import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/models/threat_intelligence.dart';
import 'package:cyberuday/services/security_audit_logger.dart';
import 'package:cyberuday/services/security_pipeline_config.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:cyberuday/services/threat_intelligence_gateway.dart';
import 'package:cyberuday/services/threat_intelligence_client_security.dart';
import 'package:cyberuday/services/threat_intelligence_http_transport.dart';
import 'package:cyberuday/services/virus_total_threat_intelligence_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('VirusTotal Premium proxy configuration', () {
    test(
      '1. configured backend provider accepts reputation responses',
      () async {
        final _FakeTransport transport = _FakeTransport()
          ..responses.add(_jsonResponse(<String, Object?>{'status': 'CLEAN'}));
        final VirusTotalProxyThreatIntelligenceProvider provider = _provider(
          transport,
        );

        final ThreatIntelligenceResult result = await provider.lookup(
          _request(ThreatIntelligenceIndicatorType.sha256, _sha('a')),
        );

        expect(provider.isConfigured, isTrue);
        expect(result.status, ThreatIntelligenceStatus.clean);
        expect(transport.requests, hasLength(1));
      },
    );

    test(
      '2. missing secure proxy configuration returns NOT_CONFIGURED',
      () async {
        final _FakeTransport transport = _FakeTransport();
        final VirusTotalProxyThreatIntelligenceProvider provider = _provider(
          transport,
          configuration: const VirusTotalProxyConfiguration(
            enabled: false,
            proxyEndpoint: '',
          ),
        );

        final ThreatIntelligenceResult result = await provider.lookup(
          _request(ThreatIntelligenceIndicatorType.sha256, _sha('b')),
        );

        expect(result.status, ThreatIntelligenceStatus.notConfigured);
        expect(result.privacy.externalTransmissionOccurred, isFalse);
        expect(transport.requests, isEmpty);
      },
    );

    test('25. non-HTTPS proxy endpoint is never contacted', () async {
      final _FakeTransport transport = _FakeTransport();
      final VirusTotalProxyThreatIntelligenceProvider provider = _provider(
        transport,
        configuration: const VirusTotalProxyConfiguration(
          enabled: true,
          proxyEndpoint: 'http://proxy.example/v1/reputation',
        ),
      );

      final ThreatIntelligenceResult result = await provider.lookup(
        _request(ThreatIntelligenceIndicatorType.url, 'https://example.com'),
      );

      expect(provider.isConfigured, isFalse);
      expect(result.status, ThreatIntelligenceStatus.notConfigured);
      expect(transport.requests, isEmpty);
    });

    test(
      'proxy endpoint rejects query credentials and direct provider URLs',
      () {
        const VirusTotalProxyConfiguration queryConfiguration =
            VirusTotalProxyConfiguration(
              enabled: true,
              proxyEndpoint: 'https://proxy.example/reputation?token=secret',
            );
        const VirusTotalProxyConfiguration directConfiguration =
            VirusTotalProxyConfiguration(
              enabled: true,
              proxyEndpoint: 'https://www.virustotal.com/api/v3/files',
            );

        expect(queryConfiguration.isConfigured, isFalse);
        expect(directConfiguration.isConfigured, isFalse);
      },
    );

    test('Firebase security headers reach only the Cyber Uday proxy', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      final VirusTotalProxyThreatIntelligenceProvider provider = _provider(
        transport,
        requestSecurityProvider: const _FakeRequestSecurityProvider(),
      );

      await provider.lookup(
        _request(ThreatIntelligenceIndicatorType.sha256, _sha('f')),
      );

      expect(
        transport.requests.single.headers['authorization'],
        'Bearer fixture-id-token',
      );
      expect(
        transport.requests.single.headers['x-firebase-appcheck'],
        'fixture-app-check-token',
      );
      expect(
        transport.requests.single.headers.keys,
        isNot(contains('x-apikey')),
      );
    });
  });

  group('VirusTotal reputation semantics', () {
    test('3. known malicious SHA-256 maps provider statistics', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _statisticsResponse(
            malicious: 9,
            suspicious: 1,
            harmless: 2,
            undetected: 18,
          ),
        );

      final ThreatIntelligenceResult result = await _provider(
        transport,
      ).lookup(_request(ThreatIntelligenceIndicatorType.sha256, _sha('c')));

      expect(result.status, ThreatIntelligenceStatus.malicious);
      expect(result.confidence, isNull);
      expect(result.matchedEvidence.single, contains('9 malicious'));
    });

    test('4. missing SHA-256 reputation remains UNKNOWN', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _jsonResponse(const <String, Object?>{}, statusCode: 404),
        );

      final ThreatIntelligenceResult result = await _provider(
        transport,
      ).lookup(_request(ThreatIntelligenceIndicatorType.sha256, _sha('d')));

      expect(result.status, ThreatIntelligenceStatus.unknown);
      expect(result.status, isNot(ThreatIntelligenceStatus.clean));
    });

    test('5. malformed SHA-256 is rejected by gateway before HTTP', () async {
      final _FakeTransport transport = _FakeTransport();
      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupHash(requestId: 'bad-hash', sha256Value: 'invalid');

      expect(result.errorCategory, ThreatIntelligenceErrorCategory.validation);
      expect(transport.requests, isEmpty);
    });

    test('6. malicious URL response is normalized', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _jsonResponse(<String, Object?>{
            'status': 'MALICIOUS',
            'evidence': <String>['Provider match confirmed.'],
          }),
        );
      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupUrl(requestId: 'url-malicious', url: 'EXAMPLE.com/login');

      expect(result.status, ThreatIntelligenceStatus.malicious);
      expect(
        _requestJson(transport.requests.single)['indicator'],
        'https://example.com/login',
      );
    });

    test('7. URL with completed zero detections maps CLEAN', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _statisticsResponse(
            malicious: 0,
            suspicious: 0,
            harmless: 3,
            undetected: 17,
          ),
        );
      final ThreatIntelligenceResult result = await _provider(transport).lookup(
        _request(ThreatIntelligenceIndicatorType.url, 'https://example.com'),
      );

      expect(result.status, ThreatIntelligenceStatus.clean);
    });

    test('8. URL without a provider record maps UNKNOWN', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _jsonResponse(const <String, Object?>{}, statusCode: 404),
        );
      final ThreatIntelligenceResult result = await _provider(transport).lookup(
        _request(ThreatIntelligenceIndicatorType.url, 'https://unknown.test'),
      );

      expect(result.status, ThreatIntelligenceStatus.unknown);
    });

    test('9. domain lookup sends only normalized domain indicator', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupDomain(requestId: 'domain', domain: 'Sub.Example.COM');

      expect(_requestJson(transport.requests.single), <String, Object?>{
        'provider': 'virustotal-premium',
        'indicatorType': 'domain',
        'indicator': 'sub.example.com',
      });
    });

    test('10. IPv4 lookup reaches only the proxy boundary', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupIp(requestId: 'ipv4', ip: '203.000.113.010');

      expect(
        _requestJson(transport.requests.single)['indicator'],
        '203.0.113.10',
      );
    });

    test('11. IPv6 lookup reaches only the proxy boundary', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupIp(requestId: 'ipv6', ip: '[2001:db8::1]');

      expect(
        _requestJson(transport.requests.single)['indicator'],
        '2001:db8:0:0:0:0:0:1',
      );
    });
  });

  group('VirusTotal provider failure isolation', () {
    test('12. transport timeout maps TIMEOUT', () async {
      final _FakeTransport transport = _FakeTransport()
        ..errors.add(ThreatIntelligenceTransportError.timeout);
      final ThreatIntelligenceResult result = await _provider(
        transport,
      ).lookup(_request(ThreatIntelligenceIndicatorType.sha256, _sha('e')));

      expect(result.status, ThreatIntelligenceStatus.timeout);
    });

    test('13. provider HTTP failure maps ERROR', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _jsonResponse(const <String, Object?>{}, statusCode: 500),
        );
      final ThreatIntelligenceResult result = await _provider(
        transport,
        maxRetries: 0,
      ).lookup(_request(ThreatIntelligenceIndicatorType.domain, 'example.com'));

      expect(result.status, ThreatIntelligenceStatus.error);
      expect(result.errorCategory, ThreatIntelligenceErrorCategory.provider);
    });

    test('14. HTTP 429 maps rate-limit error without retry', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          _jsonResponse(const <String, Object?>{}, statusCode: 429),
        );
      final ThreatIntelligenceResult result = await _provider(
        transport,
      ).lookup(_request(ThreatIntelligenceIndicatorType.domain, 'example.com'));

      expect(result.errorCategory, ThreatIntelligenceErrorCategory.rateLimited);
      expect(transport.requests, hasLength(1));
    });

    test('15. malformed JSON is discarded', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(
          ThreatIntelligenceHttpResponse(
            statusCode: 200,
            bodyBytes: Uint8List.fromList(<int>[123, 98, 97, 100]),
          ),
        );
      final ThreatIntelligenceResult result = await _provider(
        transport,
      ).lookup(_request(ThreatIntelligenceIndicatorType.domain, 'example.com'));

      expect(
        result.errorCategory,
        ThreatIntelligenceErrorCategory.malformedResponse,
      );
    });

    test('16. oversized response maps bounded response error', () async {
      final _FakeTransport transport = _FakeTransport()
        ..errors.add(ThreatIntelligenceTransportError.responseTooLarge);
      final ThreatIntelligenceResult result = await _provider(
        transport,
      ).lookup(_request(ThreatIntelligenceIndicatorType.domain, 'example.com'));

      expect(
        result.errorCategory,
        ThreatIntelligenceErrorCategory.responseTooLarge,
      );
    });

    test('26. gateway request timeout remains isolated', () async {
      final Completer<ThreatIntelligenceHttpResponse> completer =
          Completer<ThreatIntelligenceHttpResponse>();
      final _FakeTransport transport = _FakeTransport(
        responder: (_) => completer.future,
      );
      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: _provider(transport),
        config: const SecurityPipelineConfig(
          threatIntelligenceTimeout: Duration(milliseconds: 5),
        ),
      ).lookupDomain(requestId: 'outer-timeout', domain: 'example.com');

      expect(result.status, ThreatIntelligenceStatus.timeout);
      completer.complete(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
    });

    test('27. retry behavior is bounded to one safe retry', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.addAll(<ThreatIntelligenceHttpResponse>[
          _jsonResponse(const <String, Object?>{}, statusCode: 503),
          _jsonResponse(<String, Object?>{'status': 'CLEAN'}),
        ]);
      int delays = 0;
      final VirusTotalProxyThreatIntelligenceProvider provider = _provider(
        transport,
        delay: (_) async => delays += 1,
      );

      final ThreatIntelligenceResult result = await provider.lookup(
        _request(ThreatIntelligenceIndicatorType.domain, 'example.com'),
      );

      expect(result.status, ThreatIntelligenceStatus.clean);
      expect(transport.requests, hasLength(2));
      expect(delays, 1);
    });

    test('28. unavailable provider capability returns UNSUPPORTED', () async {
      final _FakeTransport transport = _FakeTransport();
      final VirusTotalProxyConfiguration configuration = _configuration(
        supportedTypes: const <ThreatIntelligenceIndicatorType>{
          ThreatIntelligenceIndicatorType.sha256,
        },
      );
      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: _provider(transport, configuration: configuration),
      ).lookupUrl(requestId: 'unsupported', url: 'example.com');

      expect(result.status, ThreatIntelligenceStatus.unsupported);
      expect(result.privacy.externalTransmissionOccurred, isFalse);
      expect(transport.requests, isEmpty);
    });
  });

  group('Gateway cache, fusion, audit, and privacy', () {
    test('17. concurrent duplicate provider lookup is suppressed', () async {
      final Completer<ThreatIntelligenceHttpResponse> completer =
          Completer<ThreatIntelligenceHttpResponse>();
      final _FakeTransport transport = _FakeTransport(
        responder: (_) => completer.future,
      );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: _provider(transport),
      );

      final Future<ThreatIntelligenceResult> first = gateway.lookupHash(
        requestId: 'dup-1',
        sha256Value: _sha('f'),
      );
      final Future<ThreatIntelligenceResult> second = gateway.lookupHash(
        requestId: 'dup-2',
        sha256Value: _sha('f'),
      );
      await Future<void>.delayed(Duration.zero);
      completer.complete(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      await Future.wait(<Future<ThreatIntelligenceResult>>[first, second]);

      expect(transport.requests, hasLength(1));
    });

    test('18. successful provider lookup is served from cache', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'CLEAN'}));
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: _provider(transport),
      );
      await gateway.lookupHash(requestId: 'cache-1', sha256Value: _sha('1'));
      final ThreatIntelligenceResult cached = await gateway.lookupHash(
        requestId: 'cache-2',
        sha256Value: _sha('1'),
      );

      expect(cached.fromCache, isTrue);
      expect(transport.requests, hasLength(1));
    });

    test('19. provider cache respects configured expiry', () async {
      DateTime now = DateTime.utc(2026, 1, 1);
      final _FakeTransport transport = _FakeTransport()
        ..responses.addAll(<ThreatIntelligenceHttpResponse>[
          _jsonResponse(<String, Object?>{'status': 'CLEAN'}),
          _jsonResponse(<String, Object?>{'status': 'CLEAN'}),
        ]);
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: _provider(transport),
        cache: BoundedThreatIntelligenceCache(
          maxEntries: 4,
          ttl: const Duration(seconds: 5),
        ),
        clock: () => now,
      );
      await gateway.lookupDomain(requestId: 'expiry-1', domain: 'example.com');
      now = now.add(const Duration(seconds: 6));
      await gateway.lookupDomain(requestId: 'expiry-2', domain: 'example.com');

      expect(transport.requests, hasLength(2));
    });

    test(
      '20. local analysis survives real-provider transport failure',
      () async {
        final _FakeTransport transport = _FakeTransport()
          ..errors.addAll(<ThreatIntelligenceTransportError>[
            ThreatIntelligenceTransportError.network,
            ThreatIntelligenceTransportError.network,
            ThreatIntelligenceTransportError.network,
            ThreatIntelligenceTransportError.network,
          ]);
        final ThreatAnalysisEngine engine = ThreatAnalysisEngine(
          threatIntelligenceGateway: ThreatIntelligenceGateway(
            provider: _provider(transport, maxRetries: 0),
          ),
          analysisExecutor: (_) async => _unavailableAnalysis,
        );

        final ThreatAnalysisRun run = await engine.analyze(
          _urlPayload('provider-offline'),
        );

        expect(run.result.verdict, ThreatVerdict.unknown);
        expect(run.result.status, ThreatResultStatus.analysisUnavailable);
      },
    );

    test('21. provider CLEAN cannot downgrade strong local HIGH', () {
      final ThreatAnalysisResult result = const ThreatFusionEngine().fuse(
        request: ThreatAnalysisRequest.fromPayload(_urlPayload('clean-high')),
        analysis: _highAnalysis,
        features: _highFeatures,
        durationMs: 1,
        threatIntelligenceResults: <ThreatIntelligenceResult>[
          _intelligenceResult(ThreatIntelligenceStatus.clean),
        ],
      );

      expect(result.verdict, ThreatVerdict.high);
    });

    test('22. provider MALICIOUS strengthens neutral evidence', () {
      final ThreatAnalysisResult result = const ThreatFusionEngine().fuse(
        request: ThreatAnalysisRequest.fromPayload(_urlPayload('malicious')),
        analysis: _unavailableAnalysis,
        features: _unknownFeatures,
        durationMs: 1,
        threatIntelligenceResults: <ThreatIntelligenceResult>[
          _intelligenceResult(
            ThreatIntelligenceStatus.malicious,
            evidence: const <String>['Known malicious reputation match.'],
          ),
        ],
      );

      expect(result.verdict, ThreatVerdict.high);
      expect(result.features.knownThreat, isTrue);
      expect(result.evidence.join(' '), isNot(contains('VirusTotal')));
      expect(result.evidence, contains('Known malicious reputation match.'));
      expect(result.analyzerResults, contains('Threat intelligence'));
      expect(result.analyzerResults.join(' '), isNot(contains('virustotal')));
    });

    test(
      '23. provider credentials never enter requests or audit logs',
      () async {
        const String credentialCanary = 'provider-credential-canary';
        final InMemorySecurityAuditLogger logger =
            InMemorySecurityAuditLogger();
        final _FakeTransport transport = _FakeTransport()
          ..responses.add(
            _jsonResponse(<String, Object?>{
              'status': 'UNKNOWN',
              'ignored': credentialCanary,
            }),
          );
        await ThreatIntelligenceGateway(
          provider: _provider(transport),
          auditLogger: logger,
        ).lookupDomain(requestId: 'credential-log', domain: 'example.com');

        final ThreatIntelligenceHttpRequest request = transport.requests.single;
        expect(request.headers.keys, isNot(contains('authorization')));
        expect(request.headers.keys, isNot(contains('x-apikey')));
        expect(utf8.decode(request.body), isNot(contains(credentialCanary)));
        expect(
          logger.events
              .map((SecurityAuditEvent event) => event.metadata)
              .join(),
          isNot(contains(credentialCanary)),
        );
      },
    );

    test('24. raw user file and local path are never transmitted', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupHash(requestId: 'file-privacy', sha256Value: _sha('2'));

      final Map<String, dynamic> body = _requestJson(transport.requests.single);
      expect(
        body.keys,
        unorderedEquals(<String>['provider', 'indicatorType', 'indicator']),
      );
      expect(body.values.join(' '), isNot(contains('/')));
      expect(body['indicator'], _sha('2'));
    });

    test('29. audit events include safe provider operation metadata', () async {
      final InMemorySecurityAuditLogger logger = InMemorySecurityAuditLogger();
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      await ThreatIntelligenceGateway(
        provider: _provider(transport),
        auditLogger: logger,
      ).lookupDomain(requestId: 'audit-provider', domain: 'example.com');

      final SecurityAuditEvent completed = logger.events.lastWhere(
        (SecurityAuditEvent event) =>
            event.type ==
            SecurityAuditEventType.threatIntelligenceLookupCompleted,
      );
      expect(completed.metadata['provider'], 'virustotal-premium-proxy');
      expect(completed.metadata['operation'], 'domain');
      expect(completed.metadata['cacheHit'], isFalse);
      expect(completed.metadata['durationMs'], isA<int>());
      expect(completed.metadata.toString(), isNot(contains('example.com')));
    });

    test('30. privacy metadata records indicator-only transmission', () async {
      final _FakeTransport transport = _FakeTransport()
        ..responses.add(_jsonResponse(<String, Object?>{'status': 'UNKNOWN'}));
      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: _provider(transport),
      ).lookupHash(requestId: 'privacy', sha256Value: _sha('3'));

      expect(result.privacy.rawContentTransmitted, isFalse);
      expect(result.privacy.rawFileTransmitted, isFalse);
      expect(result.privacy.externalTransmissionOccurred, isTrue);
      expect(
        result.privacy.transmittedValueType,
        ThreatIntelligenceTransmittedValueType.sha256,
      );
      expect(
        result.privacy.privacyMode,
        ThreatIntelligencePrivacyMode.indicatorOnly,
      );
    });
  });

  group('Bounded HTTP transport', () {
    test('response stream is stopped at the configured byte limit', () async {
      final BoundedThreatIntelligenceHttpTransport transport =
          BoundedThreatIntelligenceHttpTransport(
            client: _StreamingClient(
              response: http.StreamedResponse(
                Stream<List<int>>.value(List<int>.filled(32, 65)),
                200,
              ),
            ),
          );

      await expectLater(
        transport.post(
          ThreatIntelligenceHttpRequest(
            endpoint: Uri.parse('https://proxy.example/v1/reputation'),
            body: const <int>[],
          ),
          connectionTimeout: const Duration(seconds: 1),
          responseTimeout: const Duration(seconds: 1),
          maxResponseBytes: 16,
        ),
        throwsA(
          isA<ThreatIntelligenceTransportException>().having(
            (ThreatIntelligenceTransportException error) => error.error,
            'error',
            ThreatIntelligenceTransportError.responseTooLarge,
          ),
        ),
      );
    });
  });
}

