import 'archive_static_analysis_models.dart';
import 'apk_static_analysis_models.dart';
import 'security_pipeline_config.dart';

class LocalArchiveStaticAnalyzer implements ArchiveStaticAnalyzer {
  const LocalArchiveStaticAnalyzer({
    this.config = const SecurityPipelineConfig(),
  });

  final SecurityPipelineConfig config;

  @override
  Future<ArchiveStaticAnalysisResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  }) async => const ArchiveStaticAnalysisResult(
    status: ArchiveAnalysisStatus.unsupported,
    evidence: <String, List<String>>{
      'ARCHIVE_ANALYSIS_STATUS': <String>[
        'UNSUPPORTED: local ZIP inspection is unavailable on this platform.',
      ],
    },
    indicators: <String>['ARCHIVE_ANALYSIS_UNAVAILABLE'],
    extractedUrls: <String>[],
    textSamples: <String>[],
    entries: <ArchiveEntryMetadata>[],
    apkResults: <ApkStaticAnalysisResult>[],
    timingsMs: <String, int>{'total': 0},
    error: 'ZIP inspection is unavailable on this platform.',
  );
}
