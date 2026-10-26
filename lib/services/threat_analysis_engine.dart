import 'dart:async';

import '../models/incoming_share_payload.dart';
import '../models/threat_analysis.dart';
import '../models/threat_intelligence.dart';
import 'quarantine_storage.dart';
import 'security_audit_logger.dart';
import 'security_pipeline_config.dart';
import 'share_threat_analysis_service.dart';
import 'threat_input_validator.dart';
import 'input_classifier.dart';
import 'file_type_inspector.dart';
import 'file_type_validation.dart';
import 'threat_analysis_cancellation.dart';
import 'threat_intelligence_gateway.dart';
import 'threat_intelligence_provider_factory.dart';
import 'url_threat_analysis_service.dart';

typedef ThreatAnalysisStageCallback = void Function(ThreatAnalysisStage stage);
typedef ThreatAnalysisExecutor =
    Future<ShareThreatAnalysis> Function(IncomingSharePayload payload);

class ThreatAnalysisRun {
  const ThreatAnalysisRun({required this.result, required this.analysis});

  final ThreatAnalysisResult result;
  final ShareThreatAnalysis analysis;
}

/// Coordinates the fast, deterministic first pass. Deep file inspection and
/// threat-intelligence calls can be added behind this boundary later.
class ThreatAnalysisOrchestrator {
  const ThreatAnalysisOrchestrator({
    this.analysisService = const ShareThreatAnalysisService(),
    this.fusionEngine = const ThreatFusionEngine(),
    this.config = const SecurityPipelineConfig(),
    this.validator = const ThreatInputValidator(),
    this.classifier = const InputClassifier(),
    this.fileTypeInspector = const FileTypeInspector(),
    this.quarantineStorage = const TemporaryQuarantineStorage(),
    this.auditLogger = const NoOpSecurityAuditLogger(),
    this.threatIntelligenceGateway,
    this.analysisExecutor,
  });

  final ShareThreatAnalysisService analysisService;
  final ThreatFusionEngine fusionEngine;
  final SecurityPipelineConfig config;
  final ThreatInputValidator validator;
  final InputClassifier classifier;
  final FileTypeInspector fileTypeInspector;
  final QuarantineStorage quarantineStorage;
  final SecurityAuditLogger auditLogger;
  final ThreatIntelligenceGateway? threatIntelligenceGateway;
  final ThreatAnalysisExecutor? analysisExecutor;

  Future<ThreatAnalysisRun> analyze(
    IncomingSharePayload payload, {
    ThreatAnalysisStageCallback? onStage,
    ThreatAnalysisCancellationToken? cancellationToken,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final ThreatAnalysisRequest request = ThreatAnalysisRequest.fromPayload(
      payload,
    );
    auditLogger.record(
      SecurityAuditEvent(
        type: SecurityAuditEventType.uploadReceived,
        requestId: request.requestId,
        createdAt: DateTime.now(),
        metadata: <String, Object?>{'inputType': request.inputType.name},
      ),
    );
    if (cancellationToken?.isCancelled ?? false) {
      return _deliver(
        _cancellationFailure(request, stopwatch.elapsedMilliseconds),
      );
    }
    auditLogger.record(
      SecurityAuditEvent(
        type: SecurityAuditEventType.analysisRequested,
        requestId: request.requestId,
        createdAt: DateTime.now(),
        metadata: <String, Object?>{'inputType': request.inputType.name},
      ),
    );
    onStage?.call(ThreatAnalysisStage.receiving);
    await Future<void>.delayed(Duration.zero);
    onStage?.call(ThreatAnalysisStage.identifying);
    await Future<void>.delayed(Duration.zero);
    onStage?.call(ThreatAnalysisStage.extractingIndicators);

    final ThreatValidationResult preliminaryValidation = validator.validate(
      payload,
      request,
    );
    if (!preliminaryValidation.isValid) {
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.validationFailed,
          requestId: request.requestId,
          createdAt: DateTime.now(),
          metadata: <String, Object?>{
            'errorCount': preliminaryValidation.errors.length,
            'warningCount': preliminaryValidation.warnings.length,
            'typeMismatch': payload.hasTypeMismatch,
          },
        ),
      );
      return _deliver(
        _validationFailure(
          request,
          preliminaryValidation,
          payload.hasTypeMismatch,
          stopwatch.elapsedMilliseconds,
        ),
      );
    }