class _FakeTransport implements ThreatIntelligenceHttpTransport {
  _FakeTransport({this.responder});

  final Future<ThreatIntelligenceHttpResponse> Function(
    ThreatIntelligenceHttpRequest request,
  )?
  responder;
  final List<ThreatIntelligenceHttpRequest> requests =
      <ThreatIntelligenceHttpRequest>[];
  final List<ThreatIntelligenceHttpResponse> responses =
      <ThreatIntelligenceHttpResponse>[];
  final List<ThreatIntelligenceTransportError> errors =
      <ThreatIntelligenceTransportError>[];

  @override
  Future<ThreatIntelligenceHttpResponse> post(
    ThreatIntelligenceHttpRequest request, {
    required Duration connectionTimeout,
    required Duration responseTimeout,
    required int maxResponseBytes,
  }) async {
    requests.add(request);
    final Future<ThreatIntelligenceHttpResponse> Function(
      ThreatIntelligenceHttpRequest request,
    )?
    callback = responder;
    if (callback != null) return callback(request);
    if (errors.isNotEmpty) {
      throw ThreatIntelligenceTransportException(errors.removeAt(0));
    }
    if (responses.isEmpty) throw StateError('No fake response configured.');
    return responses.removeAt(0);
  }
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient({required this.response});

