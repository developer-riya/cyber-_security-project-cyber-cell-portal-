import 'dart:convert';

import '../models/threat_intelligence.dart';
import 'threat_analysis_interfaces.dart';
import 'threat_intelligence_client_security.dart';
import 'threat_intelligence_http_transport.dart';

Future<void> _defaultRetryDelay(Duration duration) =>
    Future<void>.delayed(duration);

class VirusTotalProxyConfiguration {
  const VirusTotalProxyConfiguration({
    required this.enabled,
    required this.proxyEndpoint,
    this.connectionTimeout = const Duration(milliseconds: 900),
    this.responseTimeout = const Duration(milliseconds: 1200),
    this.maxResponseBytes = 256 * 1024,
    this.maxRetries = 1,
    this.retryDelay = const Duration(milliseconds: 100),
    this.supportedIndicatorTypes = const <ThreatIntelligenceIndicatorType>{
      ThreatIntelligenceIndicatorType.url,
      ThreatIntelligenceIndicatorType.sha256,
      ThreatIntelligenceIndicatorType.domain,
      ThreatIntelligenceIndicatorType.ip,
    },
  });

  factory VirusTotalProxyConfiguration.fromEnvironment() =>
      const VirusTotalProxyConfiguration(
        enabled: bool.fromEnvironment(
          'CYBER_UDAY_THREAT_INTEL_ENABLED',
          defaultValue: false,
        ),
        proxyEndpoint: String.fromEnvironment(
          'CYBER_UDAY_THREAT_INTEL_PROXY_URL',
        ),
      );

  final bool enabled;
  final String proxyEndpoint;
  final Duration connectionTimeout;
  final Duration responseTimeout;
  final int maxResponseBytes;
  final int maxRetries;
  final Duration retryDelay;
  final Set<ThreatIntelligenceIndicatorType> supportedIndicatorTypes;

  Uri? get endpoint {
    final Uri? value = Uri.tryParse(proxyEndpoint.trim());
    if (value == null ||
        value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment ||
        value.host == 'virustotal.com' ||
        value.host.endsWith('.virustotal.com')) {
      return null;
    }
    return value;
  }

  bool get isConfigured => enabled && endpoint != null;
}

