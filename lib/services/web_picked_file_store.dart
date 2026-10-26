import 'dart:typed_data';

class WebPickedFileContent {
  const WebPickedFileContent({
    required this.reference,
    required this.name,
    required this.mimeType,
    required this.bytes,
    required this.sha256,
  });

  final String reference;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String sha256;
}

class WebPickedFileStore {
  WebPickedFileStore._();

  static final Map<String, WebPickedFileContent> _contents =
      <String, WebPickedFileContent>{};
  static int _nextId = 0;

  static String retain({
    required String name,
    required String mimeType,
    required Uint8List bytes,
    required String sha256,
  }) {
    final String reference =
        'web-memory://${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    _contents[reference] = WebPickedFileContent(
      reference: reference,
      name: name,
      mimeType: mimeType,
      bytes: Uint8List.fromList(bytes),
      sha256: sha256,
    );
    return reference;
  }

  static WebPickedFileContent? read(String reference) => _contents[reference];

  static bool contains(String reference) => _contents.containsKey(reference);

  static void release(String reference) {
    _contents.remove(reference);
  }
}