  final http.StreamedResponse response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
}

VirusTotalProxyThreatIntelligenceProvider _provider(
  _FakeTransport transport, {
  VirusTotalProxyConfiguration? configuration,
  ThreatIntelligenceRequestSecurityProvider requestSecurityProvider =
      const NoThreatIntelligenceRequestSecurityProvider(),
  int maxRetries = 1,
  Future<void> Function(Duration duration)? delay,
}) => VirusTotalProxyThreatIntelligenceProvider(
  configuration: configuration ?? _configuration(maxRetries: maxRetries),
  transport: transport,
  requestSecurityProvider: requestSecurityProvider,
  delay: delay ?? (_) async {},
);

class _FakeRequestSecurityProvider
    implements ThreatIntelligenceRequestSecurityProvider {
  const _FakeRequestSecurityProvider();

  @override
  Future<ThreatIntelligenceRequestSecurityHeaders> headers() async =>
      const ThreatIntelligenceRequestSecurityHeaders(
        authorization: 'Bearer fixture-id-token',
        appCheckToken: 'fixture-app-check-token',
      );
}

VirusTotalProxyConfiguration _configuration({
  int maxRetries = 1,
  Set<ThreatIntelligenceIndicatorType> supportedTypes =
      const <ThreatIntelligenceIndicatorType>{
        ThreatIntelligenceIndicatorType.url,
        ThreatIntelligenceIndicatorType.sha256,
        ThreatIntelligenceIndicatorType.domain,
        ThreatIntelligenceIndicatorType.ip,
      },
}) => VirusTotalProxyConfiguration(
  enabled: true,
  proxyEndpoint: 'https://proxy.example/v1/reputation',
  maxRetries: maxRetries,
  supportedIndicatorTypes: supportedTypes,
);

