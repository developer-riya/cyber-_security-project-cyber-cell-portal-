import 'incoming_share_payload.dart';
import 'threat_intelligence.dart';

enum ThreatAnalysisStage {
  receiving,
  identifying,
  extractingIndicators,
  checkingThreats,
  calculatingRisk,
  preparingResult,
}

enum ThreatVerdict { low, medium, high, critical, unknown }

enum ThreatRequestStatus {
  received,
  validating,
  quarantined,
  analyzing,
  complete,
  partial,
  timeout,
  error,
  cancelled,
}

enum ThreatResultStatus {
  complete,
  partial,
  analysisUnavailable,
  error,
  timeout,
}

class ThreatAnalysisRequest {
  const ThreatAnalysisRequest({
    required this.requestId,
    required this.inputType,
    required this.mimeType,
    required this.fileNames,
    required this.totalSizeBytes,
    required this.references,
    required this.extractedText,
    required this.url,
    required this.sourceApplication,
    required this.receivedAt,
    required this.metadata,
    this.filename,
    this.declaredMimeType,
    this.detectedMimeType,
    this.sizeBytes,
    this.source,
    this.contentReference,
    this.sha256,
    this.createdAt,
    this.status = ThreatRequestStatus.received,
  });

  factory ThreatAnalysisRequest.fromPayload(IncomingSharePayload payload) {
    return ThreatAnalysisRequest(
      requestId: payload.id,
      inputType: payload.primaryType,
      mimeType: payload.mimeType,
      fileNames: payload.attachments
          .map((attachment) => attachment.displayName)
          .toList(growable: false),
      totalSizeBytes: payload.attachments.fold<int>(
        0,
        (total, attachment) => total + (attachment.sizeBytes ?? 0),
      ),
      references: payload.attachments
          .map((attachment) => attachment.uri)
          .toList(growable: false),
      extractedText: payload.text,
      url: payload.urls.isEmpty ? null : payload.urls.first,
      sourceApplication: payload.sourceApplication,
      receivedAt: payload.receivedAt,
      metadata: <String, Object?>{
        'attachmentCount': payload.attachments.length,
        'multiple': payload.isMultiple,
        'temporaryQuarantineSources': payload.attachments
            .map((attachment) => attachment.isTemporaryQuarantineSource)
            .toList(growable: false),
      },
      filename: payload.attachments.length == 1
          ? payload.attachments.single.fileName
          : null,
      declaredMimeType:
          payload.mimeType ??
          (payload.attachments.length == 1
              ? payload.attachments.single.mimeType
              : null),
      detectedMimeType: payload.attachments.length == 1
          ? payload.attachments.single.detectedMimeType
          : null,
      sizeBytes: payload.attachments.length == 1
          ? payload.attachments.single.sizeBytes
          : null,
      source: payload.sourceApplication,
      contentReference: payload.attachments.length == 1
          ? payload.attachments.single.uri
          : null,
      sha256: payload.attachments.length == 1
          ? payload.attachments.single.sha256
          : null,
      createdAt: payload.receivedAt,
    );
  }

  final String requestId;
  final IncomingShareContentType inputType;
  final String? mimeType;
  final List<String> fileNames;
  final int totalSizeBytes;
  final List<String> references;
  final String? extractedText;
  final String? url;
  final String? sourceApplication;
  final DateTime receivedAt;
  final Map<String, Object?> metadata;
  final String? filename;
  final String? declaredMimeType;
  final String? detectedMimeType;
  final int? sizeBytes;
  final String? source;
  final String? contentReference;
  final String? sha256;
  final DateTime? createdAt;
  final ThreatRequestStatus status;

  ThreatAnalysisRequest copyWith({
    String? contentReference,
    String? sha256,
    int? sizeBytes,
    String? detectedMimeType,
    ThreatRequestStatus? status,
  }) => ThreatAnalysisRequest(
    requestId: requestId,
    inputType: inputType,
    mimeType: mimeType,
    fileNames: fileNames,
    totalSizeBytes: totalSizeBytes,
    references: references,
    extractedText: extractedText,
    url: url,
    sourceApplication: sourceApplication,
    receivedAt: receivedAt,
    metadata: metadata,
    filename: filename,
    declaredMimeType: declaredMimeType,
    detectedMimeType: detectedMimeType ?? this.detectedMimeType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    source: source,
    contentReference: contentReference ?? this.contentReference,
    sha256: sha256 ?? this.sha256,
    createdAt: createdAt,
    status: status ?? this.status,
  );
}

