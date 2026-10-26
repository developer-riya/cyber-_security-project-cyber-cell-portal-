import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/services/image_evidence_models.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'routes suspicious OCR text and its URL through existing analyzers',
    () async {
      final ImageThreatAnalyzer analyzer = ImageThreatAnalyzer(
        extractor: _FakeExtractor(<String, ImageEvidenceExtraction>{
          'file:///quarantine/suspicious.bin': _extraction(
            text: 'URGENT: verify your bank account OTP at http://bit.ly/check',
          ),
        }),
      );

      final ShareThreatAnalysis result = await analyzer.analyze(
        _imagePayload('suspicious'),
        _quarantine('suspicious'),
      );

      expect(result.risk, ShareThreatRisk.highRisk);
      expect(result.structuredEvidence['EXTRACTED_TEXT'], isNotEmpty);
      expect(result.structuredEvidence['EXTRACTED_URLS'], <String>[
        'http://bit.ly/check',
      ]);
      expect(result.structuredEvidence['URL_ANALYSIS'], isNotEmpty);
    },
  );

  test(
    'routes QR URL through the existing URL analyzer without opening it',
    () async {
      final ImageThreatAnalyzer analyzer = ImageThreatAnalyzer(
        extractor: _FakeExtractor(<String, ImageEvidenceExtraction>{
          'file:///quarantine/qr.bin': _extraction(
            qrPayloads: const <String>['http://192.0.2.1:8443/verify?otp=1'],
          ),
        }),
      );
      final ShareThreatAnalysis result = await analyzer.analyze(
        _imagePayload('qr'),
        _quarantine('qr'),
      );

      expect(result.structuredEvidence['EXTRACTED_URLS'], hasLength(1));
      expect(
        result.structuredEvidence['URL_ANALYSIS']!.join(' '),
        contains('IP address'),
      );
    },
  );

  test('routes QR text through the existing text analyzer', () async {
    final ImageThreatAnalyzer analyzer = ImageThreatAnalyzer(
      extractor: _FakeExtractor(<String, ImageEvidenceExtraction>{
        'file:///quarantine/qr-text.bin': _extraction(
          qrPayloads: const <String>['Urgent OTP verification required'],
        ),
      }),
    );
    final ShareThreatAnalysis result = await analyzer.analyze(
      _imagePayload('qr-text'),
      _quarantine('qr-text'),
    );

    expect(
      result.structuredEvidence['TEXT_ANALYSIS']!.join(' '),
      contains('pressure language'),
    );
  });

  test(
    'returns UNKNOWN-style unavailable result when image has no extractable content',
    () async {
      final ImageThreatAnalyzer analyzer = ImageThreatAnalyzer(
        extractor: _FakeExtractor(<String, ImageEvidenceExtraction>{
          'file:///quarantine/empty.bin': _extraction(),
        }),
      );
      final ShareThreatAnalysis result = await analyzer.analyze(
        _imagePayload('empty'),
        _quarantine('empty'),
      );

      expect(result.status, ShareAnalysisStatus.analysisUnavailable);
      expect(result.message, contains('not treated as safe'));
    },
  );

  test(
    'returns unavailable when OCR or QR extraction is partial and has no indicators',
    () async {
      final ImageThreatAnalyzer analyzer = ImageThreatAnalyzer(
        extractor: _FakeExtractor(<String, ImageEvidenceExtraction>{
          'file:///quarantine/partial.bin': _extraction(
            text: 'Green tree beside a river',
            status: ImageExtractionStatus.partial,
            messages: const <String>['QR_UNAVAILABLE: test fixture'],
          ),
        }),
      );
      final ShareThreatAnalysis result = await analyzer.analyze(
        _imagePayload('partial'),
        _quarantine('partial'),
      );

      expect(result.status, ShareAnalysisStatus.analysisUnavailable);
      expect(result.title, 'Image analysis is partial');
    },
  );

  test(
    'retains evidence for multiple images instead of silently discarding them',
    () async {
      final ImageThreatAnalyzer analyzer = ImageThreatAnalyzer(
        extractor: _FakeExtractor(<String, ImageEvidenceExtraction>{
          'file:///quarantine/multi-one.bin': _extraction(text: 'Hello'),
          'file:///quarantine/multi-two.bin': _extraction(
            text: 'Urgent bank account OTP',
          ),
        }),
      );
      final IncomingSharePayload payload = IncomingSharePayload(
        id: 'multi',
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1),
        attachments: <IncomingShareAttachment>[
          _attachment('one.png'),
          _attachment('two.png'),
        ],
      );
      final QuarantineRecord quarantine = QuarantineRecord(
        requestId: 'multi',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now(),
        metadata: const <String, Object?>{},
        contents: const <QuarantinedContent>[
          QuarantinedContent(
            attachmentIndex: 0,
            reference: 'file:///quarantine/multi-one.bin',
            sizeBytes: 1,
          ),
          QuarantinedContent(
            attachmentIndex: 1,
            reference: 'file:///quarantine/multi-two.bin',
            sizeBytes: 1,
          ),
        ],
      );

      final ShareThreatAnalysis result = await analyzer.analyze(
        payload,
        quarantine,
      );
      expect(result.structuredEvidence['IMAGE_FEATURES'], hasLength(2));
    },
  );
}

IncomingSharePayload _imagePayload(String id) => IncomingSharePayload(
  id: id,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(1),
  attachments: <IncomingShareAttachment>[_attachment('$id.png')],
);

IncomingShareAttachment _attachment(String name) =>
    IncomingShareAttachment.fromFileReference(
      reference: 'file:///source/$name',
      fileName: name,
      sizeBytes: 1,
      mimeType: 'image/png',
    );

QuarantineRecord _quarantine(String id) => QuarantineRecord(
  requestId: id,
  createdAt: DateTime.now(),
  expiresAt: DateTime.now(),
  metadata: const <String, Object?>{},
  contents: <QuarantinedContent>[
    QuarantinedContent(
      attachmentIndex: 0,
      reference: 'file:///quarantine/$id.bin',
      sizeBytes: 1,
    ),
  ],
);

ImageEvidenceExtraction _extraction({
  String? text,
  List<String> qrPayloads = const <String>[],
  ImageExtractionStatus status = ImageExtractionStatus.complete,
  List<String> messages = const <String>[],
}) => ImageEvidenceExtraction(
  status: status,
  ocrText: text,
  qrPayloads: qrPayloads,
  decodeDurationMs: 1,
  ocrDurationMs: 2,
  qrDurationMs: 3,
  messages: messages,
  width: 1,
  height: 1,
);

class _FakeExtractor implements ImageEvidenceExtractor {
  const _FakeExtractor(this.results);
  final Map<String, ImageEvidenceExtraction> results;

  @override
  Future<ImageEvidenceExtraction> extract(String contentReference) async =>
      results[contentReference] ??
      _extraction(status: ImageExtractionStatus.failed);
}
