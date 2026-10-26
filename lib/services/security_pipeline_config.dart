class SecurityPipelineConfig {
  const SecurityPipelineConfig({
    this.maxFileSizeBytes = 25 * 1024 * 1024,
    this.maxArchiveSizeBytes = 25 * 1024 * 1024,
    this.maxExtractedSizeBytes = 100 * 1024 * 1024,
    this.maxArchiveFiles = 1000,
    this.maxArchiveDepth = 1,
    this.maxArchiveCompressionRatio = 100,
    this.maxArchiveInspectedBytes = 25 * 1024 * 1024,
    this.maxSharedItemCount = 10,
    this.maxAggregateSharedSizeBytes = 50 * 1024 * 1024,
    this.maxImageDimension = 4096,
    this.maxImagePixels = 16 * 1024 * 1024,
    this.maxPdfPages = 500,
    this.maxPdfObjects = 100000,
    this.maxDocumentTextCharacters = 20000,
    this.maxApkManifestBytes = 2 * 1024 * 1024,
    this.maxApkDexBytes = 16 * 1024 * 1024,
    this.maxApkNativeLibraryBytes = 4 * 1024 * 1024,
    this.maxApkSignatureBytes = 1024 * 1024,
    this.maxApkAssetBytes = 256 * 1024,
    this.maxApkDexStrings = 20000,
    this.maxApkTextSamples = 50,
    this.maxAnalysisTime = const Duration(seconds: 60),
    this.threatIntelligenceTimeout = const Duration(seconds: 3),
    this.threatIntelligenceCacheTtl = const Duration(minutes: 10),
    this.maxThreatIntelligenceCacheEntries = 256,
    this.maxConcurrentThreatIntelligenceLookups = 8,
    this.quarantineRetention = const Duration(minutes: 15),
  });

  final int maxFileSizeBytes;
  final int maxArchiveSizeBytes;
  final int maxExtractedSizeBytes;
  final int maxArchiveFiles;
  final int maxArchiveDepth;
  final double maxArchiveCompressionRatio;
  final int maxArchiveInspectedBytes;
  final int maxSharedItemCount;
  final int maxAggregateSharedSizeBytes;
  final int maxImageDimension;
  final int maxImagePixels;
  final int maxPdfPages;
  final int maxPdfObjects;
  final int maxDocumentTextCharacters;
  final int maxApkManifestBytes;
  final int maxApkDexBytes;
  final int maxApkNativeLibraryBytes;
  final int maxApkSignatureBytes;
  final int maxApkAssetBytes;
  final int maxApkDexStrings;
  final int maxApkTextSamples;
  final Duration maxAnalysisTime;
  final Duration threatIntelligenceTimeout;
  final Duration threatIntelligenceCacheTtl;
  final int maxThreatIntelligenceCacheEntries;
  final int maxConcurrentThreatIntelligenceLookups;
  final Duration quarantineRetention;
}
