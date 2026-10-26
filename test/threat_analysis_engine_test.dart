import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ThreatAnalysisEngine engine = ThreatAnalysisEngine();

  test('fuses URL indicators into a structured high-risk result', () async {
    final IncomingSharePayload payload =
        IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
          'id': 'engine-risk',
          'receivedAt': 1,
          'text': 'URGENT verify bank account OTP at http://bit.ly/check',
          'items': const <Object?>[],
        });
    final List<ThreatAnalysisStage> stages = <ThreatAnalysisStage>[];

    final ThreatAnalysisRun run = await engine.analyze(
      payload,
      onStage: stages.add,
    );

    expect(run.result.verdict, ThreatVerdict.high);
    expect(run.result.riskScore, greaterThanOrEqualTo(80));
    expect(run.result.requestId, 'engine-risk');
    expect(run.result.durationMs, greaterThanOrEqualTo(0));
    expect(stages, contains(ThreatAnalysisStage.calculatingRisk));
  });

  test('keeps unavailable document analysis separate from low risk', () async {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'engine-document',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/report.pdf',
            'mimeType': 'application/pdf',
            'fileName': 'report.pdf',
            'isAccessible': true,
          },
        ],
      },
    );

    final ThreatAnalysisRun run = await engine.analyze(payload);

    expect(run.result.status, ThreatResultStatus.analysisUnavailable);
    expect(run.result.verdict, ThreatVerdict.unknown);
    expect(run.result.riskScore, 0);
  });
}
