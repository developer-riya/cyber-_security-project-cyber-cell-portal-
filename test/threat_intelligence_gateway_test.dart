import 'dart:async';

import 'package:cyberuday/models/cyber_risk_signal.dart';
import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/models/threat_intelligence.dart';
import 'package:cyberuday/services/security_audit_logger.dart';
import 'package:cyberuday/services/security_pipeline_config.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:cyberuday/services/threat_analysis_interfaces.dart';
import 'package:cyberuday/services/threat_intelligence_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _ProviderResponder =
    Future<ThreatIntelligenceResult> Function(
      ThreatIntelligenceLookupRequest request,
    );

void main() {
  group('ThreatIntelligenceGateway normalization and privacy', () {
    test('1. no provider configured returns NOT_CONFIGURED', () async {
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway();

      final List<ThreatIntelligenceResult> results = await Future.wait(
        <Future<ThreatIntelligenceResult>>[
          gateway.lookupUrl(requestId: 'none-url', url: 'example.com'),
          gateway.lookupHash(requestId: 'none-hash', sha256Value: 'a' * 64),
          gateway.lookupDomain(requestId: 'none-domain', domain: 'example.com'),
          gateway.lookupIp(requestId: 'none-ip', ip: '203.0.113.10'),
        ],
      );

      expect(
        results.map((ThreatIntelligenceResult result) => result.status),
        everyElement(ThreatIntelligenceStatus.notConfigured),
      );
      expect(
        results.map(
          (ThreatIntelligenceResult result) =>
              result.privacy.externalTransmissionOccurred,
        ),
        everyElement(isFalse),
      );
    });

    test(
      'no-provider outcome remains deterministic behind limiter hook',
      () async {
        final _DenyRateLimiter limiter = _DenyRateLimiter();
        final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
          rateLimiter: limiter,
        ).lookupDomain(requestId: 'none-limited', domain: 'example.com');

        expect(result.status, ThreatIntelligenceStatus.notConfigured);
        expect(limiter.allowedChecks, 0);
      },
    );

    test('2. URL lookup reuses normalized HTTP(S) parsing', () async {
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      await gateway.lookupUrl(
        requestId: 'url',
        url: ' EXAMPLE.com/login?step=1 ',
      );

      expect(
        provider.requests.single.indicatorType,
        ThreatIntelligenceIndicatorType.url,
      );
      expect(
        provider.requests.single.indicator,
        'https://example.com/login?step=1',
      );
    });

    test(
      '3. SHA-256 lookup sends only the normalized hash indicator',
      () async {
        final _FakeProvider provider = _FakeProvider();
        final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
          provider: provider,
        );

        await gateway.lookupHash(requestId: 'hash', sha256Value: 'A' * 64);

        final ThreatIntelligenceLookupRequest request =
            provider.requests.single;
        expect(request.indicator, 'a' * 64);
        expect(request.indicatorType, ThreatIntelligenceIndicatorType.sha256);
        expect(request.privacy.rawFileTransmitted, isFalse);
        expect(request.privacy.rawContentTransmitted, isFalse);
        expect(
          request.privacy.transmittedValueType,
          ThreatIntelligenceTransmittedValueType.sha256,
        );
      },
    );

    test('4. domain lookup normalizes case', () async {
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      await gateway.lookupDomain(
        requestId: 'domain',
        domain: 'Sub.Example.COM',
      );

      expect(provider.requests.single.indicator, 'sub.example.com');
      expect(
        provider.requests.single.indicatorType,
        ThreatIntelligenceIndicatorType.domain,
      );
    });

    test('5. IPv4 lookup validates and normalizes octets', () async {
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      await gateway.lookupIp(requestId: 'ipv4', ip: '203.000.113.010');

      expect(provider.requests.single.indicator, '203.0.113.10');
    });

    test('6. IPv6 lookup expands a normalized provider indicator', () async {
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      await gateway.lookupIp(requestId: 'ipv6', ip: '[2001:DB8::1]');

      expect(provider.requests.single.indicator, '2001:db8:0:0:0:0:0:1');
    });

    test('7. malformed hash is rejected before provider invocation', () async {
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: provider,
      ).lookupHash(requestId: 'bad-hash', sha256Value: 'not-a-hash');

      expect(result.status, ThreatIntelligenceStatus.error);
      expect(result.errorCategory, ThreatIntelligenceErrorCategory.validation);
      expect(provider.requests, isEmpty);
    });

    test(
      '8. malformed domain is rejected before provider invocation',
      () async {
        final _FakeProvider provider = _FakeProvider();
        final ThreatIntelligenceResult result =
            await ThreatIntelligenceGateway(provider: provider).lookupDomain(
              requestId: 'bad-domain',
              domain: 'https://example.com/x',
            );

        expect(result.status, ThreatIntelligenceStatus.error);
        expect(
          result.errorCategory,
          ThreatIntelligenceErrorCategory.validation,
        );
        expect(provider.requests, isEmpty);
      },
    );

    test('21. request model cannot carry raw file content or paths', () async {
      final _FakeProvider provider = _FakeProvider();
      await ThreatIntelligenceGateway(
        provider: provider,
      ).lookupHash(requestId: 'privacy', sha256Value: 'b' * 64);

      final ThreatIntelligenceLookupRequest request = provider.requests.single;
      expect(request.indicator, 'b' * 64);
      expect(request.privacy.rawFileTransmitted, isFalse);
      expect(request.privacy.rawContentTransmitted, isFalse);
    });

    test('22. URL boundary does not fetch the submitted target', () async {
      final _FakeProvider provider = _FakeProvider();
      await ThreatIntelligenceGateway(provider: provider).lookupUrl(
        requestId: 'no-target-contact',
        url: 'https://example.com/private/path',
      );

      expect(provider.calls, 1);
      expect(provider.targetFetches, 0);
    });

    test('23. URL boundary does not perform DNS lookup', () async {
      final _FakeProvider provider = _FakeProvider();
      await ThreatIntelligenceGateway(
        provider: provider,
      ).lookupUrl(requestId: 'no-dns', url: 'https://example.com/check');

      expect(provider.dnsLookups, 0);
    });

    test('24. URL boundary does not launch a browser', () async {
      final _FakeProvider provider = _FakeProvider();
      await ThreatIntelligenceGateway(
        provider: provider,
      ).lookupUrl(requestId: 'no-browser', url: 'https://example.com/check');

      expect(provider.browserLaunches, 0);
    });
  });

  group('ThreatIntelligenceGateway resilience', () {
    test('9. provider timeout is isolated', () async {
      final _FakeProvider provider = _FakeProvider(
        responder: (ThreatIntelligenceLookupRequest request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _providerResult(request);
        },
      );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
        config: const SecurityPipelineConfig(
          threatIntelligenceTimeout: Duration(milliseconds: 5),
        ),
      );

      final ThreatIntelligenceResult result = await gateway.lookupUrl(
        requestId: 'timeout',
        url: 'example.com',
      );

      expect(result.status, ThreatIntelligenceStatus.timeout);
      expect(result.errorCategory, isNull);
    });

    test('10. provider exception becomes structured ERROR', () async {
      final _FakeProvider provider = _FakeProvider(
        responder: (ThreatIntelligenceLookupRequest _) async =>
            throw StateError('fake provider failure'),
      );

      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: provider,
      ).lookupUrl(requestId: 'error', url: 'example.com');

      expect(result.status, ThreatIntelligenceStatus.error);
      expect(result.errorCategory, ThreatIntelligenceErrorCategory.provider);
    });

    test('11. malformed provider response is discarded', () async {
      final _FakeProvider provider = _FakeProvider(
        responder: (ThreatIntelligenceLookupRequest request) async =>
            _providerResult(
              request,
              indicatorType: ThreatIntelligenceIndicatorType.ip,
            ),
      );

      final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
        provider: provider,
      ).lookupUrl(requestId: 'malformed', url: 'example.com');

      expect(result.status, ThreatIntelligenceStatus.error);
      expect(
        result.errorCategory,
        ThreatIntelligenceErrorCategory.malformedResponse,
      );
    });

    test('12. identical lookup uses cache', () async {
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      await gateway.lookupHash(requestId: 'cache-1', sha256Value: 'c' * 64);
      final ThreatIntelligenceResult cached = await gateway.lookupHash(
        requestId: 'cache-2',
        sha256Value: 'c' * 64,
      );

      expect(provider.calls, 1);
      expect(cached.fromCache, isTrue);
    });

    test('13. cache entry expires after configured TTL', () async {
      DateTime now = DateTime.utc(2026, 1, 1);
      final _FakeProvider provider = _FakeProvider();
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
        cache: BoundedThreatIntelligenceCache(
          maxEntries: 10,
          ttl: const Duration(minutes: 1),
        ),
        clock: () => now,
      );

      await gateway.lookupDomain(requestId: 'ttl-1', domain: 'example.com');
      now = now.add(const Duration(minutes: 2));
      await gateway.lookupDomain(requestId: 'ttl-2', domain: 'example.com');

      expect(provider.calls, 2);
    });

    test('14. concurrent duplicate lookup is suppressed', () async {
      final Completer<ThreatIntelligenceResult> completer =
          Completer<ThreatIntelligenceResult>();
      final _FakeProvider provider = _FakeProvider(
        responder: (ThreatIntelligenceLookupRequest _) => completer.future,
      );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      final Future<ThreatIntelligenceResult> first = gateway.lookupDomain(
        requestId: 'dedupe-1',
        domain: 'example.com',
      );
      final Future<ThreatIntelligenceResult> second = gateway.lookupDomain(
        requestId: 'dedupe-2',
        domain: 'example.com',
      );
      await Future<void>.delayed(Duration.zero);
      completer.complete(_providerResult(provider.requests.single));
      await Future.wait(<Future<ThreatIntelligenceResult>>[first, second]);

      expect(provider.calls, 1);
    });

    test('15. cache evicts least-recently-used entry at its bound', () async {
      final _FakeProvider provider = _FakeProvider();
      final BoundedThreatIntelligenceCache cache =
          BoundedThreatIntelligenceCache(
            maxEntries: 2,
            ttl: const Duration(minutes: 5),
          );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
        cache: cache,
      );

      await gateway.lookupDomain(requestId: 'bound-1', domain: 'one.example');
      await gateway.lookupDomain(requestId: 'bound-2', domain: 'two.example');
      await gateway.lookupDomain(requestId: 'bound-3', domain: 'three.example');
      await gateway.lookupDomain(requestId: 'bound-4', domain: 'one.example');

      expect(cache.length, 2);
      expect(provider.calls, 4);
    });

    test('concurrent provider work is centrally bounded', () async {
      final Completer<ThreatIntelligenceResult> completer =
          Completer<ThreatIntelligenceResult>();
      final _FakeProvider provider = _FakeProvider(
        responder: (ThreatIntelligenceLookupRequest _) => completer.future,
      );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
        config: const SecurityPipelineConfig(
          maxConcurrentThreatIntelligenceLookups: 1,
        ),
      );

      final Future<ThreatIntelligenceResult> first = gateway.lookupDomain(
        requestId: 'concurrent-1',
        domain: 'one.example',
      );
      await Future<void>.delayed(Duration.zero);
      final ThreatIntelligenceResult limited = await gateway.lookupDomain(
        requestId: 'concurrent-2',
        domain: 'two.example',
      );
      completer.complete(_providerResult(provider.requests.single));
      await first;

      expect(limited.status, ThreatIntelligenceStatus.error);
      expect(
        limited.errorCategory,
        ThreatIntelligenceErrorCategory.rateLimited,
      );
      expect(provider.calls, 1);
    });

    test(
      '16. rate limiter blocks provider without breaking boundary',
      () async {
        final _FakeProvider provider = _FakeProvider();
        final _DenyRateLimiter limiter = _DenyRateLimiter();
        final ThreatIntelligenceResult result = await ThreatIntelligenceGateway(
          provider: provider,
          rateLimiter: limiter,
        ).lookupDomain(requestId: 'limited', domain: 'example.com');

        expect(result.status, ThreatIntelligenceStatus.error);
        expect(
          result.errorCategory,
          ThreatIntelligenceErrorCategory.rateLimited,
        );
        expect(provider.calls, 0);
        expect(limiter.allowedChecks, 1);
      },
    );

    test('25. audit events contain fingerprints instead of raw URL', () async {
      final InMemorySecurityAuditLogger logger = InMemorySecurityAuditLogger();
      await ThreatIntelligenceGateway(
        provider: _FakeProvider(),
        auditLogger: logger,
      ).lookupUrl(requestId: 'audit', url: 'https://example.com/private-value');

      expect(
        logger.events.map((SecurityAuditEvent event) => event.type),
        containsAll(<SecurityAuditEventType>[
          SecurityAuditEventType.threatIntelligenceLookupStarted,
          SecurityAuditEventType.threatIntelligenceLookupCompleted,
        ]),
      );
      final String loggedMetadata = logger.events
          .map((SecurityAuditEvent event) => event.metadata.toString())
          .join(' ');
      expect(loggedMetadata, isNot(contains('private-value')));
      expect(loggedMetadata, contains('indicatorFingerprint'));
    });

    test('26. one provider failure does not poison the next lookup', () async {
      int attempts = 0;
      final _FakeProvider provider = _FakeProvider(
        responder: (ThreatIntelligenceLookupRequest request) async {
          attempts += 1;
          if (attempts == 1) throw StateError('first call fails');
          return _providerResult(request);
        },
      );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      final ThreatIntelligenceResult failed = await gateway.lookupDomain(
        requestId: 'isolation-1',
        domain: 'example.com',
      );
      final ThreatIntelligenceResult recovered = await gateway.lookupDomain(
        requestId: 'isolation-2',
        domain: 'example.com',
      );

      expect(failed.status, ThreatIntelligenceStatus.error);
      expect(recovered.status, ThreatIntelligenceStatus.unknown);
      expect(provider.calls, 2);
    });

    test('NOT_CONFIGURED responses are never cached', () async {
      final _FakeProvider provider = _FakeProvider(
        configured: false,
        responder: (ThreatIntelligenceLookupRequest request) async =>
            _providerResult(
              request,
              status: ThreatIntelligenceStatus.notConfigured,
              configured: false,
            ),
      );
      final ThreatIntelligenceGateway gateway = ThreatIntelligenceGateway(
        provider: provider,
      );

      await gateway.lookupDomain(requestId: 'nc-1', domain: 'example.com');
      await gateway.lookupDomain(requestId: 'nc-2', domain: 'example.com');

      expect(provider.calls, 2);
      expect(gateway.cache.length, 0);
    });
  });

  group('Threat fusion integration', () {
    test(
      '17. local analysis continues when intelligence is unavailable',
      () async {
        final _FakeProvider provider = _FakeProvider(
          responder: (ThreatIntelligenceLookupRequest _) async =>
              throw StateError('offline fake'),
        );
        final ThreatAnalysisEngine engine = ThreatAnalysisEngine(
          threatIntelligenceGateway: ThreatIntelligenceGateway(
            provider: provider,
          ),
          analysisExecutor: (IncomingSharePayload _) async =>
              const ShareThreatAnalysis(
                risk: ShareThreatRisk.error,
                status: ShareAnalysisStatus.analysisUnavailable,
                title: 'Unavailable',
                message: 'Local analysis unavailable.',
                indicators: <String>[],
                recommendations: <String>['Keep the item closed.'],
                analyzerName: 'Fake local analyzer',
              ),
        );

        final ThreatAnalysisRun run = await engine.analyze(
          _urlPayload('integration-offline'),
        );

        expect(run.result.verdict, ThreatVerdict.unknown);
        expect(run.result.status, ThreatResultStatus.analysisUnavailable);
        expect(
          run.result.threatIntelligenceResults,
          everyElement(
            isA<ThreatIntelligenceResult>().having(
              (ThreatIntelligenceResult result) => result.status,
              'status',
              ThreatIntelligenceStatus.error,
            ),
          ),
        );
      },
    );

    test('18. NOT_CONFIGURED cannot turn unknown local result into LOW', () {
      final ThreatAnalysisResult result = const ThreatFusionEngine().fuse(
        request: ThreatAnalysisRequest.fromPayload(_urlPayload('nc-fusion')),
        analysis: _unavailableAnalysis,
        features: _unknownFeatures,
        durationMs: 1,
        threatIntelligenceResults: <ThreatIntelligenceResult>[
          _resultForFusion(ThreatIntelligenceStatus.notConfigured),
        ],
      );

      expect(result.verdict, ThreatVerdict.unknown);
      expect(result.riskScore, 0);
    });

    test('19. CLEAN intelligence cannot downgrade strong local HIGH', () {
      final ThreatAnalysisResult result = const ThreatFusionEngine().fuse(
        request: ThreatAnalysisRequest.fromPayload(_urlPayload('clean-high')),
        analysis: _highAnalysis,
        features: _highFeatures,
        durationMs: 1,
        threatIntelligenceResults: <ThreatIntelligenceResult>[
          _resultForFusion(ThreatIntelligenceStatus.clean),
        ],
      );

      expect(result.verdict, ThreatVerdict.high);
      expect(result.riskScore, greaterThanOrEqualTo(85));
    });

    test(
      '20. MALICIOUS intelligence is strong evidence but not CRITICAL alone',
      () {
        final ThreatAnalysisResult result = const ThreatFusionEngine().fuse(
          request: ThreatAnalysisRequest.fromPayload(
            _urlPayload('malicious-intel'),
          ),
          analysis: _unavailableAnalysis,
          features: _unknownFeatures,
          durationMs: 1,
          threatIntelligenceResults: <ThreatIntelligenceResult>[
            _resultForFusion(
              ThreatIntelligenceStatus.malicious,
              evidence: const <String>['Known malicious test indicator.'],
            ),
          ],
        );

        expect(result.verdict, ThreatVerdict.high);
        expect(result.verdict, isNot(ThreatVerdict.critical));
        expect(result.features.knownThreat, isTrue);
        expect(
          result.structuredEvidence['THREAT_INTELLIGENCE'],
          contains('Known malicious test indicator.'),
        );
        expect(CyberRiskSignal.fromResult(result).level, CyberRiskLevel.high);
      },
    );
  });
}

