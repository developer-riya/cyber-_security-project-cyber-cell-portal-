import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ShareThreatAnalysisService service = ShareThreatAnalysisService();

  test('flags several common phishing signals as high risk', () {
    final IncomingSharePayload payload =
        IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
          'id': 'risk',
          'receivedAt': 1,
          'text': 'URGENT: verify your bank account OTP at http://bit.ly/check',
          'items': const <Object?>[],
        });

    final ShareThreatAnalysis analysis = service.analyze(payload);

    expect(analysis.risk, ShareThreatRisk.highRisk);
    expect(analysis.indicators, isNotEmpty);
  });

  test(
    'keeps shared documents unexecuted and marks detailed inspection pending',
    () {
      final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
        <Object?, Object?>{
          'id': 'pdf',
          'receivedAt': 1,
          'items': <Object?>[
            <Object?, Object?>{
              'uri': 'content://example/document.pdf',
              'mimeType': 'application/pdf',
              'contentType': 'pdf',
              'fileName': 'document.pdf',
              'isAccessible': true,
            },
          ],
        },
      );

      final ShareThreatAnalysis analysis = service.analyze(payload);

      expect(analysis.risk, ShareThreatRisk.unsupported);
      expect(analysis.message, contains('not opened or executed'));
    },
  );

  test('accepts an APK without claiming that it is safe', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'apk',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/app.apk',
            'mimeType': 'application/vnd.android.package-archive',
            'fileName': 'app.apk',
            'isAccessible': true,
          },
        ],
      },
    );

    final ShareThreatAnalysis analysis = service.analyze(payload);

    expect(analysis.status, ShareAnalysisStatus.analysisUnavailable);
    expect(analysis.title, 'APK received safely');
    expect(analysis.message, isNot(contains('safe')));
    expect(analysis.message, contains('not installed'));
  });

  test('accepts unknown files and reports analysis unavailable', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'unknown',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/data.custom',
            'mimeType': 'application/x-custom-binary',
            'fileName': 'data.custom',
            'isAccessible': true,
          },
        ],
      },
    );

    final ShareThreatAnalysis analysis = service.analyze(payload);

    expect(analysis.status, ShareAnalysisStatus.analysisUnavailable);
    expect(analysis.title, 'File received');
    expect(analysis.message, contains('received this item safely'));
  });

  test('explains when a shared file exceeds the safe size limit', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'large',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/large.zip',
            'mimeType': 'application/zip',
            'fileName': 'large.zip',
            'isAccessible': false,
            'error': 'This file is larger than the safe review limit.',
          },
        ],
      },
    );

    final ShareThreatAnalysis analysis = service.analyze(payload);

    expect(analysis.status, ShareAnalysisStatus.error);
    expect(analysis.title, 'This file is too large to analyze safely');
  });
}
