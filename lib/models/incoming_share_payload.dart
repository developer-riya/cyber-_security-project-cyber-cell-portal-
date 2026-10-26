enum IncomingShareContentType {
  link,
  message,
  image,
  pdf,
  document,
  apk,
  archive,
  audio,
  video,
  executable,
  script,
  unsupported,
}

extension IncomingShareContentTypeLabel on IncomingShareContentType {
  String get label => switch (this) {
    IncomingShareContentType.link => 'Link',
    IncomingShareContentType.message => 'Message',
    IncomingShareContentType.image => 'Image',
    IncomingShareContentType.pdf => 'PDF',
    IncomingShareContentType.document => 'Document',
    IncomingShareContentType.apk => 'Android application',
    IncomingShareContentType.archive => 'Archive',
    IncomingShareContentType.audio => 'Audio',
    IncomingShareContentType.video => 'Video',
    IncomingShareContentType.executable => 'Executable file',
    IncomingShareContentType.script => 'Script',
    IncomingShareContentType.unsupported => 'File',
  };
}

class IncomingShareAttachment {
  const IncomingShareAttachment({
    required this.uri,
    required this.mimeType,
    required this.contentType,
    this.fileName,
    this.sizeBytes,
    this.isAccessible = true,
    this.error,
    this.detectedMimeType,
    this.sha256,
    this.fileTypeMismatch = false,
    this.isTemporaryQuarantineSource = false,
  });

  factory IncomingShareAttachment.fromPlatformMap(Map<Object?, Object?> map) {
    final String mimeType = (map['mimeType'] as String? ?? '').toLowerCase();
    return IncomingShareAttachment(
      uri: map['uri'] as String? ?? '',
      mimeType: mimeType,
      contentType: _contentTypeFromPlatform(
        map['contentType'] as String?,
        mimeType,
        map['fileName'] as String?,
      ),
      fileName: map['fileName'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
      isAccessible: map['isAccessible'] as bool? ?? true,
      error: map['error'] as String?,
      detectedMimeType: map['detectedMimeType'] as String?,
      sha256: map['sha256'] as String?,
      fileTypeMismatch: map['fileTypeMismatch'] as bool? ?? false,
      isTemporaryQuarantineSource:
          map['isTemporaryQuarantineSource'] as bool? ?? false,
    );
  }

  factory IncomingShareAttachment.fromFileReference({
    required String reference,
    required String fileName,
    required int sizeBytes,
    String? mimeType,
    bool isAccessible = true,
    String? error,
    String? detectedMimeType,
    String? sha256,
    bool fileTypeMismatch = false,
    bool isTemporaryQuarantineSource = false,
  }) {
    final String normalizedMimeType = (mimeType ?? '').toLowerCase();
    return IncomingShareAttachment(
      uri: reference,
      mimeType: normalizedMimeType,
      contentType: _contentTypeFromPlatform(null, normalizedMimeType, fileName),
      fileName: fileName,
      sizeBytes: sizeBytes,
      isAccessible: isAccessible,
      error: error,
      detectedMimeType: detectedMimeType,
      sha256: sha256,
      fileTypeMismatch: fileTypeMismatch,
      isTemporaryQuarantineSource: isTemporaryQuarantineSource,
    );
  }

  final String uri;
  final String mimeType;
  final IncomingShareContentType contentType;
  final String? fileName;
  final int? sizeBytes;
  final bool isAccessible;
  final String? error;
  final String? detectedMimeType;
  final String? sha256;
  final bool fileTypeMismatch;
  final bool isTemporaryQuarantineSource;

  String get displayName {
    final String? name = fileName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Shared ${contentType.label.toLowerCase()}';
  }

  static IncomingShareContentType _contentTypeFromPlatform(
    String? value,
    String mimeType,
    String? fileName,
  ) {
    final String extension = fileName?.split('.').last.toLowerCase() ?? '';
    return switch (value) {
      'image' => IncomingShareContentType.image,
      'pdf' => IncomingShareContentType.pdf,
      'document' => IncomingShareContentType.document,
      'apk' => IncomingShareContentType.apk,
      'archive' => IncomingShareContentType.archive,
      'audio' => IncomingShareContentType.audio,
      'video' => IncomingShareContentType.video,
      'executable' => IncomingShareContentType.executable,
      'script' => IncomingShareContentType.script,
      'unsupported' => IncomingShareContentType.unsupported,
      _ when mimeType.startsWith('image/') => IncomingShareContentType.image,
      _
          when <String>{
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'heic',
          }.contains(extension) =>
        IncomingShareContentType.image,
      _ when mimeType == 'application/pdf' => IncomingShareContentType.pdf,
      _ when extension == 'pdf' => IncomingShareContentType.pdf,
      _ when mimeType == 'application/vnd.android.package-archive' =>
        IncomingShareContentType.apk,
      _ when extension == 'apk' => IncomingShareContentType.apk,
      _ when mimeType.startsWith('audio/') => IncomingShareContentType.audio,
      _ when <String>{'mp3', 'wav', 'm4a', 'aac', 'ogg'}.contains(extension) =>
        IncomingShareContentType.audio,
      _ when mimeType.startsWith('video/') => IncomingShareContentType.video,
      _ when <String>{'mp4', 'mov', 'mkv', 'avi', 'webm'}.contains(extension) =>
        IncomingShareContentType.video,
      _
          when mimeType == 'application/zip' ||
              mimeType == 'application/x-7z-compressed' ||
              mimeType == 'application/x-rar-compressed' ||
              mimeType == 'application/gzip' ||
              mimeType == 'application/x-tar' =>
        IncomingShareContentType.archive,
      _ when <String>{'zip', '7z', 'rar', 'gz', 'tar'}.contains(extension) =>
        IncomingShareContentType.archive,
      _
          when mimeType.startsWith('text/') ||
              mimeType.contains('word') ||
              mimeType.contains('document') ||
              mimeType.contains('spreadsheet') ||
              mimeType.contains('excel') =>
        IncomingShareContentType.document,
      _
          when mimeType == 'application/x-sh' ||
              mimeType == 'application/x-bat' ||
              mimeType == 'text/x-python' ||
              mimeType == 'text/javascript' =>
        IncomingShareContentType.script,
      _
          when <String>{
            'sh',
            'bat',
            'cmd',
            'js',
            'py',
            'ps1',
          }.contains(extension) =>
        IncomingShareContentType.script,
      _
          when <String>{
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'odt',
            'ods',
          }.contains(extension) =>
        IncomingShareContentType.document,
      _
          when mimeType == 'application/x-executable' ||
              mimeType == 'application/vnd.microsoft.portable-executable' =>
        IncomingShareContentType.executable,
      _ when <String>{'exe', 'bin', 'elf'}.contains(extension) =>
        IncomingShareContentType.executable,
      _ => IncomingShareContentType.unsupported,
    };
  }
}

class IncomingSharePayload {
  const IncomingSharePayload({
    required this.id,
    required this.receivedAt,
    required this.attachments,
    this.text,
    this.mimeType,
    this.sourceApplication,
    this.explicitUrls = const <String>[],
    this.intakeError,
  });

