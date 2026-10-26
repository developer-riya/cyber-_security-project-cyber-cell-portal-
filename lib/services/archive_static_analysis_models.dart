import 'apk_static_analysis_models.dart';

enum ArchiveAnalysisStatus { complete, partial, unknown, unsupported }

class ArchiveEntryMetadata {
  const ArchiveEntryMetadata({
    required this.path,
    required this.extension,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.compressionMethod,
    required this.depth,
    required this.isNestedArchive,
    required this.isExecutableLike,
  });

  final String path;
  final String extension;
  final int compressedSize;
  final int uncompressedSize;
  final int compressionMethod;
  final int depth;
  final bool isNestedArchive;
  final bool isExecutableLike;
}

class ArchiveStaticAnalysisResult {
  const ArchiveStaticAnalysisResult({
    required this.status,
    required this.evidence,
    required this.indicators,
    required this.extractedUrls,
    required this.textSamples,
    required this.entries,
    required this.apkResults,
    required this.timingsMs,
    this.error,
  });

  final ArchiveAnalysisStatus status;
  final Map<String, List<String>> evidence;
  final List<String> indicators;
  final List<String> extractedUrls;
  final List<String> textSamples;
  final List<ArchiveEntryMetadata> entries;
  final List<ApkStaticAnalysisResult> apkResults;
  final Map<String, int> timingsMs;
  final String? error;
}

abstract interface class ArchiveStaticAnalyzer {
  Future<ArchiveStaticAnalysisResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  });
}
