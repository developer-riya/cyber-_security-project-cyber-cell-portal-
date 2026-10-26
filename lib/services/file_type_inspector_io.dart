import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/incoming_share_payload.dart';
import 'file_type_validation.dart';
import 'quarantine_storage.dart';
import 'security_pipeline_config.dart';

/// Performs bounded signature and container checks on temporary quarantine
/// copies. It never opens files with external applications or executes them.
class FileTypeInspector {
  const FileTypeInspector({this.config = const SecurityPipelineConfig()});

  final SecurityPipelineConfig config;

  Future<List<FileTypeValidationResult>> inspect(
    IncomingSharePayload payload,
    QuarantineRecord quarantine,
  ) async {
    final Map<int, QuarantinedContent> contents = <int, QuarantinedContent>{
      for (final QuarantinedContent content in quarantine.contents)
        content.attachmentIndex: content,
    };
    final List<FileTypeValidationResult> results = <FileTypeValidationResult>[];
    for (int index = 0; index < payload.attachments.length; index++) {
      final IncomingShareAttachment attachment = payload.attachments[index];
      final QuarantinedContent? content = contents[index];
      results.add(await _inspectAttachment(attachment, content));
    }
    return List<FileTypeValidationResult>.unmodifiable(results);
  }

  Future<FileTypeValidationResult> _inspectAttachment(
    IncomingShareAttachment attachment,
    QuarantinedContent? content,
  ) async {
    final String extension = _extension(attachment.fileName);
    if (content == null) {
      return FileTypeValidationResult(
        declaredType: _orNull(attachment.mimeType),
        detectedType: attachment.detectedMimeType,
        extension: extension,
        mismatch: attachment.fileTypeMismatch,
        structurallyValid: null,
        confidence: FileTypeValidationConfidence.none,
        reason:
            'No temporary content copy was available for structural validation.',
      );
    }
    final File file = File.fromUri(Uri.parse(content.reference));
    final int size = await file.length();
    if (size == 0) {
      return _invalid(attachment, extension, 'The quarantined file is empty.');
    }
    if (size > config.maxFileSizeBytes) {
      return _invalid(
        attachment,
        extension,
        'The quarantined file exceeds the configured size limit.',
      );
    }
    final Uint8List bytes = await file.readAsBytes();
    final _Signature signature = _signature(bytes);
    final bool expectedApk = _expectsApk(attachment, extension);
    final bool expectedZip = _expectsZip(attachment, extension);
    final bool expectedPdf = _expectsPdf(attachment, extension);
    final bool expectedImage = _expectsImage(attachment, extension);

    if (signature.mimeType == 'application/zip') {
      if (bytes.length > config.maxArchiveSizeBytes) {
        return _invalid(
          attachment,
          extension,
          'The archive exceeds the configured compressed-size limit.',
        );
      }
      final _ArchiveCheck archive = _inspectArchive(bytes, expectedApk);
      final bool apkValid = expectedApk && archive.apkStructureValid;
      final String detectedType = apkValid
          ? 'application/vnd.android.package-archive'
          : 'application/zip';
      final bool mismatch =
          archive.invalid ||
          (expectedApk && !apkValid) ||
          (expectedImage || expectedPdf) ||
          (!expectedApk &&
              !expectedZip &&
              _mimeMismatches(attachment.mimeType, detectedType));
      return FileTypeValidationResult(
        declaredType: _orNull(attachment.mimeType),
        detectedType: detectedType,
        extension: extension,
        mismatch: mismatch,
        structurallyValid: archive.invalid
            ? false
            : (archive.partial ? null : true),
        confidence: archive.invalid
            ? FileTypeValidationConfidence.high
            : FileTypeValidationConfidence.medium,
        reason: archive.reason,
        archiveFileCount: archive.fileCount,
        archiveExtractedSize: archive.extractedSize,
        archiveDepth: archive.depth,
      );
    }

    if (signature.mimeType == 'application/pdf') {
      final bool validPdf = bytes.length >= 9 && _containsPdfEof(bytes);
      return FileTypeValidationResult(
        declaredType: _orNull(attachment.mimeType),
        detectedType: signature.mimeType,
        extension: extension,
        mismatch:
            !validPdf ||
            _mimeMismatches(attachment.mimeType, signature.mimeType) ||
            (!expectedPdf && extension.isNotEmpty),
        structurallyValid: validPdf,
        confidence: FileTypeValidationConfidence.medium,
        reason: validPdf
            ? 'PDF header and terminal marker were found in the temporary copy.'
            : 'The PDF header was present, but a bounded structural check failed.',
      );
    }

    if (signature.mimeType != null) {
      final bool mismatch =
          _mimeMismatches(attachment.mimeType, signature.mimeType) ||
          (expectedPdf || expectedApk || expectedZip) ||
          (expectedImage && !signature.mimeType!.startsWith('image/'));
      return FileTypeValidationResult(
        declaredType: _orNull(attachment.mimeType),
        detectedType: signature.mimeType,
        extension: extension,
        mismatch: mismatch,
        structurallyValid: true,
        confidence: FileTypeValidationConfidence.high,
        reason:
            'The temporary copy matched a recognized ${signature.label} signature.',
      );
    }

    final bool expectedStructured =
        expectedPdf || expectedApk || expectedZip || expectedImage;
    return FileTypeValidationResult(
      declaredType: _orNull(attachment.mimeType),
      detectedType: null,
      extension: extension,
      mismatch: expectedStructured || attachment.fileTypeMismatch,
      structurallyValid: expectedStructured ? false : null,
      confidence: expectedStructured
          ? FileTypeValidationConfidence.medium
          : FileTypeValidationConfidence.low,
      reason: expectedStructured
          ? 'The expected file signature was not found in the temporary copy.'
          : 'No supported signature is available for this format.',
    );
  }