/// VirusTotal Premium adapter for a Cyber Uday-controlled backend proxy.
/// The proxy owns the provider credential. Flutter sends only a normalized
/// indicator and never receives or stores the provider API key.
class VirusTotalProxyThreatIntelligenceProvider
    implements ThreatIntelligenceProvider {
  VirusTotalProxyThreatIntelligenceProvider({
    required this.configuration,
    required this.transport,
    this.requestSecurityProvider =
        const NoThreatIntelligenceRequestSecurityProvider(),
    this.delay = _defaultRetryDelay,
  }) {
    if (configuration.maxResponseBytes <= 0) {
      throw ArgumentError.value(
        configuration.maxResponseBytes,
        'maxResponseBytes',
        'Must be positive.',
      );
    }
    if (configuration.maxRetries < 0 || configuration.maxRetries > 2) {
      throw ArgumentError.value(
        configuration.maxRetries,
        'maxRetries',
        'Must be between zero and two.',
      );
    }
  }

  final VirusTotalProxyConfiguration configuration;
  final ThreatIntelligenceHttpTransport transport;
  final ThreatIntelligenceRequestSecurityProvider requestSecurityProvider;
  final Future<void> Function(Duration duration) delay;

  @override
  String get providerName => 'virustotal-premium-proxy';

  @override
  bool get isConfigured => configuration.isConfigured;

  @override
  Future<ThreatIntelligenceResult> lookup(
    ThreatIntelligenceLookupRequest request,
  ) async {
    if (!isConfigured) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.notConfigured,
        transmitted: false,
      );
    }
    if (!configuration.supportedIndicatorTypes.contains(
      request.indicatorType,
    )) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.unsupported,
        evidence: const <String>[
          'This reputation operation is not supported by the configured provider.',
        ],
        transmitted: false,
      );
    }

    final Uri endpoint = configuration.endpoint!;
    final ThreatIntelligenceRequestSecurityHeaders securityHeaders =
        await requestSecurityProvider.headers();
    final ThreatIntelligenceHttpRequest httpRequest =
        ThreatIntelligenceHttpRequest(
          endpoint: endpoint,
          headers: <String, String>{
            'accept': 'application/json',
            'content-type': 'application/json',
            ...securityHeaders.toHttpHeaders(),
          },
          body: utf8.encode(
            jsonEncode(<String, Object?>{
              'provider': 'virustotal-premium',
              'indicatorType': request.indicatorType.name,
              'indicator': request.indicator,
            }),
          ),
        );

    for (int attempt = 0; ; attempt += 1) {
      try {
        final ThreatIntelligenceHttpResponse response = await transport.post(
          httpRequest,
          connectionTimeout: configuration.connectionTimeout,
          responseTimeout: configuration.responseTimeout,
          maxResponseBytes: configuration.maxResponseBytes,
        );
        if (_isRetryableStatus(response.statusCode) &&
            attempt < configuration.maxRetries) {
          await delay(configuration.retryDelay);
          continue;
        }
        return _parseResponse(request, response);
      } on ThreatIntelligenceTransportException catch (error) {
        if (error.error == ThreatIntelligenceTransportError.network &&
            attempt < configuration.maxRetries) {
          await delay(configuration.retryDelay);
          continue;
        }
        return _transportFailure(request, error.error);
      } catch (_) {
        return _result(
          request: request,
          status: ThreatIntelligenceStatus.error,
          errorCategory: ThreatIntelligenceErrorCategory.provider,
          evidence: const <String>[
            'Threat intelligence was unavailable; local analysis remains available.',
          ],
        );
      }
    }
  }

  ThreatIntelligenceResult _parseResponse(
    ThreatIntelligenceLookupRequest request,
    ThreatIntelligenceHttpResponse response,
  ) {
    if (response.statusCode == 404) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.unknown,
        evidence: const <String>[
          'No reputation record was available for this indicator.',
        ],
      );
    }
    if (response.statusCode == 429) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.rateLimited,
        evidence: const <String>[
          'The reputation service rate limit was reached.',
        ],
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.authorization,
        evidence: const <String>[
          'The reputation service authorization was unavailable.',
        ],
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.provider,
        evidence: const <String>[
          'The reputation service returned an unavailable response.',
        ],
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: false),
      );
    } catch (_) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.malformedResponse,
        evidence: const <String>[
          'The reputation response could not be validated.',
        ],
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.malformedResponse,
        evidence: const <String>[
          'The reputation response had an unexpected structure.',
        ],
      );
    }

    final ThreatIntelligenceStatus? normalizedStatus = _normalizedStatus(
      decoded['status'],
    );
    if (normalizedStatus != null) {
      final double? confidence = _validConfidence(decoded['confidence']);
      if (decoded['confidence'] != null && confidence == null) {
        return _result(
          request: request,
          status: ThreatIntelligenceStatus.error,
          errorCategory: ThreatIntelligenceErrorCategory.malformedResponse,
          evidence: const <String>[
            'The reputation response confidence was invalid.',
          ],
        );
      }
      return _result(
        request: request,
        status: normalizedStatus,
        confidence: confidence,
        evidence: _boundedEvidence(decoded['evidence']),
      );
    }

    final Map<String, dynamic>? statistics = _lastAnalysisStatistics(decoded);
    if (statistics == null) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.unknown,
        evidence: const <String>[
          'The provider returned no usable reputation statistics.',
        ],
      );
    }
    return _resultFromStatistics(request, statistics);
  }

  ThreatIntelligenceResult _resultFromStatistics(
    ThreatIntelligenceLookupRequest request,
    Map<String, dynamic> statistics,
  ) {
    final int? malicious = _nonNegativeInteger(statistics['malicious']);
    final int? suspicious = _nonNegativeInteger(statistics['suspicious']);
    final int? harmless = _nonNegativeInteger(statistics['harmless']);
    final int? undetected = _nonNegativeInteger(statistics['undetected']);
    if (<int?>[malicious, suspicious, harmless, undetected].contains(null)) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.malformedResponse,
        evidence: const <String>[
          'The provider reputation statistics were malformed.',
        ],
      );
    }
    final int total = malicious! + suspicious! + harmless! + undetected!;
    if (total == 0) {
      return _result(
        request: request,
        status: ThreatIntelligenceStatus.unknown,
        evidence: const <String>[
          'The provider had no completed reputation observations.',
        ],
      );
    }
    final ThreatIntelligenceStatus status = malicious > 0
        ? ThreatIntelligenceStatus.malicious
        : suspicious > 0
        ? ThreatIntelligenceStatus.suspicious
        : ThreatIntelligenceStatus.clean;
    return _result(
      request: request,
      status: status,
      evidence: <String>[
        'Threat intelligence observations: $malicious malicious, $suspicious suspicious, and ${harmless + undetected} without a threat classification.',
      ],
    );
  }

  ThreatIntelligenceResult _transportFailure(
    ThreatIntelligenceLookupRequest request,
    ThreatIntelligenceTransportError error,
  ) => switch (error) {
    ThreatIntelligenceTransportError.timeout => _result(
      request: request,
      status: ThreatIntelligenceStatus.timeout,
      evidence: const <String>[
        'The reputation request timed out; local analysis remains available.',
      ],
    ),
    ThreatIntelligenceTransportError.responseTooLarge => _result(
      request: request,
      status: ThreatIntelligenceStatus.error,
      errorCategory: ThreatIntelligenceErrorCategory.responseTooLarge,
      evidence: const <String>[
        'The reputation response exceeded the configured safety limit.',
      ],
    ),
    ThreatIntelligenceTransportError.insecureEndpoint => _result(
      request: request,
      status: ThreatIntelligenceStatus.error,
      errorCategory: ThreatIntelligenceErrorCategory.insecureEndpoint,
      evidence: const <String>[
        'The reputation endpoint did not satisfy HTTPS requirements.',
      ],
      transmitted: false,
    ),
    ThreatIntelligenceTransportError.network => _result(
      request: request,
      status: ThreatIntelligenceStatus.error,
      errorCategory: ThreatIntelligenceErrorCategory.network,
      evidence: const <String>[
        'The reputation service could not be reached; local analysis remains available.',
      ],
    ),
  };

  ThreatIntelligenceResult _result({
    required ThreatIntelligenceLookupRequest request,
    required ThreatIntelligenceStatus status,
    List<String> evidence = const <String>[],
    double? confidence,
    ThreatIntelligenceErrorCategory? errorCategory,
    bool transmitted = true,
  }) => ThreatIntelligenceResult(
    indicatorType: request.indicatorType,
    status: status,
    providerName: providerName,
    confidence: confidence,
    matchedEvidence: List<String>.unmodifiable(evidence),
    lookupDurationMs: 0,
    lookedUpAt: DateTime.now(),
    privacy: ThreatIntelligencePrivacyMetadata(
      providerConfigured: isConfigured,
      indicatorType: request.indicatorType,
      transmittedValueType: transmitted
          ? _valueType(request.indicatorType)
          : ThreatIntelligenceTransmittedValueType.none,
      privacyMode: transmitted
          ? ThreatIntelligencePrivacyMode.indicatorOnly
          : ThreatIntelligencePrivacyMode.noExternalTransmission,
      externalTransmissionOccurred: transmitted,
    ),
    errorCategory: errorCategory,
  );

  static bool _isRetryableStatus(int statusCode) =>
      statusCode == 502 || statusCode == 503 || statusCode == 504;

  static ThreatIntelligenceStatus? _normalizedStatus(Object? value) {
    if (value is! String) return null;
    return switch (value.trim().toUpperCase()) {
      'MALICIOUS' => ThreatIntelligenceStatus.malicious,
      'SUSPICIOUS' => ThreatIntelligenceStatus.suspicious,
      'CLEAN' => ThreatIntelligenceStatus.clean,
      'UNKNOWN' => ThreatIntelligenceStatus.unknown,
      'UNSUPPORTED' => ThreatIntelligenceStatus.unsupported,
      'NOT_CONFIGURED' => ThreatIntelligenceStatus.notConfigured,
      'ERROR' => ThreatIntelligenceStatus.error,
      'TIMEOUT' => ThreatIntelligenceStatus.timeout,
      _ => null,
    };
  }

  static Map<String, dynamic>? _lastAnalysisStatistics(
    Map<String, dynamic> response,
  ) {
    final Object? data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final Object? attributes = data['attributes'];
    if (attributes is! Map<String, dynamic>) return null;
    final Object? statistics = attributes['last_analysis_stats'];
    return statistics is Map<String, dynamic> ? statistics : null;
  }

  static List<String> _boundedEvidence(Object? value) {
    if (value is! List<Object?>) return const <String>[];
    return List<String>.unmodifiable(
      value
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .take(10)
          .map(
            (String item) =>
                item.length <= 240 ? item : '${item.substring(0, 237)}...',
          ),
    );
  }

  static double? _validConfidence(Object? value) {
    if (value is! num) return null;
    final double confidence = value.toDouble();
    return confidence.isFinite && confidence >= 0 && confidence <= 1
        ? confidence
        : null;
  }

  static int? _nonNegativeInteger(Object? value) {
    if (value is! num || value != value.roundToDouble() || value < 0) {
      return null;
    }
    return value.toInt();
  }

  static ThreatIntelligenceTransmittedValueType _valueType(
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
}
