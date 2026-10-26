import 'dart:io';

import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/screens/share_to_scan_screen.dart';
import 'package:cyberuday/services/input_classifier.dart';
import 'package:cyberuday/services/file_type_validation.dart';
import 'package:cyberuday/services/threat_input_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android share routing contract', () {
    test('maps supported MIME and content types to existing analyzers', () {
      final List<IncomingShareContentType> types = <IncomingShareContentType>[
        _attachment('text.txt', 'text/plain', 'document').contentType,
        _attachment('photo.png', 'image/png', 'image').contentType,
        _attachment('report.pdf', 'application/pdf', 'pdf').contentType,
        _attachment(
          'app.apk',
          'application/vnd.android.package-archive',
          'apk',
        ).contentType,
        _attachment('bundle.zip', 'application/zip', 'archive').contentType,
      ];

      expect(
        types,
        <IncomingShareContentType>[
          IncomingShareContentType.document,
          IncomingShareContentType.image,
          IncomingShareContentType.pdf,
          IncomingShareContentType.apk,
          IncomingShareContentType.archive,
        ],
      );
    });

    test('does not select an analyzer from filename alone', () {
      final IncomingShareAttachment attachment = _attachment(
        'invoice.pdf',
        'application/octet-stream',
        'unsupported',
      );
      final InputClassification classification = const InputClassifier().classify(
        IncomingSharePayload(
          id: 'filename-only',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(1),
          attachments: <IncomingShareAttachment>[attachment],
        ),
      );

      expect(classification.inputType, IncomingShareContentType.unsupported);
    });
  });

  group('bounded multiple-share intake', () {
    test('accepts mixed supported items within the configured bounds', () {
      final IncomingSharePayload payload = _payload(
        List<IncomingShareAttachment>.generate(
          4,
          (int index) => _attachment(
            'item-$index.bin',
            index.isEven ? 'application/zip' : 'application/pdf',
            index.isEven ? 'archive' : 'pdf',
            sizeBytes: 1024,
          ),
        ),
      );
      final ThreatValidationResult result = _validate(payload);

      expect(result.isValid, isTrue);
      expect(payload.isMultiple, isTrue);
    });

    test('rejects more than ten items and aggregate size above 50 MB', () {
      final List<IncomingShareAttachment> attachments =
          List<IncomingShareAttachment>.generate(
            11,
            (int index) => _attachment(
              'item-$index.zip',
              'application/zip',
              'archive',
              sizeBytes: 5 * 1024 * 1024,
            ),
          );
      final ThreatValidationResult result = _validate(_payload(attachments));

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('item count')));
      expect(result.errors, contains(contains('aggregate size')));
    });

    test('rejects one inaccessible item in an otherwise valid share', () {
      final ThreatValidationResult result = _validate(
        _payload(<IncomingShareAttachment>[
          _attachment('safe.pdf', 'application/pdf', 'pdf', sizeBytes: 12),
          _attachment(
            'revoked.pdf',
            'application/pdf',
            'pdf',
            isAccessible: false,
            error: 'The source app did not grant access to this file.',
          ),
        ]),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('did not grant access'));
    });
  });

  group('untrusted URI and content metadata', () {
    test('content URI failures become validation errors', () {
      final List<IncomingShareAttachment> attachments = <IncomingShareAttachment>[
        _attachment(
          'missing.bin',
          'application/octet-stream',
          'unsupported',
          reference: 'content://provider/missing',
          isAccessible: false,
          error: 'The shared URI is no longer available.',
        ),
        _attachment(
          'empty.bin',
          'application/octet-stream',
          'unsupported',
          reference: 'content://provider/empty',
          sizeBytes: 0,
        ),
        _attachment(
          'oversized.bin',
          'application/octet-stream',
          'unsupported',
          reference: 'content://provider/oversized',
          sizeBytes: 26 * 1024 * 1024,
        ),
      ];

      final ThreatValidationResult result = _validate(_payload(attachments));

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('no longer available')));
      expect(result.errors, contains(contains('exceeds')));
    });

    test('signature mismatch remains a downstream validation signal', () {
      final IncomingSharePayload payload = _payload(<IncomingShareAttachment>[
        _attachment(
          'invoice.pdf',
          'application/pdf',
          'pdf',
          reference: 'content://provider/not-a-pdf',
          detectedMimeType: 'application/zip',
          fileTypeMismatch: true,
        ),
      ]);

      final InputClassification classification = const InputClassifier().classify(
        payload,
        fileTypes: <FileTypeValidationResult>[
          const FileTypeValidationResult(
            declaredType: 'application/pdf',
            detectedType: 'application/zip',
            extension: 'pdf',
            mismatch: true,
            structurallyValid: false,
            confidence: FileTypeValidationConfidence.high,
            reason: 'The file signature does not match its declared type.',
          ),
        ],
      );

      expect(classification.hasTypeMismatch, isTrue);
    });
  });

  testWidgets('valid share enters the scanner surface directly', (
    WidgetTester tester,
  ) async {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'direct-share',
        'receivedAt': 1,
        'text': 'https://example.test',
        'items': const <Object?>[],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: ShareToScanScreen(payload: payload),
      ),
    );

    await tester.tap(find.text('Analyze safely'));
    await tester.pumpAndSettle();

    expect(find.text('Shared content ready to check'), findsOneWidget);
  });

  test('Android share filters stay explicit and do not accept all MIME types', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('android:mimeType="*/*"')));
    expect(manifest, contains('android:mimeType="text/plain"'));
    expect(manifest, contains('android:mimeType="image/*"'));
    expect(manifest, contains('android:mimeType="application/pdf"'));
    expect(
      manifest,
      contains('android:mimeType="application/vnd.android.package-archive"'),
    );
    expect(manifest, contains('android:mimeType="application/zip"'));
  });
}

IncomingSharePayload _payload(List<IncomingShareAttachment> attachments) =>
    IncomingSharePayload(
      id: 'share-hardening',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(1),
      attachments: attachments,
    );

ThreatValidationResult _validate(IncomingSharePayload payload) {
  final ThreatAnalysisRequest request = ThreatAnalysisRequest.fromPayload(
    payload,
  );
  return const ThreatInputValidator().validate(payload, request);
}

IncomingShareAttachment _attachment(
  String fileName,
  String mimeType,
  String contentType, {
  String? reference,
  int sizeBytes = 1024,
  bool isAccessible = true,
  String? error,
  String? detectedMimeType,
  bool fileTypeMismatch = false,
}) => IncomingShareAttachment.fromPlatformMap(<Object?, Object?>{
  'uri': reference ?? 'content://provider/$fileName',
  'mimeType': mimeType,
  'contentType': contentType,
  'fileName': fileName,
  'sizeBytes': sizeBytes,
  'isAccessible': isAccessible,
  'error': error,
  'detectedMimeType': detectedMimeType,
  'fileTypeMismatch': fileTypeMismatch,
});
