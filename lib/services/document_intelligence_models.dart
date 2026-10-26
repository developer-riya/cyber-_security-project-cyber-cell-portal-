enum DocumentIntelligenceStatus { complete, partial, unknown, unsupported }

class DocumentMetadata {
  const DocumentMetadata({
    this.title,
    this.author,
    this.creator,
    this.producer,
    this.creationDate,
    this.modificationDate,
    this.pageCount,
    this.pdfVersion,
  });

  final String? title;
  final String? author;
  final String? creator;
  final String? producer;
  final String? creationDate;
  final String? modificationDate;
  final int? pageCount;
  final String? pdfVersion;
}

class DocumentIntelligenceResult {
  const DocumentIntelligenceResult({
    required this.status,
    required this.documentType,
    required this.evidence,
    required this.extractedUrls,
    required this.indicators,
    required this.metadata,
    required this.timingsMs,
    this.extractedText,
    this.error,
    this.encrypted = false,
  });

  final DocumentIntelligenceStatus status;
  final String documentType;
  final Map<String, List<String>> evidence;
  final List<String> extractedUrls;
  final List<String> indicators;
  final DocumentMetadata metadata;
  final Map<String, int> timingsMs;
  final String? extractedText;
  final String? error;
  final bool encrypted;
}

abstract interface class DocumentIntelligence {
  Future<DocumentIntelligenceResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  });
}