ThreatIntelligenceLookupRequest _request(
  ThreatIntelligenceIndicatorType type,
  String indicator,
) => ThreatIntelligenceLookupRequest(
  requestId: 'provider-test',
  indicatorType: type,
  indicator: indicator,
  privacy: ThreatIntelligencePrivacyMetadata(
    providerConfigured: true,
    indicatorType: type,
    transmittedValueType: _valueType(type),
    privacyMode: ThreatIntelligencePrivacyMode.indicatorOnly,
  ),
);

ThreatIntelligenceTransmittedValueType _valueType(
  ThreatIntelligenceIndicatorType type,
) => switch (type) {
  ThreatIntelligenceIndicatorType.url =>
    ThreatIntelligenceTransmittedValueType.normalizedUrl,
  ThreatIntelligenceIndicatorType.sha256 =>
    ThreatIntelligenceTransmittedValueType.sha256,
  ThreatIntelligenceIndicatorType.domain =>
    ThreatIntelligenceTransmittedValueType.domain,
  ThreatIntelligenceIndicatorType.ip =>
    ThreatIntelligenceTransmittedValueType.ip,
};

ThreatIntelligenceHttpResponse _jsonResponse(
  Map<String, Object?> body, {
  int statusCode = 200,
}) => ThreatIntelligenceHttpResponse(
  statusCode: statusCode,
  bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

ThreatIntelligenceHttpResponse _statisticsResponse({
  required int malicious,
  required int suspicious,
  required int harmless,
  required int undetected,
}) => _jsonResponse(<String, Object?>{
  'data': <String, Object?>{
    'attributes': <String, Object?>{
      'last_analysis_stats': <String, Object?>{
        'malicious': malicious,
        'suspicious': suspicious,
        'harmless': harmless,
        'undetected': undetected,
      },
    },
  },
});

Map<String, dynamic> _requestJson(ThreatIntelligenceHttpRequest request) =>
    jsonDecode(utf8.decode(request.body)) as Map<String, dynamic>;

String _sha(String character) => List<String>.filled(64, character).join();

IncomingSharePayload _urlPayload(String id) =>
    IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
      'id': id,
      'receivedAt': 1,
      'text': 'https://example.com/check',
      'items': const <Object?>[],
    });

