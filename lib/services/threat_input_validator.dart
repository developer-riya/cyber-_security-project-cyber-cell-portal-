import '../models/incoming_share_payload.dart';
import '../models/threat_analysis.dart';
import 'file_type_validation.dart';
import 'security_pipeline_config.dart';

class ThreatValidationResult {
  const ThreatValidationResult({
    required this.isValid,
    required this.isPartial,
    required this.errors,
    required this.warnings,
  });

  final bool isValid;
  final bool isPartial;
  final List<String> errors;
  final List<String> warnings;
}

class ThreatInputValidator {
  const ThreatInputValidator({this.config = const SecurityPipelineConfig()});

  final SecurityPipelineConfig config;

  ThreatValidationResult validate(
    IncomingSharePayload payload,
    ThreatAnalysisRequest request, {
    List<FileTypeValidationResult> fileTypes =
        const <FileTypeValidationResult>[],
  }) {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    if (payload.intakeError != null) {
      errors.add(payload.intakeError!);
    }
    if (payload.attachments.length > config.maxSharedItemCount) {
      errors.add('The shared item count exceeds the configured safety limit.');
    }
    final int aggregateSize = payload.attachments.fold<int>(
      0,
      (total, attachment) => total + (attachment.sizeBytes ?? 0),
    );
    if (aggregateSize > config.maxAggregateSharedSizeBytes) {
      errors.add(
        'The shared content exceeds the configured aggregate size limit.',
      );
    }
    if (payload.text == null && payload.attachments.isEmpty) {
      errors.add('The submitted input was empty.');
    }
    for (final IncomingShareAttachment attachment in payload.attachments) {
      if (attachment.uri.trim().isEmpty) {
        errors.add('A submitted file reference was empty.');
      }
      final int? size = attachment.sizeBytes;
      if (size != null && size < 0) {
        errors.add('A submitted file reported an invalid size.');
      }
      if (size != null && size > config.maxFileSizeBytes) {
        errors.add('A submitted file exceeds the configured size limit.');
      }
      if (!attachment.isAccessible) {
        errors.add(attachment.error ?? 'A submitted file is not readable.');
      }
      if (attachment.sha256 == null && size != 0) {
        warnings.add('A SHA-256 hash was not available for this reference.');
      }
    }
    for (final FileTypeValidationResult type in fileTypes) {
      if (type.blocksAnalysis) {
        errors.add(type.reason);
      } else if (type.structurallyValid == null) {
        warnings.add(type.reason);
      }
    }
    if (request.inputType == IncomingShareContentType.unsupported) {
      warnings.add('No specialized analyzer is available for this format.');
    }
    return ThreatValidationResult(
      isValid: errors.isEmpty,
      isPartial: errors.isEmpty && warnings.isNotEmpty,
      errors: List<String>.unmodifiable(errors),
      warnings: List<String>.unmodifiable(warnings),
    );
  }
}