class ThreatFeatures {
  const ThreatFeatures({
    required this.suspiciousDomain,
    required this.phishingIndicator,
    required this.suspiciousUrl,
    required this.impersonationIndicator,
    required this.urgencyIndicator,
    required this.credentialTheftIndicator,
    required this.suspiciousFileType,
    required this.knownThreat,
    required this.unknownRisk,
    this.activeContentIndicator = false,
    this.embeddedFileIndicator = false,
    this.launchActionIndicator = false,
    this.javascriptIndicator = false,
    this.documentAnalysisIncomplete = false,
    this.apkSecurityIndicator = false,
    this.apkAccessibilityIndicator = false,
    this.apkPersistenceIndicator = false,
    this.apkPermissionCombinationIndicator = false,
    this.apkDynamicCodeIndicator = false,
    this.archiveExecutableIndicator = false,
    this.archiveBombIndicator = false,
    this.archiveNestedIndicator = false,
  });

  final bool suspiciousDomain;
  final bool phishingIndicator;
  final bool suspiciousUrl;
  final bool impersonationIndicator;
  final bool urgencyIndicator;
  final bool credentialTheftIndicator;
  final bool suspiciousFileType;
  final bool knownThreat;
  final bool unknownRisk;
  final bool activeContentIndicator;
  final bool embeddedFileIndicator;
  final bool launchActionIndicator;
  final bool javascriptIndicator;
  final bool documentAnalysisIncomplete;
  final bool apkSecurityIndicator;
  final bool apkAccessibilityIndicator;
  final bool apkPersistenceIndicator;
  final bool apkPermissionCombinationIndicator;
  final bool apkDynamicCodeIndicator;
  final bool archiveExecutableIndicator;
  final bool archiveBombIndicator;
  final bool archiveNestedIndicator;

  ThreatFeatures copyWith({bool? knownThreat}) => ThreatFeatures(
    suspiciousDomain: suspiciousDomain,
    phishingIndicator: phishingIndicator,
    suspiciousUrl: suspiciousUrl,
    impersonationIndicator: impersonationIndicator,
    urgencyIndicator: urgencyIndicator,
    credentialTheftIndicator: credentialTheftIndicator,
    suspiciousFileType: suspiciousFileType,
    knownThreat: knownThreat ?? this.knownThreat,
    unknownRisk: unknownRisk,
    activeContentIndicator: activeContentIndicator,
    embeddedFileIndicator: embeddedFileIndicator,
    launchActionIndicator: launchActionIndicator,
    javascriptIndicator: javascriptIndicator,
    documentAnalysisIncomplete: documentAnalysisIncomplete,
    apkSecurityIndicator: apkSecurityIndicator,
    apkAccessibilityIndicator: apkAccessibilityIndicator,
    apkPersistenceIndicator: apkPersistenceIndicator,
    apkPermissionCombinationIndicator: apkPermissionCombinationIndicator,
    apkDynamicCodeIndicator: apkDynamicCodeIndicator,
    archiveExecutableIndicator: archiveExecutableIndicator,
    archiveBombIndicator: archiveBombIndicator,
    archiveNestedIndicator: archiveNestedIndicator,
  );
}

class ThreatAnalysisResult {
  const ThreatAnalysisResult({
    required this.requestId,
    required this.status,
    required this.verdict,
    required this.riskScore,
    required this.confidence,
    required this.detectedThreats,
    required this.evidence,
    required this.recommendedActions,
    required this.analyzedAt,
    required this.analyzerResults,
    required this.durationMs,
    required this.features,
    this.sha256,
    this.inputType,
    this.detectedType,
    this.structuredEvidence = const <String, List<String>>{},
    this.threatIntelligenceResults = const <ThreatIntelligenceResult>[],
  });

  final String requestId;
  final ThreatResultStatus status;
  final ThreatVerdict verdict;
  final int riskScore;
  final double confidence;
  final List<String> detectedThreats;
  final List<String> evidence;
  final List<String> recommendedActions;
  final DateTime analyzedAt;
  final List<String> analyzerResults;
  final int durationMs;
  final ThreatFeatures features;
  final String? sha256;
  final IncomingShareContentType? inputType;
  final IncomingShareContentType? detectedType;
  final Map<String, List<String>> structuredEvidence;
  final List<ThreatIntelligenceResult> threatIntelligenceResults;
}
