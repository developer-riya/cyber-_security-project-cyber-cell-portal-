enum ApkAnalysisStatus { complete, partial, unknown, unsupported }

class ApkComponentMetadata {
  const ApkComponentMetadata({
    required this.type,
    required this.name,
    this.exported,
    this.intentFilterCount = 0,
  });

  final String type;
  final String name;
  final bool? exported;
  final int intentFilterCount;
}

class ApkNativeLibraryMetadata {
  const ApkNativeLibraryMetadata({
    required this.path,
    required this.abi,
    required this.sizeBytes,
    required this.sha256,
  });

  final String path;
  final String abi;
  final int sizeBytes;
  final String? sha256;
}

class ApkManifestMetadata {
  const ApkManifestMetadata({
    this.packageName,
    this.applicationLabel,
    this.versionCode,
    this.versionName,
    this.minSdk,
    this.targetSdk,
    this.debuggable,
    this.allowBackup,
    this.permissions = const <String>[],
    this.components = const <ApkComponentMetadata>[],
  });

  final String? packageName;
  final String? applicationLabel;
  final String? versionCode;
  final String? versionName;
  final String? minSdk;
  final String? targetSdk;
  final bool? debuggable;
  final bool? allowBackup;
  final List<String> permissions;
  final List<ApkComponentMetadata> components;
}

class ApkSignatureMetadata {
  const ApkSignatureMetadata({
    required this.present,
    required this.entries,
    this.digest,
    this.analysisAvailable = false,
  });

  final bool present;
  final List<String> entries;
  final String? digest;
  final bool analysisAvailable;
}

class ApkStaticAnalysisResult {
  const ApkStaticAnalysisResult({
    required this.status,
    required this.evidence,
    required this.indicators,
    required this.extractedUrls,
    required this.textSamples,
    required this.manifest,
    required this.dexCount,
    required this.nativeLibraries,
    required this.signature,
    required this.timingsMs,
    this.error,
  });

  final ApkAnalysisStatus status;
  final Map<String, List<String>> evidence;
  final List<String> indicators;
  final List<String> extractedUrls;
  final List<String> textSamples;
  final ApkManifestMetadata manifest;
  final int dexCount;
  final List<ApkNativeLibraryMetadata> nativeLibraries;
  final ApkSignatureMetadata signature;
  final Map<String, int> timingsMs;
  final String? error;
}

abstract interface class ApkStaticAnalyzer {
  Future<ApkStaticAnalysisResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  });
}
