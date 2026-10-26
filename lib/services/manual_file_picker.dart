import 'manual_file_picker_base.dart';
import 'manual_file_picker_io.dart'
    if (dart.library.html) 'manual_file_picker_web.dart';

export 'manual_file_picker_base.dart';

ManualFilePicker createManualFilePicker() => createPlatformManualFilePicker();
