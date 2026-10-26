import '../models/incoming_share_payload.dart';
import 'file_type_validation.dart';

class InputClassification {
  const InputClassification({
    required this.inputType,
    required this.detectedType,
    required this.hasTypeMismatch,
  });

  final IncomingShareContentType inputType;
  final IncomingShareContentType? detectedType;
  final bool hasTypeMismatch;
}

class InputClassifier {
  const InputClassifier();

  InputClassification classify(
    IncomingSharePayload payload, {
    List<FileTypeValidationResult> fileTypes =
        const <FileTypeValidationResult>[],
  }) {
    final IncomingShareAttachment? first = payload.attachments.isEmpty
        ? null
        : payload.attachments.first;
    return InputClassification(
      inputType: payload.primaryType,
      detectedType: first?.contentType,
      hasTypeMismatch:
          payload.hasTypeMismatch || fileTypes.any((type) => type.mismatch),
    );
  }
}
