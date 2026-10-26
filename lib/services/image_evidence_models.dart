enum ImageExtractionStatus { complete, partial, unavailable, failed }

class ImageEvidenceExtraction {
  const ImageEvidenceExtraction({
    required this.status,
    required this.ocrText,
    required this.qrPayloads,
    required this.decodeDurationMs,
    required this.ocrDurationMs,
    required this.qrDurationMs,
    required this.messages,
    this.width,
    this.height,
  });

  final ImageExtractionStatus status;
  final String? ocrText;
  final List<String> qrPayloads;
  final int decodeDurationMs;
  final int ocrDurationMs;
  final int qrDurationMs;
  final List<String> messages;
  final int? width;
  final int? height;

  bool get hasExtractedContent =>
      (ocrText?.trim().isNotEmpty ?? false) || qrPayloads.isNotEmpty;
}

abstract interface class ImageEvidenceExtractor {
  Future<ImageEvidenceExtraction> extract(String contentReference);
}