  FileTypeValidationResult _invalid(
    IncomingShareAttachment attachment,
    String extension,
    String reason,
  ) => FileTypeValidationResult(
    declaredType: _orNull(attachment.mimeType),
    detectedType: attachment.detectedMimeType,
    extension: extension,
    mismatch: true,
    structurallyValid: false,
    confidence: FileTypeValidationConfidence.high,
    reason: reason,
  );

  _ArchiveCheck _inspectArchive(Uint8List bytes, bool expectedApk) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final int eocd = _findEndOfCentralDirectory(bytes);
    if (eocd < 0 || eocd + 22 > bytes.length) {
      return const _ArchiveCheck.invalid('The ZIP end record is missing.');
    }
    final int fileCount = _u16(bytes, eocd + 10);
    final int directorySize = _u32(bytes, eocd + 12);
    final int directoryOffset = _u32(bytes, eocd + 16);
    if (fileCount > config.maxArchiveFiles) {
      return _ArchiveCheck.invalid(
        'The archive exceeds the configured file-count limit.',
      );
    }
    if (directoryOffset < 0 ||
        directorySize < 0 ||
        directoryOffset + directorySize > bytes.length) {
      return const _ArchiveCheck.invalid(
        'The ZIP central directory is malformed.',
      );
    }
    int cursor = directoryOffset;
    int extractedSize = 0;
    bool hasManifest = false;
    bool hasDex = false;
    bool manifestSignatureValid = false;
    bool dexSignatureValid = false;
    bool containsNestedArchive = false;
    for (int index = 0; index < fileCount; index++) {
      if (stopwatch.elapsed > config.maxAnalysisTime) {
        return const _ArchiveCheck.invalid(
          'Archive inspection exceeded the configured time limit.',
        );
      }
      if (cursor + 46 > bytes.length || _u32(bytes, cursor) != 0x02014b50) {
        return const _ArchiveCheck.invalid(
          'A ZIP directory entry is malformed.',
        );
      }
      final int uncompressedSize = _u32(bytes, cursor + 24);
      final int nameLength = _u16(bytes, cursor + 28);
      final int extraLength = _u16(bytes, cursor + 30);
      final int commentLength = _u16(bytes, cursor + 32);
      final int nameStart = cursor + 46;
      final int next = nameStart + nameLength + extraLength + commentLength;
      if (next > bytes.length) {
        return const _ArchiveCheck.invalid(
          'A ZIP entry extends beyond the archive boundary.',
        );
      }
      final String name = String.fromCharCodes(
        bytes.sublist(nameStart, nameStart + nameLength),
      );
      if (_unsafeArchiveName(name)) {
        return const _ArchiveCheck.invalid(
          'The archive contains an unsafe entry path.',
        );
      }
      extractedSize += uncompressedSize;
      if (extractedSize > config.maxExtractedSizeBytes) {
        return _ArchiveCheck.invalid(
          'The archive exceeds the configured extracted-size limit.',
        );
      }
      hasManifest = hasManifest || name == 'AndroidManifest.xml';
      hasDex = hasDex || name == 'classes.dex';
      if (expectedApk &&
          (name == 'AndroidManifest.xml' || name == 'classes.dex')) {
        final int compressionMethod = _u16(bytes, cursor + 10);
        final int compressedSize = _u32(bytes, cursor + 20);
        final int localHeaderOffset = _u32(bytes, cursor + 42);
        final Uint8List? content = _readArchiveEntry(
          bytes,
          localHeaderOffset: localHeaderOffset,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          compressionMethod: compressionMethod,
          maxBytes: name == 'AndroidManifest.xml'
              ? config.maxApkManifestBytes
              : config.maxApkDexBytes,
        );
        if (name == 'AndroidManifest.xml') {
          manifestSignatureValid = _startsWith(content, const <int>[
            0x03,
            0x00,
            0x08,
            0x00,
          ]);
        } else {
          dexSignatureValid = _startsWith(content, const <int>[
            0x64,
            0x65,
            0x78,
            0x0a,
          ]);
        }
      }
      containsNestedArchive = containsNestedArchive || _isArchiveName(name);
      cursor = next;
    }
    if (containsNestedArchive && config.maxArchiveDepth < 2) {
      return _ArchiveCheck.invalid(
        'Nested archives exceed the configured archive-depth limit.',
      );
    }
    if (containsNestedArchive) {
      return _ArchiveCheck.partial(
        'A nested archive was detected. Recursive extraction is intentionally unavailable in this phase.',
        fileCount,
        extractedSize,
        2,
        expectedApk &&
            hasManifest &&
            hasDex &&
            manifestSignatureValid &&
            dexSignatureValid,
      );
    }
    if (expectedApk && !(hasManifest && hasDex)) {
      return _ArchiveCheck.invalid(
        'The ZIP does not contain the minimum expected Android APK entries.',
      );
    }
    if (expectedApk && !(manifestSignatureValid && dexSignatureValid)) {
      return _ArchiveCheck.invalid(
        'The ZIP contains APK-named entries, but their AndroidManifest.xml or classes.dex signatures are invalid.',
      );
    }
    return _ArchiveCheck.valid(
      expectedApk
          ? 'The ZIP contains the minimum expected Android APK entries.'
          : 'The ZIP central directory passed bounded static checks.',
      fileCount,
      extractedSize,
      1,
      expectedApk,
    );
  }
}

