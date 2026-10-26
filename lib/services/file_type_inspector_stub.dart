import '../models/incoming_share_payload.dart';
import 'file_type_validation.dart';
import 'quarantine_storage.dart';
import 'security_pipeline_config.dart';

class FileTypeInspector {
  const FileTypeInspector({this.config = const SecurityPipelineConfig()});

  final SecurityPipelineConfig config;

  Future<List<FileTypeValidationResult>> inspect(
    IncomingSharePayload payload,
    QuarantineRecord quarantine,
  ) async => payload.attachments
      .map(
        (attachment) => FileTypeValidationResult(
          declaredType: attachment.mimeType,
          detectedType: attachment.detectedMimeType,
          extension: attachment.fileName?.split('.').last.toLowerCase() ?? '',
          mismatch: attachment.fileTypeMismatch,
          structurallyValid: null,
          confidence: FileTypeValidationConfidence.none,
          reason: 'Temporary file content is unavailable on this platform.',
        ),
      )
      .toList(growable: false);
}