class _FakeProvider implements ThreatIntelligenceProvider {
  _FakeProvider({this.responder, this.configured = true});

  final _ProviderResponder? responder;
  final bool configured;
  final List<ThreatIntelligenceLookupRequest> requests =
      <ThreatIntelligenceLookupRequest>[];
  int targetFetches = 0;
  int dnsLookups = 0;
  int browserLaunches = 0;

  int get calls => requests.length;

  @override
  bool get isConfigured => configured;

  @override
  String get providerName => 'fake-provider';

  @override
  Future<ThreatIntelligenceResult> lookup(
    ThreatIntelligenceLookupRequest request,
  ) async {
    requests.add(request);
    return responder?.call(request) ?? _providerResult(request);
  }
}

class _DenyRateLimiter implements ThreatIntelligenceRateLimiter {
  int allowedChecks = 0;

  @override
  Future<bool> allow(ThreatIntelligenceRateLimitContext context) async {
    allowedChecks += 1;
    return false;
  }

  @override
  void record(ThreatIntelligenceRateLimitContext context) {}
}

ThreatIntelligenceResult _providerResult(
  ThreatIntelligenceLookupRequest request, {
  ThreatIntelligenceStatus status = ThreatIntelligenceStatus.unknown,
  ThreatIntelligenceIndicatorType? indicatorType,
  bool configured = true,
}) => ThreatIntelligenceResult(
  indicatorType: indicatorType ?? request.indicatorType,
  status: status,
  providerName: 'fake-provider',
  lookupDurationMs: 0,
  lookedUpAt: DateTime.utc(2026, 1, 1),
  privacy: ThreatIntelligencePrivacyMetadata(
    providerConfigured: configured,
    indicatorType: indicatorType ?? request.indicatorType,
    transmittedValueType: configured
        ? _testValueType(indicatorType ?? request.indicatorType)
        : ThreatIntelligenceTransmittedValueType.none,
    privacyMode: configured
        ? ThreatIntelligencePrivacyMode.indicatorOnly
        : ThreatIntelligencePrivacyMode.noExternalTransmission,
  ),
);

