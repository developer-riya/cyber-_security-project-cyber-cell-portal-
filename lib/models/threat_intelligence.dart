enum ThreatIntelligenceIndicatorType { url, sha256, domain, ip }

enum ThreatIntelligenceStatus {
  malicious,
  suspicious,
  clean,
  unknown,
  unsupported,
  notConfigured,
  error,
  timeout,
}

enum ThreatIntelligenceErrorCategory {
  validation,
  provider,
  malformedResponse,
  rateLimited,
  network,
  authorization,
  responseTooLarge,
  insecureEndpoint,
}

enum ThreatIntelligenceTransmittedValueType {
  none,
  indicatorOnly,
  normalizedUrl,
  sha256,
  domain,
  ip,
}

enum ThreatIntelligencePrivacyMode { noExternalTransmission, indicatorOnly }

class ThreatIntelligencePrivacyMetadata {
  const ThreatIntelligencePrivacyMetadata({
    required this.providerConfigured,
    required this.indicatorType,
    required this.transmittedValueType,
    required this.privacyMode,
    this.rawContentTransmitted = false,
    this.rawFileTransmitted = false,
    this.externalTransmissionOccurred = false,
  });

  final bool providerConfigured;
  final ThreatIntelligenceIndicatorType indicatorType;
  final ThreatIntelligenceTransmittedValueType transmittedValueType;
  final ThreatIntelligencePrivacyMode privacyMode;
  final bool rawContentTransmitted;
  final bool rawFileTransmitted;
  final bool externalTransmissionOccurred;
}

/// Contains only a normalized reputation indicator and lookup metadata.
/// File bytes, local paths, credentials, and raw uploaded content have no place
/// in this provider boundary.
class ThreatIntelligenceLookupRequest {
  const ThreatIntelligenceLookupRequest({
    required this.requestId,
    required this.indicatorType,
    required this.indicator,
    required this.privacy,
  });

  final String requestId;
  final ThreatIntelligenceIndicatorType indicatorType;
  final String indicator;
  final ThreatIntelligencePrivacyMetadata privacy;
}

class ThreatIntelligenceResult {
  const ThreatIntelligenceResult({
    required this.indicatorType,
    required this.status,
    required this.providerName,
    required this.lookupDurationMs,
    required this.lookedUpAt,
    required this.privacy,
    this.confidence,
    this.matchedEvidence = const <String>[],
    this.errorCategory,
    this.fromCache = false,
  });

  final ThreatIntelligenceIndicatorType indicatorType;
  final ThreatIntelligenceStatus status;
  final String providerName;
  final double? confidence;
  final List<String> matchedEvidence;
  final int lookupDurationMs;
  final DateTime lookedUpAt;
  final ThreatIntelligencePrivacyMetadata privacy;
  final ThreatIntelligenceErrorCategory? errorCategory;
  final bool fromCache;

  ThreatIntelligenceResult copyWith({
    int? lookupDurationMs,
    DateTime? lookedUpAt,
    ThreatIntelligencePrivacyMetadata? privacy,
    bool? fromCache,
  }) => ThreatIntelligenceResult(
    indicatorType: indicatorType,
    status: status,
    providerName: providerName,
    confidence: confidence,
    matchedEvidence: List<String>.unmodifiable(matchedEvidence),
    lookupDurationMs: lookupDurationMs ?? this.lookupDurationMs,
    lookedUpAt: lookedUpAt ?? this.lookedUpAt,
    privacy: privacy ?? this.privacy,
    errorCategory: errorCategory,
    fromCache: fromCache ?? this.fromCache,
  );
}
