import 'package:file_picker/file_picker.dart';

import 'manual_file_picker_base.dart';

ManualFilePicker createPlatformManualFilePicker() =>
    const PlatformManualFilePicker();

class PlatformManualFilePicker implements ManualFilePicker {
  const PlatformManualFilePicker();

  @override
  Future<ManualPickedFile?> pickFile({
    required bool apkOnly,
    required int maxBytes,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: apkOnly ? FileType.custom : FileType.any,
      allowedExtensions: apkOnly ? <String>['apk'] : null,
      withData: false,
      withReadStream: false,
      dialogTitle: apkOnly
          ? 'Choose an APK to check'
          : 'Choose a file to check',
    );
    if (result == null || result.files.isEmpty) return null;

    final PlatformFile file = result.files.single;
    return ManualPickedFile(
      name: file.name,
      sizeBytes: file.size,
      reference: file.path,
    );
  }
}
