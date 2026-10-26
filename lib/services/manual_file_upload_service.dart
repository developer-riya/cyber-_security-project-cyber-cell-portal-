import 'package:crypto/crypto.dart';

import '../models/incoming_share_payload.dart';
import 'file_hash_service.dart';
import 'manual_file_picker.dart';
import 'security_pipeline_config.dart';
import 'web_picked_file_store.dart';

export 'manual_file_picker_base.dart' show ManualFilePickerException;

/// Converts an explicit platform file selection into the normalized security
/// intake model. It never opens, executes, uploads, or renders the file.
class ManualFileUploadService {
  ManualFileUploadService({
    ManualFilePicker? picker,
    this.pipelineConfig = const SecurityPipelineConfig(),
  }) : _picker = picker ?? createManualFilePicker();

  final ManualFilePicker _picker;
  final SecurityPipelineConfig pipelineConfig;

  Future<IncomingSharePayload?> pickFiles({bool apkOnly = false}) async {
    final ManualPickedFile? file = await _picker.pickFile(
      apkOnly: apkOnly,
      maxBytes: pipelineConfig.maxFileSizeBytes,
    );
    if (file == null) return null;
    if (file.sizeBytes > pipelineConfig.maxFileSizeBytes) {
      throw ManualFilePickerException(_oversizedMessage);
    }

    final IncomingShareAttachment attachment = await _toAttachment(file);
    return IncomingSharePayload.fromManualFiles(<IncomingShareAttachment>[
      attachment,
    ]);
  }

  Future<IncomingShareAttachment> _toAttachment(ManualPickedFile file) async {
    final String normalizedMimeType = file.mimeType?.trim().toLowerCase() ?? '';
    final String reference;
    final String? hash;
    if (file.bytes != null) {
      if (file.bytes!.length > pipelineConfig.maxFileSizeBytes) {
        throw ManualFilePickerException(_oversizedMessage);
      }
      hash = sha256.convert(file.bytes!).toString();
      reference = WebPickedFileStore.retain(
        name: file.name,
        mimeType: normalizedMimeType,
        bytes: file.bytes!,
        sha256: hash,
      );
    } else {
      final String? sourceReference = file.reference;
      if (sourceReference == null || sourceReference.trim().isEmpty) {
        throw const ManualFilePickerException(
          'Cyber Uday could not read the selected file.',
        );
      }
      reference = sourceReference;
      hash = await sha256ForReference(
        reference,
        maxBytes: pipelineConfig.maxFileSizeBytes,
      );
    }

    return IncomingShareAttachment.fromFileReference(
      reference: reference,
      fileName: file.name,
      sizeBytes: file.bytes?.length ?? file.sizeBytes,
      mimeType: normalizedMimeType,
      sha256: hash,
    );
  }

  void releasePayload(IncomingSharePayload payload) {
    for (final IncomingShareAttachment attachment in payload.attachments) {
      if (attachment.uri.startsWith('web-memory://')) {
        WebPickedFileStore.release(attachment.uri);
      }
    }
  }

  String get _oversizedMessage {
    final double limitMb = pipelineConfig.maxFileSizeBytes / (1024 * 1024);
    final String label = limitMb == limitMb.roundToDouble()
        ? limitMb.toStringAsFixed(0)
        : limitMb.toStringAsFixed(1);
    return 'This file is larger than the $label MB safe review limit.';
  }
}
