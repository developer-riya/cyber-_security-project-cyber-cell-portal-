import 'apk_static_analysis_models.dart';
import 'security_pipeline_config.dart';

class LocalApkStaticAnalyzer implements ApkStaticAnalyzer {
  const LocalApkStaticAnalyzer({this.config = const SecurityPipelineConfig()});

  final SecurityPipelineConfig config;

  @override
  Future<ApkStaticAnalysisResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  }) async => const ApkStaticAnalysisResult(
    status: ApkAnalysisStatus.unsupported,
    evidence: <String, List<String>>{
      'APK_ANALYSIS_STATUS': <String>[
        'UNSUPPORTED: local APK static inspection is unavailable on this platform.',
      ],
    },
    indicators: <String>['SIGNATURE_ANALYSIS_UNAVAILABLE'],
    extractedUrls: <String>[],
    textSamples: <String>[],
    manifest: ApkManifestMetadata(),
    dexCount: 0,
    nativeLibraries: <ApkNativeLibraryMetadata>[],
    signature: ApkSignatureMetadata(present: false, entries: <String>[]),
    timingsMs: <String, int>{'total': 0},
    error: 'APK static inspection is unavailable on this platform.',
  );
}