bool _startsWith(Uint8List? bytes, List<int> expected) =>
    bytes != null &&
    bytes.length >= expected.length &&
    expected.asMap().entries.every((entry) => bytes[entry.key] == entry.value);

Uint8List? _readArchiveEntry(
  Uint8List bytes, {
  required int localHeaderOffset,
  required int compressedSize,
  required int uncompressedSize,
  required int compressionMethod,
  required int maxBytes,
}) {
  if (uncompressedSize > maxBytes ||
      localHeaderOffset < 0 ||
      localHeaderOffset + 30 > bytes.length) {
    return null;
  }
  if (_u32(bytes, localHeaderOffset) != 0x04034b50) return null;
  final int nameLength = _u16(bytes, localHeaderOffset + 26);
  final int extraLength = _u16(bytes, localHeaderOffset + 28);
  final int dataStart = localHeaderOffset + 30 + nameLength + extraLength;
  final int dataEnd = dataStart + compressedSize;
  if (dataStart < 0 || dataEnd > bytes.length) return null;
  final Uint8List compressed = bytes.sublist(dataStart, dataEnd);
  try {
    if (compressionMethod == 0) {
      return compressed.length == uncompressedSize ? compressed : null;
    }
    if (compressionMethod == 8) {
      final _BoundedBytesSink output = _BoundedBytesSink(maxBytes);
      final ByteConversionSink decoder = ZLibDecoder(
        raw: true,
      ).startChunkedConversion(output);
      decoder
        ..add(compressed)
        ..close();
      return output.bytes.length == uncompressedSize
          ? Uint8List.fromList(output.bytes)
          : null;
    }
  } on Object {
    return null;
  }
  return null;
}

class _BoundedBytesSink implements Sink<List<int>> {
  _BoundedBytesSink(this.maxBytes);

  final int maxBytes;
  final List<int> bytes = <int>[];

  @override
  void add(List<int> chunk) {
    if (bytes.length > maxBytes - chunk.length) {
      throw StateError('Bounded archive decompression limit exceeded.');
    }
    bytes.addAll(chunk);
  }