  factory IncomingSharePayload.fromPlatformMap(Map<Object?, Object?> map) {
    final List<Object?> rawItems = map['items'] is List<Object?>
        ? map['items'] as List<Object?>
        : const <Object?>[];
    final List<IncomingShareAttachment> attachments = rawItems
        .whereType<Map<Object?, Object?>>()
        .map(IncomingShareAttachment.fromPlatformMap)
        .toList(growable: false);
    return IncomingSharePayload(
      id:
          map['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['receivedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      text: _trimmedOrNull(map['text'] as String?),
      mimeType: _trimmedOrNull(map['mimeType'] as String?),
      sourceApplication: _trimmedOrNull(map['sourceApplication'] as String?),
      attachments: attachments,
      intakeError: map['intakeError'] as String?,
    );
  }

  factory IncomingSharePayload.fromManualFiles(
    List<IncomingShareAttachment> attachments,
  ) {
    return IncomingSharePayload(
      id: 'upload-${DateTime.now().microsecondsSinceEpoch}',
      receivedAt: DateTime.now(),
      attachments: List<IncomingShareAttachment>.unmodifiable(attachments),
      sourceApplication: 'Cyber Uday file picker',
    );
  }

  factory IncomingSharePayload.fromManualUrl(String url, {String? note}) {
    final String trimmedUrl = url.trim();
    return IncomingSharePayload(
      id: 'url-${DateTime.now().microsecondsSinceEpoch}',
      receivedAt: DateTime.now(),
      text: note == null || note.trim().isEmpty
          ? trimmedUrl
          : '${note.trim()}\n$trimmedUrl',
      attachments: const <IncomingShareAttachment>[],
      sourceApplication: 'Cyber Uday manual scanner',
      explicitUrls: <String>[trimmedUrl],
    );
  }

  final String id;
  final DateTime receivedAt;
  final String? text;
  final String? mimeType;
  final List<IncomingShareAttachment> attachments;
  final String? sourceApplication;
  final List<String> explicitUrls;
  final String? intakeError;

  static final RegExp _urlExpression = RegExp(
    r'(?:(?:https?://)|(?:www\.))[\w.-]+(?:\.[\w.-]+)+(?:[^\s<>]*)?',
    caseSensitive: false,
  );

  List<String> get urls => explicitUrls.isNotEmpty
      ? List<String>.unmodifiable(explicitUrls)
      : _urlExpression
            .allMatches(text ?? '')
            .map((match) => match.group(0)!)
            .toList(growable: false);

  IncomingShareContentType get primaryType {
    if (urls.isNotEmpty) return IncomingShareContentType.link;
    if (attachments.isNotEmpty) return attachments.first.contentType;
    return IncomingShareContentType.message;
  }

  String get primaryPreview {
    if (primaryType == IncomingShareContentType.link) return urls.first;
    if (attachments.isNotEmpty) return attachments.first.displayName;
    return text ?? 'Shared item';
  }

  bool get hasInaccessibleAttachment =>
      attachments.any((attachment) => !attachment.isAccessible);

  bool get hasOversizedAttachment => attachments.any(
    (attachment) =>
        attachment.error?.toLowerCase().contains('larger than the safe') ??
        false,
  );

  bool get hasTypeMismatch =>
      attachments.any((attachment) => attachment.fileTypeMismatch);

  bool get isMultiple => attachments.length > 1;

  String get displayTitle {
    if (primaryType == IncomingShareContentType.link) {
      return 'Suspicious link received';
    }
    if (primaryType == IncomingShareContentType.apk) {
      return 'Android application received';
    }
    if (primaryType == IncomingShareContentType.pdf) {
      return 'PDF document received';
    }
    if (primaryType == IncomingShareContentType.message) {
      return 'Message received';
    }
    if (attachments.isNotEmpty) {
      return '${primaryType.label} received';
    }
    return 'File received';
  }

  static String? _trimmedOrNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
