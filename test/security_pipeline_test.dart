import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/security_audit_logger.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quarantines metadata, emits audit events, and cleans up', () async {
    final InMemorySecurityAuditLogger audit = InMemorySecurityAuditLogger();
    const InMemoryQuarantineStorage quarantine = InMemoryQuarantineStorage();
    final ThreatAnalysisEngine engine = ThreatAnalysisEngine(
      auditLogger: audit,
      quarantineStorage: quarantine,
    );
    final IncomingSharePayload payload =
        IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
          'id': 'pipeline-url',
          'receivedAt': 1,
          'text': 'https://example.com',
          'items': const <Object?>[],
        });

    final ThreatAnalysisRun run = await engine.analyze(payload);

    expect(run.result.requestId, 'pipeline-url');
    expect(run.result.verdict, ThreatVerdict.low);
    expect(await quarantine.exists('pipeline-url'), isFalse);
    expect(
      audit.events.map((event) => event.type),
      containsAll(<SecurityAuditEventType>[
        SecurityAuditEventType.analysisRequested,
        SecurityAuditEventType.quarantined,
        SecurityAuditEventType.verdictGenerated,
        SecurityAuditEventType.quarantineCleanup,
      ]),
    );
  });

  test('type mismatch returns UNKNOWN without analyzing the content', () async {
    const ThreatAnalysisEngine engine = ThreatAnalysisEngine();
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'pipeline-mismatch',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/invoice.pdf',
            'mimeType': 'application/pdf',
            'detectedMimeType': 'application/zip',
            'fileTypeMismatch': true,
            'fileName': 'invoice.pdf',
            'isAccessible': true,
          },
        ],
      },
    );

    final ThreatAnalysisRun run = await engine.analyze(payload);

    expect(run.result.verdict, ThreatVerdict.unknown);
    expect(run.result.status, ThreatResultStatus.error);
    expect(run.analysis.title, 'We could not validate this item');
  });

  test('analyzer failure is inconclusive, never low risk', () async {
    const ShareThreatAnalysisService service = ShareThreatAnalysisService(
      analyzers: <ShareAnalyzer>[_ThrowingAnalyzer()],
    );
    const ThreatAnalysisEngine engine = ThreatAnalysisEngine(
      analysisService: service,
    );
    final IncomingSharePayload payload =
        IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
          'id': 'pipeline-failure',
          'receivedAt': 1,
          'text': 'hello',
          'items': const <Object?>[],
        });

    final ThreatAnalysisRun run = await engine.analyze(payload);

    expect(run.result.verdict, ThreatVerdict.unknown);
    expect(run.result.status, ThreatResultStatus.error);
  });
}

class _ThrowingAnalyzer implements ShareAnalyzer {
  const _ThrowingAnalyzer();

  @override
  String get name => 'Test failure analyzer';

  @override
  bool canAnalyze(IncomingSharePayload payload) => true;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) {
    throw StateError('controlled analyzer failure');
  }
}
