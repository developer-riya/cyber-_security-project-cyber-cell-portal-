enum FileTypeValidationConfidence { none, low, medium, high }

class FileTypeValidationResult {
  const FileTypeValidationResult({
    required this.declaredType,
    required this.detectedType,
    required this.extension,
    required this.mismatch,
    required this.structurallyValid,
    required this.confidence,
    required this.reason,
    this.archiveFileCount,
    this.archiveExtractedSize,
    this.archiveDepth,
  });

  final String? declaredType;
  final String? detectedType;
  final String extension;
  final bool mismatch;
  final bool? structurallyValid;
  final FileTypeValidationConfidence confidence;
  final String reason;
  final int? archiveFileCount;
  final int? archiveExtractedSize;
  final int? archiveDepth;

  bool get blocksAnalysis => mismatch || structurallyValid == false;
}
