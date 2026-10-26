import 'image_evidence_models.dart';

/// Web fallback until the picker exposes bounded image bytes to the local OCR
/// adapter. It intentionally returns unavailable rather than a safe verdict.
class LocalImageEvidenceExtractor implements ImageEvidenceExtractor {
  const LocalImageEvidenceExtractor();

  @override
  Future<ImageEvidenceExtraction> extract(
    String contentReference,
  ) async => const ImageEvidenceExtraction(
    status: ImageExtractionStatus.unavailable,
    ocrText: null,
    qrPayloads: <String>[],
    decodeDurationMs: 0,
    ocrDurationMs: 0,
    qrDurationMs: 0,
    messages: <String>[
      'OCR_UNAVAILABLE: local image bytes are not available on this platform.',
      'QR_UNAVAILABLE: local image bytes are not available on this platform.',
    ],
  );
}
