import 'document_intelligence_models.dart';

class LocalDocumentIntelligence implements DocumentIntelligence {
  const LocalDocumentIntelligence();

  @override
  Future<DocumentIntelligenceResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  }) async => DocumentIntelligenceResult(
    status: DocumentIntelligenceStatus.unsupported,
    documentType: 'document',
    evidence: const <String, List<String>>{
      'PDF_ANALYSIS_STATUS': <String>[
        'UNSUPPORTED_PLATFORM: local document bytes are not available here.',
      ],
    },
    extractedUrls: const <String>[],
    indicators: const <String>[
      'Document analysis is unavailable on this platform.',
    ],
    metadata: const DocumentMetadata(),
    timingsMs: const <String, int>{'total': 0},
    error: 'Document bytes were unavailable for local static inspection.',
  );
}
