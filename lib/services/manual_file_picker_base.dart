import 'dart:typed_data';

class ManualPickedFile {
  const ManualPickedFile({
    required this.name,
    required this.sizeBytes,
    this.mimeType,
    this.reference,
    this.bytes,
  });

  final String name;
  final int sizeBytes;
  final String? mimeType;
  final String? reference;
  final Uint8List? bytes;
}

abstract interface class ManualFilePicker {
  Future<ManualPickedFile?> pickFile({
    required bool apkOnly,
    required int maxBytes,
  });
}

class ManualFilePickerException implements Exception {
  const ManualFilePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}