ThreatIntelligenceResult _resultForFusion(
  ThreatIntelligenceStatus status, {
  List<String> evidence = const <String>[],
}) => ThreatIntelligenceResult(
  indicatorType: ThreatIntelligenceIndicatorType.url,
  status: status,
  providerName: status == ThreatIntelligenceStatus.notConfigured
      ? 'not-configured'
      : 'fake-provider',
  matchedEvidence: evidence,
  lookupDurationMs: 1,
  lookedUpAt: DateTime.utc(2026, 1, 1),
  privacy: ThreatIntelligencePrivacyMetadata(
    providerConfigured: status != ThreatIntelligenceStatus.notConfigured,
    indicatorType: ThreatIntelligenceIndicatorType.url,
    transmittedValueType: status == ThreatIntelligenceStatus.notConfigured
        ? ThreatIntelligenceTransmittedValueType.none
        : ThreatIntelligenceTransmittedValueType.normalizedUrl,
    privacyMode: status == ThreatIntelligenceStatus.notConfigured
        ? ThreatIntelligencePrivacyMode.noExternalTransmission
        : ThreatIntelligencePrivacyMode.indicatorOnly,
  ),
);

ThreatIntelligenceTransmittedValueType _testValueType(
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

IncomingSharePayload _urlPayload(String id) =>
    IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
      'id': id,
      'receivedAt': 1,
      'text': 'https://example.com/check',
      'items': const <Object?>[],
    });

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