    final DateTime quarantineExpiry = DateTime.now().add(
      config.quarantineRetention,
    );
    final QuarantineRecord quarantine = await quarantineStorage.store(
      request,
      expiresAt: quarantineExpiry,
    );
    auditLogger.record(
      SecurityAuditEvent(
        type: SecurityAuditEventType.quarantined,
        requestId: request.requestId,
        createdAt: DateTime.now(),
        metadata: <String, Object?>{
          'temporaryContent': quarantine.contents.isNotEmpty,
        },
      ),
    );
    final QuarantinedContent? primaryContent = quarantine.contents.isEmpty
        ? null
        : quarantine.contents.first;
    final ThreatAnalysisRequest workingRequest = request.copyWith(
      contentReference: primaryContent?.reference,
      sha256: primaryContent?.sha256,
      sizeBytes: primaryContent?.sizeBytes,
      status: ThreatRequestStatus.quarantined,
    );
    if (workingRequest.sha256 != null) {
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.hashGenerated,
          requestId: workingRequest.requestId,
          createdAt: DateTime.now(),
          metadata: <String, Object?>{'hashPresent': true},
        ),
      );
    }

    try {
      if (cancellationToken?.isCancelled ?? false) {
        return _deliver(
          _cancellationFailure(workingRequest, stopwatch.elapsedMilliseconds),
        );
      }
      final List<FileTypeValidationResult> fileTypes = await fileTypeInspector
          .inspect(payload, quarantine);
      final InputClassification classification = classifier.classify(
        payload,
        fileTypes: fileTypes,
      );
      final ThreatValidationResult validation = validator.validate(
        payload,
        workingRequest,
        fileTypes: fileTypes,
      );
      if (!validation.isValid || classification.hasTypeMismatch) {
        auditLogger.record(
          SecurityAuditEvent(
            type: SecurityAuditEventType.validationFailed,
            requestId: workingRequest.requestId,
            createdAt: DateTime.now(),
            metadata: <String, Object?>{
              'errorCount': validation.errors.length,
              'warningCount': validation.warnings.length,
              'typeMismatch': classification.hasTypeMismatch,
            },
          ),
        );
        return _deliver(
          _validationFailure(
            workingRequest,
            validation,
            classification.hasTypeMismatch,
            stopwatch.elapsedMilliseconds,
          ),
        );
      }
      onStage?.call(ThreatAnalysisStage.checkingThreats);
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.analyzerStarted,
          requestId: workingRequest.requestId,
          createdAt: DateTime.now(),
        ),
      );
      final Future<ShareThreatAnalysis> analysisFuture =
          analysisExecutor?.call(payload) ??
          analysisService.analyzeAsync(payload, quarantine: quarantine);
      final ShareThreatAnalysis analysis = await analysisFuture.timeout(
        config.maxAnalysisTime,
      );
      onStage?.call(ThreatAnalysisStage.calculatingRisk);
      final ThreatFeatures features = _featuresFrom(workingRequest, analysis);
      final ThreatIntelligenceGateway intelligenceGateway =
          threatIntelligenceGateway ??
          ThreatIntelligenceProviderFactory.createGateway(
            auditLogger: auditLogger,
            config: config,
          );
      final List<ThreatIntelligenceResult> intelligenceResults =
          await _lookupThreatIntelligence(
            request: workingRequest,
            gateway: intelligenceGateway,
          );
      final ThreatAnalysisResult result = fusionEngine.fuse(
        request: workingRequest,
        analysis: analysis,
        features: features,
        durationMs: stopwatch.elapsedMilliseconds,
        threatIntelligenceResults: intelligenceResults,
      );
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.analyzerCompleted,
          requestId: workingRequest.requestId,
          createdAt: DateTime.now(),
          metadata: <String, Object?>{'analyzer': analysis.analyzerName},
        ),
      );
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.verdictGenerated,
          requestId: workingRequest.requestId,
          createdAt: DateTime.now(),
          metadata: <String, Object?>{'verdict': result.verdict.name},
        ),
      );
      onStage?.call(ThreatAnalysisStage.preparingResult);
      return _deliver(ThreatAnalysisRun(result: result, analysis: analysis));
    } on TimeoutException {
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.timeout,
          requestId: workingRequest.requestId,
          createdAt: DateTime.now(),
        ),
      );
      final ThreatAnalysisResult result = ThreatAnalysisResult(
        requestId: request.requestId,
        status: ThreatResultStatus.timeout,
        verdict: ThreatVerdict.unknown,
        riskScore: 0,
        confidence: 0,
        detectedThreats: const <String>[],
        evidence: const <String>[
          'The first-pass deadline was reached before sufficient evidence was available.',
        ],
        recommendedActions: const <String>[
          'Keep the item closed until deeper analysis is available.',
        ],
        analyzedAt: DateTime.now(),
        analyzerResults: const <String>[],
        durationMs: stopwatch.elapsedMilliseconds,
        features: const ThreatFeatures(
          suspiciousDomain: false,
          phishingIndicator: false,
          suspiciousUrl: false,
          impersonationIndicator: false,
          urgencyIndicator: false,
          credentialTheftIndicator: false,
          suspiciousFileType: false,
          knownThreat: false,
          unknownRisk: true,
        ),
      );
      return _deliver(
        ThreatAnalysisRun(
          result: result,
          analysis: const ShareThreatAnalysis(
            risk: ShareThreatRisk.error,
            status: ShareAnalysisStatus.error,
            title: 'Initial analysis timed out',
            message:
                'Cyber Uday could not establish a confident result within the first-pass time limit.',
            indicators: <String>[
              'A timeout is not treated as proof that the item is safe.',
            ],
            recommendations: <String>[
              'Keep the item closed and try again later.',
            ],
            analyzerName: 'Analysis deadline',
          ),
        ),
      );
    } catch (_) {
      auditLogger.record(
        SecurityAuditEvent(
          type: SecurityAuditEventType.analyzerFailed,
          requestId: workingRequest.requestId,
          createdAt: DateTime.now(),
        ),
      );
      return _deliver(
        _analysisFailure(workingRequest, stopwatch.elapsedMilliseconds),
      );
    } finally {
      try {
        await quarantineStorage.delete(request.requestId);
      } finally {
        auditLogger.record(
          SecurityAuditEvent(
            type: SecurityAuditEventType.quarantineCleanup,
            requestId: request.requestId,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  ThreatAnalysisRun _deliver(ThreatAnalysisRun run) {
    auditLogger.record(
      SecurityAuditEvent(
        type: SecurityAuditEventType.resultDelivered,
        requestId: run.result.requestId,
        createdAt: DateTime.now(),
        metadata: <String, Object?>{'verdict': run.result.verdict.name},
      ),
    );
    return run;
  }

  ThreatAnalysisRun _validationFailure(
    ThreatAnalysisRequest request,
    ThreatValidationResult validation,
    bool typeMismatch,
    int durationMs,
  ) {
    final String reason = typeMismatch
        ? 'The file signature does not match its declared type.'
        : validation.errors.join(' ');
    final ShareThreatAnalysis analysis = ShareThreatAnalysis(
      risk: ShareThreatRisk.error,
      status: ShareAnalysisStatus.error,
      title: 'We could not validate this item',
      message:
          '$reason It was not opened or executed, and no safe verdict was assigned.',
      indicators: <String>[...validation.errors, ...validation.warnings],
      recommendations: const <String>[
        'Keep the item closed.',
        'Share a clean copy from a trusted source if needed.',
      ],
      analyzerName: 'Input validation',
    );
    return ThreatAnalysisRun(
      result: fusionEngine.fuse(
        request: request,
        analysis: analysis,
        features: const ThreatFeatures(
          suspiciousDomain: false,
          phishingIndicator: false,
          suspiciousUrl: false,
          impersonationIndicator: false,
          urgencyIndicator: false,
          credentialTheftIndicator: false,
          suspiciousFileType: false,
          knownThreat: false,
          unknownRisk: true,
        ),
        durationMs: durationMs,
      ),
      analysis: analysis,
    );
  }

  ThreatAnalysisRun _analysisFailure(
    ThreatAnalysisRequest request,
    int durationMs,
  ) {
    final ShareThreatAnalysis analysis = const ShareThreatAnalysis(
      risk: ShareThreatRisk.error,
      status: ShareAnalysisStatus.error,
      title: 'Initial analysis could not be completed',
      message:
          'Cyber Uday could not establish a confident result. This is not treated as safe.',
      indicators: <String>['An analyzer failed before returning evidence.'],
      recommendations: <String>['Keep the item closed and try again later.'],
      analyzerName: 'Analysis orchestrator',
    );
    return ThreatAnalysisRun(
      result: fusionEngine.fuse(
        request: request,
        analysis: analysis,
        features: const ThreatFeatures(
          suspiciousDomain: false,
          phishingIndicator: false,
          suspiciousUrl: false,
          impersonationIndicator: false,
          urgencyIndicator: false,
          credentialTheftIndicator: false,
          suspiciousFileType: false,
          knownThreat: false,
          unknownRisk: true,
        ),
        durationMs: durationMs,
      ),
      analysis: analysis,
    );
  }

  ThreatAnalysisRun _cancellationFailure(
    ThreatAnalysisRequest request,
    int durationMs,
  ) {
    const ShareThreatAnalysis analysis = ShareThreatAnalysis(
      risk: ShareThreatRisk.error,
      status: ShareAnalysisStatus.error,
      title: 'Initial analysis was cancelled',
      message:
          'Cyber Uday could not establish a confident result. Cancellation is not treated as safe.',
      indicators: <String>['The initial analysis did not complete.'],
      recommendations: <String>['Keep the item closed and try again later.'],
      analyzerName: 'Analysis cancellation',
    );
    return ThreatAnalysisRun(
      result: fusionEngine.fuse(
        request: request,
        analysis: analysis,
        features: const ThreatFeatures(
          suspiciousDomain: false,
          phishingIndicator: false,
          suspiciousUrl: false,
          impersonationIndicator: false,
          urgencyIndicator: false,
          credentialTheftIndicator: false,
          suspiciousFileType: false,
          knownThreat: false,
          unknownRisk: true,
        ),
        durationMs: durationMs,
      ),
      analysis: analysis,
    );
  }

  static ThreatFeatures _featuresFrom(
    ThreatAnalysisRequest request,
    ShareThreatAnalysis analysis,
  ) {
    final String indicators = analysis.indicators.join(' ').toLowerCase();
    return ThreatFeatures(
      suspiciousDomain:
          indicators.contains('domain') || indicators.contains('hostname'),
      phishingIndicator:
          indicators.contains('phishing') || indicators.contains('credential'),
      suspiciousUrl:
          (request.url != null && analysis.risk != ShareThreatRisk.safe) ||
          indicators.contains('apk_suspicious_url'),
      impersonationIndicator: indicators.contains('impersonat'),
      urgencyIndicator:
          indicators.contains('pressure') || indicators.contains('urgent'),
      credentialTheftIndicator:
          indicators.contains('password') ||
          indicators.contains('otp') ||
          indicators.contains('credential'),
      suspiciousFileType:
          request.inputType == IncomingShareContentType.apk ||
          request.inputType == IncomingShareContentType.executable ||
          request.inputType == IncomingShareContentType.script,
      knownThreat: false,
      unknownRisk:
          analysis.status != ShareAnalysisStatus.safe &&
          analysis.status == ShareAnalysisStatus.analysisUnavailable,
      activeContentIndicator:
          indicators.contains('active_content_indicator') ||
          indicators.contains('javascript_indicator') ||
          indicators.contains('launch_action_indicator') ||
          indicators.contains('automatic_action_indicator'),
      embeddedFileIndicator: indicators.contains('embedded_file_indicator'),
      launchActionIndicator: indicators.contains('launch_action_indicator'),
      javascriptIndicator: indicators.contains('javascript_indicator'),
      apkSecurityIndicator:
          indicators.contains('apk_credential_string_indicator') ||
          indicators.contains('apk_sms_indicator') ||
          indicators.contains('apk_financial_string_indicator') ||
          indicators.contains('apk_webview_indicator') ||
          indicators.contains('apk_native_loading_indicator') ||
          indicators.contains('apk_shell_execution_indicator'),
      apkAccessibilityIndicator: indicators.contains(
        'apk_accessibility_indicator',
      ),
      apkPersistenceIndicator: indicators.contains(
        'apk_persistence_accessibility_indicator',
      ),
      apkPermissionCombinationIndicator:
          indicators.contains('apk_permission_combination_indicator') ||
          indicators.contains('apk_device_admin_network_indicator') ||
          indicators.contains('apk_package_install_network_indicator'),
      apkDynamicCodeIndicator: indicators.contains(
        'apk_dynamic_code_indicator',
      ),
      archiveExecutableIndicator: indicators.contains(
        'archive_executable_content_indicator',
      ),
      archiveBombIndicator: indicators.contains(
        'archive_compression_ratio_indicator',
      ),
      archiveNestedIndicator: indicators.contains(
        'archive_nested_archive_indicator',
      ),
      documentAnalysisIncomplete:
          analysis.structuredEvidence['PDF_ANALYSIS_STATUS']?.any(
            (String value) =>
                value.contains('PARTIAL') || value.contains('UNKNOWN'),
          ) ??
          false,
    );
  }

  Future<List<ThreatIntelligenceResult>> _lookupThreatIntelligence({
    required ThreatAnalysisRequest request,
    required ThreatIntelligenceGateway gateway,
  }) async {
    final List<Future<ThreatIntelligenceResult>> lookups =
        <Future<ThreatIntelligenceResult>>[];
    final String? sha256Value = request.sha256;
    if (sha256Value != null && sha256Value.isNotEmpty) {
      lookups.add(
        gateway.lookupHash(
          requestId: request.requestId,
          sha256Value: sha256Value,
        ),
      );
    }

    final String? submittedUrl = request.url;
    if (submittedUrl != null && submittedUrl.isNotEmpty) {
      lookups.add(
        gateway.lookupUrl(requestId: request.requestId, url: submittedUrl),
      );
      final UrlNormalizationResult normalized = const UrlNormalizationService()
          .normalize(submittedUrl);
      final NormalizedUrl? normalizedUrl = normalized.url;
      if (normalizedUrl != null) {
        final UrlDomainParts domain = const PublicSuffixDomainParser().parse(
          normalizedUrl.uri.host,
        );
        if (domain.isIpAddress) {
          lookups.add(
            gateway.lookupIp(requestId: request.requestId, ip: domain.hostname),
          );
        } else if (!domain.isLocalhost) {
          final String domainIndicator =
              domain.registrableDomain ?? domain.hostname;
          lookups.add(
            gateway.lookupDomain(
              requestId: request.requestId,
              domain: domainIndicator,
            ),
          );
        }
      }
    }
    if (lookups.isEmpty) return const <ThreatIntelligenceResult>[];
    return List<ThreatIntelligenceResult>.unmodifiable(
      await Future.wait(lookups),
    );
  }
}

class ThreatFusionEngine {
  const ThreatFusionEngine();

  ThreatAnalysisResult fuse({
    required ThreatAnalysisRequest request,
    required ShareThreatAnalysis analysis,
    required ThreatFeatures features,
    required int durationMs,
    List<ThreatIntelligenceResult> threatIntelligenceResults =
        const <ThreatIntelligenceResult>[],
  }) {
    final (
      ThreatVerdict verdict,
      int score,
      double confidence,
      ThreatResultStatus status,
    ) = switch (analysis.status) {
      ShareAnalysisStatus.safe => (
        ThreatVerdict.low,
        15,
        0.45,
        ThreatResultStatus.complete,
      ),
      ShareAnalysisStatus.suspicious => (
        ThreatVerdict.medium,
        55,
        0.68,
        ThreatResultStatus.complete,
      ),
      ShareAnalysisStatus.highRisk => (
        ThreatVerdict.high,
        85,
        0.82,
        ThreatResultStatus.complete,
      ),
      ShareAnalysisStatus.partial => (
        analysis.risk == ShareThreatRisk.highRisk
            ? ThreatVerdict.high
            : analysis.risk == ShareThreatRisk.suspicious
            ? ThreatVerdict.medium
            : ThreatVerdict.unknown,
        analysis.risk == ShareThreatRisk.highRisk
            ? 85
            : analysis.risk == ShareThreatRisk.suspicious
            ? 55
            : 0,
        analysis.risk == ShareThreatRisk.highRisk
            ? 0.72
            : analysis.risk == ShareThreatRisk.suspicious
            ? 0.58
            : 0,
        ThreatResultStatus.partial,
      ),
      ShareAnalysisStatus.analysisUnavailable => (
        ThreatVerdict.unknown,
        0,
        0,
        ThreatResultStatus.analysisUnavailable,
      ),
      ShareAnalysisStatus.error => (
        ThreatVerdict.unknown,
        0,
        0,
        ThreatResultStatus.error,
      ),
    };
    final int strongSignalCount = <bool>[
      features.suspiciousUrl,
      features.credentialTheftIndicator,
      features.activeContentIndicator,
      features.embeddedFileIndicator,
      features.launchActionIndicator,
      features.javascriptIndicator,
      features.apkAccessibilityIndicator,
      features.apkPersistenceIndicator,
      features.apkPermissionCombinationIndicator,
      features.apkDynamicCodeIndicator,
      features.apkSecurityIndicator,
      features.archiveExecutableIndicator,
      features.archiveBombIndicator,
      features.archiveNestedIndicator,
    ].where((bool value) => value).length;
    final bool maliciousIntelligence = threatIntelligenceResults.any(
      (ThreatIntelligenceResult result) =>
          result.status == ThreatIntelligenceStatus.malicious,
    );
    final bool suspiciousIntelligence = threatIntelligenceResults.any(
      (ThreatIntelligenceResult result) =>
          result.status == ThreatIntelligenceStatus.suspicious,
    );
    final int signalBonus = features.unknownRisk
        ? 0
        : (features.activeContentIndicator ? 8 : 0) +
              (features.embeddedFileIndicator ? 8 : 0) +
              (features.launchActionIndicator ? 8 : 0) +
              (features.javascriptIndicator ? 6 : 0) +
              (features.suspiciousUrl ? 6 : 0) +
              (features.credentialTheftIndicator ? 6 : 0) +
              (features.apkSecurityIndicator ? 4 : 0) +
              (features.apkAccessibilityIndicator ? 8 : 0) +
              (features.apkPersistenceIndicator ? 8 : 0) +
              (features.apkPermissionCombinationIndicator ? 8 : 0) +
              (features.apkDynamicCodeIndicator ? 6 : 0) +
              (features.archiveExecutableIndicator ? 8 : 0) +
              (features.archiveBombIndicator ? 8 : 0) +
              (features.archiveNestedIndicator ? 4 : 0);
    final int intelligenceBonus = maliciousIntelligence
        ? 20
        : suspiciousIntelligence
        ? 8
        : 0;
    int adjustedScore = (score + signalBonus + intelligenceBonus).clamp(0, 100);
    if (maliciousIntelligence && adjustedScore < 85) adjustedScore = 85;
    if (suspiciousIntelligence &&
        verdict == ThreatVerdict.unknown &&
        adjustedScore < 55) {
      adjustedScore = 55;
    }
    final bool justifiedCritical =
        status == ThreatResultStatus.complete &&
        strongSignalCount >= 3 &&
        adjustedScore >= 95;
    final ThreatVerdict adjustedVerdict = justifiedCritical
        ? ThreatVerdict.critical
        : maliciousIntelligence &&
              (verdict == ThreatVerdict.low ||
                  verdict == ThreatVerdict.medium ||
                  verdict == ThreatVerdict.unknown)
        ? ThreatVerdict.high
        : suspiciousIntelligence && verdict == ThreatVerdict.unknown
        ? ThreatVerdict.medium
        : verdict;
    final ThreatFeatures adjustedFeatures = maliciousIntelligence
        ? features.copyWith(knownThreat: true)
        : features;
    final List<ThreatIntelligenceResult> actionableIntelligence =
        threatIntelligenceResults
            .where(
              (ThreatIntelligenceResult result) =>
                  result.status == ThreatIntelligenceStatus.malicious ||
                  result.status == ThreatIntelligenceStatus.suspicious,
            )
            .toList(growable: false);
    final List<String> intelligenceEvidence = actionableIntelligence
        .expand(
          (ThreatIntelligenceResult result) => <String>[
            'Threat intelligence: ${result.status.name.toUpperCase()}',
            ...result.matchedEvidence,
          ],
        )
        .toList(growable: false);
    final Map<String, List<String>> structuredEvidence = <String, List<String>>{
      ...analysis.structuredEvidence,
      if (intelligenceEvidence.isNotEmpty)
        'THREAT_INTELLIGENCE': List<String>.unmodifiable(intelligenceEvidence),
    };
    return ThreatAnalysisResult(
      requestId: request.requestId,
      status: status,
      verdict: adjustedVerdict,
      riskScore: adjustedScore,
      confidence: adjustedVerdict == ThreatVerdict.unknown
          ? 0
          : justifiedCritical
          ? 0.9
          : confidence,
      detectedThreats: List<String>.unmodifiable(analysis.indicators),
      evidence: List<String>.unmodifiable(<String>[
        'Analyzer: ${analysis.analyzerName}',
        ...analysis.indicators,
        ...intelligenceEvidence,
      ]),
      recommendedActions: List<String>.unmodifiable(analysis.recommendations),
      analyzedAt: DateTime.now(),
      analyzerResults: List<String>.unmodifiable(<String>{
        analysis.analyzerName,
        if (actionableIntelligence.isNotEmpty) 'Threat intelligence',
      }),
      durationMs: durationMs,
      features: adjustedFeatures,
      sha256: request.sha256,
      inputType: request.inputType,
      detectedType: request.inputType,
      structuredEvidence: structuredEvidence,
      threatIntelligenceResults: List<ThreatIntelligenceResult>.unmodifiable(
        threatIntelligenceResults,
      ),
    );
  }
}

class ThreatAnalysisEngine extends ThreatAnalysisOrchestrator {
  const ThreatAnalysisEngine({
    super.analysisService,
    super.fusionEngine,
    super.config,
    super.validator,
    super.classifier,
    super.quarantineStorage,
    super.auditLogger,
    super.threatIntelligenceGateway,
    super.analysisExecutor,
  });
}