  @override
  void close() {}
}

class _Signature {
  const _Signature(this.mimeType, this.label);

  final String? mimeType;
  final String label;
}

_Signature _signature(Uint8List bytes) {
  bool starts(List<int> expected) =>
      bytes.length >= expected.length &&
      expected.asMap().entries.every(
        (entry) => bytes[entry.key] == entry.value,
      );
  if (starts(const <int>[0x25, 0x50, 0x44, 0x46])) {
    return const _Signature('application/pdf', 'PDF');
  }
  if (starts(const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return const _Signature('image/png', 'PNG');
  }
  if (starts(const <int>[0xff, 0xd8, 0xff])) {
    return const _Signature('image/jpeg', 'JPEG');
  }
  if (starts(const <int>[0x47, 0x49, 0x46, 0x38])) {
    return const _Signature('image/gif', 'GIF');
  }
  if (starts(const <int>[0x50, 0x4b, 0x03, 0x04]) ||
      starts(const <int>[0x50, 0x4b, 0x05, 0x06])) {
    return const _Signature('application/zip', 'ZIP');
  }
  return const _Signature(null, 'unknown');
}

bool _containsPdfEof(Uint8List bytes) {
  final int start = bytes.length > 2048 ? bytes.length - 2048 : 0;
  return String.fromCharCodes(bytes.sublist(start)).contains('%%EOF');
}

int _findEndOfCentralDirectory(Uint8List bytes) {
  final int lowerBound = bytes.length > 65557 ? bytes.length - 65557 : 0;
  for (int index = bytes.length - 22; index >= lowerBound; index--) {
    if (_u32(bytes, index) == 0x06054b50) return index;
  }
  return -1;
}

int _u16(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _u32(Uint8List bytes, int offset) =>
    _u16(bytes, offset) | (_u16(bytes, offset + 2) << 16);

String _extension(String? fileName) =>
    fileName?.split('.').last.toLowerCase() ?? '';

String? _orNull(String value) => value.trim().isEmpty ? null : value;

bool _expectsApk(IncomingShareAttachment attachment, String extension) =>
    attachment.mimeType == 'application/vnd.android.package-archive' ||
    extension == 'apk';

bool _expectsZip(IncomingShareAttachment attachment, String extension) =>
    attachment.mimeType == 'application/zip' || extension == 'zip';

bool _expectsPdf(IncomingShareAttachment attachment, String extension) =>
    attachment.mimeType == 'application/pdf' || extension == 'pdf';

bool _expectsImage(IncomingShareAttachment attachment, String extension) =>
    attachment.mimeType.startsWith('image/') ||
    const <String>{'png', 'jpg', 'jpeg', 'gif'}.contains(extension);

bool _mimeMismatches(String declared, String? detected) =>
    detected != null &&
    declared.isNotEmpty &&
    declared != '*/*' &&
    declared != detected;

bool _unsafeArchiveName(String value) =>
    value.startsWith('/') ||
    value.startsWith('\\') ||
    value.split('/').any((part) => part == '..');

bool _isArchiveName(String value) => const <String>{
  'zip',
  'apk',
  'jar',
  'rar',
  '7z',
  'tar',
  'gz',
}.contains(_extension(value));

class _ArchiveCheck {
  const _ArchiveCheck._({
    required this.invalid,
    required this.partial,
    required this.reason,
    this.fileCount,
    this.extractedSize,
    this.depth,
    this.apkStructureValid = false,
  });

  const _ArchiveCheck.invalid(String reason)
    : this._(invalid: true, partial: false, reason: reason);

  const _ArchiveCheck.partial(
    String reason,
    int fileCount,
    int extractedSize,
    int depth,
    bool apkStructureValid,
  ) : this._(
        invalid: false,
        partial: true,
        reason: reason,
        fileCount: fileCount,
        extractedSize: extractedSize,
        depth: depth,
        apkStructureValid: apkStructureValid,
      );

  const _ArchiveCheck.valid(
    String reason,
    int fileCount,
    int extractedSize,
    int depth,
    bool apkStructureValid,
  ) : this._(
        invalid: false,
        partial: false,
        reason: reason,
        fileCount: fileCount,
        extractedSize: extractedSize,
        depth: depth,
        apkStructureValid: apkStructureValid,
      );

  final bool invalid;
  final bool partial;
  final String reason;
  final int? fileCount;
  final int? extractedSize;
  final int? depth;
  final bool apkStructureValid;
}
