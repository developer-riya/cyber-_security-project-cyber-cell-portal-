import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'manual_file_picker_base.dart';

ManualFilePicker createPlatformManualFilePicker() =>
    const BrowserManualFilePicker();

class BrowserManualFilePicker implements ManualFilePicker {
  const BrowserManualFilePicker();

  static const String _generalAccept =
      'image/*,application/pdf,application/vnd.android.package-archive,'
      'application/zip,text/plain,.apk,.zip,.pdf';
  static const String _apkAccept =
      'application/vnd.android.package-archive,.apk';

  @override
  Future<ManualPickedFile?> pickFile({
    required bool apkOnly,
    required int maxBytes,
  }) async {
    final web.HTMLInputElement input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = false
      ..accept = apkOnly ? _apkAccept : _generalAccept
      ..style.display = 'none';
    final Completer<ManualPickedFile?> result = Completer<ManualPickedFile?>();
    bool selectionChanged = false;

    void complete(ManualPickedFile? file) {
      if (!result.isCompleted) result.complete(file);
    }

    void cancelListener(web.Event _) {
      complete(null);
    }

    void focusListener(web.Event _) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!selectionChanged) complete(null);
      });
    }

    final StreamSubscription<web.Event> changeSubscription = input.onChange
        .listen((web.Event _) async {
          selectionChanged = true;
          final web.File? file = input.files?.item(0);
          if (file == null) {
            complete(null);
            return;
          }
          if (file.size > maxBytes) {
            complete(
              ManualPickedFile(
                name: file.name,
                sizeBytes: file.size,
                mimeType: file.type,
              ),
            );
            return;
          }

          try {
            final web.FileReader reader = web.FileReader();
            final Completer<Uint8List> bytes = Completer<Uint8List>();
            late final StreamSubscription<web.ProgressEvent> loadSubscription;
            loadSubscription = reader.onLoadEnd.listen((_) {
              final ByteBuffer? buffer =
                  (reader.result as JSArrayBuffer?)?.toDart;
              if (buffer == null) {
                if (!bytes.isCompleted) {
                  bytes.completeError(
                    const ManualFilePickerException(
                      'Cyber Uday could not read the selected file.',
                    ),
                  );
                }
                return;
              }
              if (!bytes.isCompleted) bytes.complete(buffer.asUint8List());
            });
            reader.readAsArrayBuffer(file);
            final Uint8List selectedBytes = await bytes.future;
            await loadSubscription.cancel();
            complete(
              ManualPickedFile(
                name: file.name,
                sizeBytes: selectedBytes.length,
                mimeType: file.type,
                bytes: selectedBytes,
              ),
            );
          } catch (error, stackTrace) {
            if (!result.isCompleted) result.completeError(error, stackTrace);
          }
        });

    input.addEventListener('cancel', cancelListener.toJS);
    web.window.addEventListener('focus', focusListener.toJS);
    web.document.body?.append(input);
    input.click();

    try {
      return await result.future;
    } finally {
      await changeSubscription.cancel();
      input.removeEventListener('cancel', cancelListener.toJS);
      web.window.removeEventListener('focus', focusListener.toJS);
      input.remove();
    }
  }
}