ThreatIntelligenceResult _intelligenceResult(
  ThreatIntelligenceStatus status, {
  List<String> evidence = const <String>[],
}) => ThreatIntelligenceResult(
  indicatorType: ThreatIntelligenceIndicatorType.url,
  status: status,
  providerName: 'virustotal-premium-proxy',
  matchedEvidence: evidence,
  lookupDurationMs: 1,
  lookedUpAt: DateTime.utc(2026, 1, 1),
  privacy: const ThreatIntelligencePrivacyMetadata(
    providerConfigured: true,
    indicatorType: ThreatIntelligenceIndicatorType.url,
    transmittedValueType: ThreatIntelligenceTransmittedValueType.normalizedUrl,
    privacyMode: ThreatIntelligencePrivacyMode.indicatorOnly,
    externalTransmissionOccurred: true,
  ),
);

const ShareThreatAnalysis _unavailableAnalysis = ShareThreatAnalysis(
  risk: ShareThreatRisk.error,
  status: ShareAnalysisStatus.analysisUnavailable,
  title: 'Unavailable',
  message: 'No local conclusion.',
  indicators: <String>[],
  recommendations: <String>['Keep the item closed.'],
  analyzerName: 'Fake local analyzer',
);

const ShareThreatAnalysis _highAnalysis = ShareThreatAnalysis(
  risk: ShareThreatRisk.highRisk,
  status: ShareAnalysisStatus.highRisk,
  title: 'High',
  message: 'Strong local indicators.',
  indicators: <String>['credential phishing indicator'],
  recommendations: <String>['Do not continue.'],
  analyzerName: 'Fake local analyzer',
);

const ThreatFeatures _unknownFeatures = ThreatFeatures(
  suspiciousDomain: false,
  phishingIndicator: false,
  suspiciousUrl: false,
  impersonationIndicator: false,
  urgencyIndicator: false,
  credentialTheftIndicator: false,
  suspiciousFileType: false,
  knownThreat: false,
  unknownRisk: true,
);

const ThreatFeatures _highFeatures = ThreatFeatures(
  suspiciousDomain: true,
  phishingIndicator: true,
  suspiciousUrl: true,
  impersonationIndicator: false,
  urgencyIndicator: false,
  credentialTheftIndicator: true,
  suspiciousFileType: false,
  knownThreat: false,
  unknownRisk: false,
);
