import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'apk_static_analysis.dart';
import 'archive_static_analysis_models.dart';
import 'security_pipeline_config.dart';

/// Performs bounded ZIP inventory inspection. It never extracts an archive
/// wholesale and never executes, installs, launches, or loads an entry.
class LocalArchiveStaticAnalyzer implements ArchiveStaticAnalyzer {
  const LocalArchiveStaticAnalyzer({
    this.config = const SecurityPipelineConfig(),
  });

  final SecurityPipelineConfig config;

  @override
  Future<ArchiveStaticAnalysisResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  }) async {
    final Stopwatch total = Stopwatch()..start();
    final File? source = _fileFromReference(reference);
    if (source == null || !await source.exists()) {
      return _unknown(total, 'ARCHIVE_SOURCE_UNAVAILABLE');
    }
    final int size = await source.length();
    if (size == 0) return _unknown(total, 'EMPTY_ARCHIVE');
    if (size > config.maxFileSizeBytes || size > config.maxArchiveSizeBytes) {
      return _partial(total, 'ARCHIVE_SIZE_LIMIT_EXCEEDED');
    }
    if (size > config.maxArchiveInspectedBytes) {
      return _partial(total, 'ARCHIVE_INSPECTED_BYTES_LIMIT_EXCEEDED');
    }

    final Uint8List bytes = await source.readAsBytes();
    final Stopwatch inventoryTimer = Stopwatch()..start();
    final _ZipInventory inventory = _ZipInventory.parse(bytes, config);
    final int inventoryMs = inventoryTimer.elapsedMilliseconds;
    final Map<String, List<String>> evidence = <String, List<String>>{
      'ARCHIVE_FEATURES': <String>[
        'FORMAT: ZIP',
        'SIZE_BYTES: $size',
        'ENTRY_COUNT: ${inventory.entries.length}',
        'COMPRESSED_BYTES: ${inventory.totalCompressedSize}',
        'DECLARED_UNCOMPRESSED_BYTES: ${inventory.totalUncompressedSize}',
        'MAX_NESTING_DEPTH: ${inventory.maxDepth}',
      ],
      'ARCHIVE_ENTRIES': <String>[],
      'ARCHIVE_SECURITY_INDICATORS': <String>[],
      'ARCHIVE_URLS': <String>[],
      'ARCHIVE_DOMAINS': <String>[],
      'ARCHIVE_TEXT': <String>[],
      'ARCHIVE_APK_DELEGATION': <String>[],
      'ARCHIVE_ANALYSIS_STATUS': <String>[],
      'ARCHIVE_PERFORMANCE': <String>[],
    };
    if (!inventory.valid) {
      evidence['ARCHIVE_SECURITY_INDICATORS']!.add(
        'INVALID: ${inventory.reason}',
      );
      evidence['ARCHIVE_ANALYSIS_STATUS']!.add('UNKNOWN');
      evidence['ARCHIVE_PERFORMANCE']!.add('inventory: $inventoryMs ms');
      evidence['ARCHIVE_PERFORMANCE']!.add(
        'total: ${total.elapsedMilliseconds} ms',
      );
      return ArchiveStaticAnalysisResult(
        status: ArchiveAnalysisStatus.unknown,
        evidence: _freezeEvidence(evidence),
        indicators: <String>['ARCHIVE_INVALID_INPUT: ${inventory.reason}'],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        entries: const <ArchiveEntryMetadata>[],
        apkResults: const <ApkStaticAnalysisResult>[],
        timingsMs: <String, int>{
          'inventory': inventoryMs,
          'total': total.elapsedMilliseconds,
        },
        error: inventory.reason,
      );
    }

    final List<String> indicators = <String>[];
    final List<ArchiveEntryMetadata> metadata = <ArchiveEntryMetadata>[];
    for (final _ZipEntry entry in inventory.entries) {
      final ArchiveEntryMetadata item = ArchiveEntryMetadata(
        path: entry.name,
        extension: _extension(entry.name),
        compressedSize: entry.compressedSize,
        uncompressedSize: entry.uncompressedSize,
        compressionMethod: entry.compressionMethod,
        depth: entry.depth,
        isNestedArchive: entry.isNestedArchive,
        isExecutableLike: entry.isExecutableLike,
      );
      metadata.add(item);
      if (metadata.length <= 100) {
        evidence['ARCHIVE_ENTRIES']!.add(
          '${entry.name}: compressed=${entry.compressedSize}; uncompressed=${entry.uncompressedSize}; method=${entry.compressionMethod}; depth=${entry.depth}',
        );
      }
      if (entry.isExecutableLike) {
        final String signal =
            'ARCHIVE_EXECUTABLE_CONTENT_INDICATOR: ${entry.name} appears executable-like; it was not opened or executed.';
        evidence['ARCHIVE_SECURITY_INDICATORS']!.add(signal);
        indicators.add(signal);
      }
    }
    if (inventory.nestedArchive) {
      const String signal =
          'ARCHIVE_NESTED_ARCHIVE_INDICATOR: nested archive content was detected; recursive inspection was bounded.';
      evidence['ARCHIVE_SECURITY_INDICATORS']!.add(signal);
      indicators.add(signal);
    }
    if (inventory.compressionRatioExceeded) {
      const String signal =
          'ARCHIVE_COMPRESSION_RATIO_INDICATOR: a declared compression ratio exceeded the configured safety limit.';
      evidence['ARCHIVE_SECURITY_INDICATORS']!.add(signal);
      indicators.add(signal);
    }

    final List<String> textSamples = <String>[];
    final Stopwatch contentTimer = Stopwatch()..start();
    for (final _ZipEntry entry in inventory.entries.where(
      _isInspectableTextEntry,
    )) {
      final Uint8List? content = inventory.readEntry(
        bytes,
        entry,
        config.maxApkAssetBytes,
      );
      if (content == null) continue;
      final String text = utf8.decode(content, allowMalformed: true);
      if (text.trim().isEmpty) continue;
      textSamples.add(text.length > 2000 ? text.substring(0, 2000) : text);
      evidence['ARCHIVE_TEXT']!.add(
        '${entry.name}: bounded text sample inspected.',
      );
    }
    final List<String> extractedUrls = _extractUrls(textSamples.join('\n'));
    for (final String url in extractedUrls) {
      evidence['ARCHIVE_URLS']!.add('EXTRACTED_URL: $url');
      evidence['ARCHIVE_DOMAINS']!.add(
        'DOMAIN: ${Uri.tryParse(url)?.host ?? 'unknown'}',
      );
    }
    final int contentMs = contentTimer.elapsedMilliseconds;

    final List<ApkStaticAnalysisResult> apkResults =
        <ApkStaticAnalysisResult>[];
    final Stopwatch apkTimer = Stopwatch()..start();
    Directory? delegatedDirectory;
    try {
      for (final _ZipEntry entry in inventory.entries.where(_isApkEntry)) {
        if (entry.uncompressedSize > config.maxFileSizeBytes) {
          evidence['ARCHIVE_APK_DELEGATION']!.add(
            '${entry.name}: delegation skipped because the bounded APK limit was exceeded.',
          );
          continue;
        }
        final Uint8List? apkBytes = inventory.readEntry(
          bytes,
          entry,
          config.maxFileSizeBytes,
        );
        if (apkBytes == null) {
          evidence['ARCHIVE_APK_DELEGATION']!.add(
            '${entry.name}: delegation unavailable because the entry could not be safely materialized.',
          );
          continue;
        }
        delegatedDirectory ??= await Directory.systemTemp.createTemp(
          'cyber-uday-archive-apk-',
        );
        final File apkFile = File(
          '${delegatedDirectory.path}/entry-${apkResults.length}.apk',
        );
        await apkFile.writeAsBytes(apkBytes, flush: true);
        final ApkStaticAnalysisResult result =
            await const LocalApkStaticAnalyzer().analyze(
              reference: apkFile.path,
              fileName: entry.name,
              mimeType: 'application/vnd.android.package-archive',
            );
        apkResults.add(result);
        evidence['ARCHIVE_APK_DELEGATION']!.add(
          '${entry.name}: existing APK static analyzer returned ${result.status.name.toUpperCase()}.',
        );
        _mergeEvidence(evidence, result.evidence);
        indicators.addAll(result.indicators.where(_isThreatIndicator));
      }
    } finally {
      if (delegatedDirectory != null && await delegatedDirectory.exists()) {
        await delegatedDirectory.delete(recursive: true);
      }
    }
    final int apkMs = apkTimer.elapsedMilliseconds;

    final bool partial =
        inventory.partial ||
        (inventory.nestedArchive && config.maxArchiveDepth < 2) ||
        (inventory.entries.any(_isApkEntry) && apkResults.isEmpty) ||
        apkResults.any(
          (ApkStaticAnalysisResult result) =>
              result.status == ApkAnalysisStatus.partial ||
              result.status == ApkAnalysisStatus.unknown ||
              result.status == ApkAnalysisStatus.unsupported,
        );
    final ArchiveAnalysisStatus status = partial
        ? ArchiveAnalysisStatus.partial
        : ArchiveAnalysisStatus.complete;
    evidence['ARCHIVE_ANALYSIS_STATUS']!.add(status.name.toUpperCase());
    evidence['ARCHIVE_PERFORMANCE']!.addAll(<String>[
      'inventory: $inventoryMs ms',
      'content: $contentMs ms',
      'apk_delegation: $apkMs ms',
      'total: ${total.elapsedMilliseconds} ms',
    ]);
    if (partial) {
      indicators.add(
        'ARCHIVE_ANALYSIS_PARTIAL: incomplete archive evidence is not treated as safe.',
      );
    }
    return ArchiveStaticAnalysisResult(
      status: status,
      evidence: _freezeEvidence(evidence),
      indicators: List<String>.unmodifiable(indicators),
      extractedUrls: List<String>.unmodifiable(extractedUrls),
      textSamples: List<String>.unmodifiable(textSamples),
      entries: List<ArchiveEntryMetadata>.unmodifiable(metadata),
      apkResults: List<ApkStaticAnalysisResult>.unmodifiable(apkResults),
      timingsMs: <String, int>{
        'inventory': inventoryMs,
        'content': contentMs,
        'apkDelegation': apkMs,
        'total': total.elapsedMilliseconds,
      },
    );
  }

  ArchiveStaticAnalysisResult _unknown(Stopwatch total, String reason) =>
      ArchiveStaticAnalysisResult(
        status: ArchiveAnalysisStatus.unknown,
        evidence: <String, List<String>>{
          'ARCHIVE_ANALYSIS_STATUS': <String>['UNKNOWN: $reason'],
        },
        indicators: <String>['ARCHIVE_ANALYSIS_UNKNOWN: $reason'],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        entries: const <ArchiveEntryMetadata>[],
        apkResults: const <ApkStaticAnalysisResult>[],
        timingsMs: <String, int>{'total': total.elapsedMilliseconds},
        error: reason,
      );

  ArchiveStaticAnalysisResult _partial(Stopwatch total, String reason) =>
      ArchiveStaticAnalysisResult(
        status: ArchiveAnalysisStatus.partial,
        evidence: <String, List<String>>{
          'ARCHIVE_ANALYSIS_STATUS': <String>['PARTIAL: $reason'],
        },
        indicators: <String>[
          'ARCHIVE_ANALYSIS_PARTIAL: $reason',
          'ARCHIVE_ANALYSIS_INCOMPLETE: this is not treated as safe.',
        ],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        entries: const <ArchiveEntryMetadata>[],
        apkResults: const <ApkStaticAnalysisResult>[],
        timingsMs: <String, int>{'total': total.elapsedMilliseconds},
        error: reason,
      );
}

class _ZipEntry {
  const _ZipEntry({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.depth,
    required this.isNestedArchive,
    required this.isExecutableLike,
  });

  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int depth;
  final bool isNestedArchive;
  final bool isExecutableLike;
}

class _ZipInventory {
  const _ZipInventory({
    required this.valid,
    required this.entries,
    required this.totalCompressedSize,
    required this.totalUncompressedSize,
    required this.maxDepth,
    required this.nestedArchive,
    required this.partial,
    required this.compressionRatioExceeded,
    required this.reason,
  });

  const _ZipInventory.invalid(this.reason)
    : valid = false,
      entries = const <_ZipEntry>[],
      totalCompressedSize = 0,
      totalUncompressedSize = 0,
      maxDepth = 0,
      nestedArchive = false,
      partial = false,
      compressionRatioExceeded = false;

  final bool valid;
  final List<_ZipEntry> entries;
  final int totalCompressedSize;
  final int totalUncompressedSize;
  final int maxDepth;
  final bool nestedArchive;
  final bool partial;
  final bool compressionRatioExceeded;
  final String reason;

  static _ZipInventory parse(Uint8List bytes, SecurityPipelineConfig config) {
    final int eocd = _findEocd(bytes);
    if (eocd < 0 || eocd + 22 > bytes.length) {
      return const _ZipInventory.invalid('ZIP end record is missing.');
    }
    if (_u16(bytes, eocd + 4) != 0 || _u16(bytes, eocd + 6) != 0) {
      return const _ZipInventory.invalid(
        'Multi-disk ZIP archives are unsupported.',
      );
    }
    final int fileCount = _u16(bytes, eocd + 10);
    final int directorySize = _u32(bytes, eocd + 12);
    final int directoryOffset = _u32(bytes, eocd + 16);
    if (fileCount > config.maxArchiveFiles ||
        directoryOffset + directorySize > bytes.length) {
      return const _ZipInventory.invalid(
        'ZIP resource limits or directory bounds were exceeded.',
      );
    }
    final List<_ZipEntry> entries = <_ZipEntry>[];
    final Set<String> seenPaths = <String>{};
    int cursor = directoryOffset;
    int compressedTotal = 0;
    int uncompressedTotal = 0;
    int maxDepth = 0;
    bool nested = false;
    bool partial = false;
    bool ratioExceeded = false;
    for (int index = 0; index < fileCount; index++) {
      if (cursor + 46 > bytes.length || _u32(bytes, cursor) != 0x02014b50) {
        return const _ZipInventory.invalid(
          'ZIP central directory entry is malformed.',
        );
      }
      final int compressed = _u32(bytes, cursor + 20);
      final int uncompressed = _u32(bytes, cursor + 24);
      final int nameLength = _u16(bytes, cursor + 28);
      final int extraLength = _u16(bytes, cursor + 30);
      final int commentLength = _u16(bytes, cursor + 32);
      final int nameStart = cursor + 46;
      final int next = nameStart + nameLength + extraLength + commentLength;
      if (next > bytes.length) {
        return const _ZipInventory.invalid('ZIP entry exceeds archive bounds.');
      }
      final String rawName = utf8.decode(
        bytes.sublist(nameStart, nameStart + nameLength),
        allowMalformed: true,
      );
      final String name = rawName.replaceAll('\\', '/');
      if (_unsafePath(name)) {
        return const _ZipInventory.invalid(
          'ZIP contains an unsafe entry path.',
        );
      }
      final String collisionKey = name.toLowerCase();
      if (!seenPaths.add(collisionKey)) {
        return const _ZipInventory.invalid(
          'ZIP contains duplicate or colliding entry paths.',
        );
      }
      if (_u16(bytes, cursor + 10) != 0 && _u16(bytes, cursor + 10) != 8) {
        return const _ZipInventory.invalid(
          'ZIP compression method is unsupported.',
        );
      }
      compressedTotal += compressed;
      uncompressedTotal += uncompressed;
      if (compressedTotal > config.maxArchiveSizeBytes ||
          uncompressedTotal > config.maxExtractedSizeBytes) {
        return const _ZipInventory.invalid(
          'ZIP declared resource limits were exceeded.',
        );
      }
      final bool nestedEntry = _isNestedArchive(name);
      final int depth = nestedEntry ? 2 : 1;
      final bool executable = _isExecutableLike(name);
      maxDepth = depth > maxDepth ? depth : maxDepth;
      nested = nested || nestedEntry;
      if (uncompressed > 0 &&
          (compressed == 0 ||
              uncompressed / compressed > config.maxArchiveCompressionRatio)) {
        ratioExceeded = true;
        partial = true;
      }
      entries.add(
        _ZipEntry(
          name: name,
          compressionMethod: _u16(bytes, cursor + 10),
          compressedSize: compressed,
          uncompressedSize: uncompressed,
          localHeaderOffset: _u32(bytes, cursor + 42),
          depth: depth,
          isNestedArchive: nestedEntry,
          isExecutableLike: executable,
        ),
      );
      cursor = next;
    }
    if (nested && config.maxArchiveDepth < 2) partial = true;
    return _ZipInventory(
      valid: true,
      entries: List<_ZipEntry>.unmodifiable(entries),
      totalCompressedSize: compressedTotal,
      totalUncompressedSize: uncompressedTotal,
      maxDepth: maxDepth,
      nestedArchive: nested,
      partial: partial,
      compressionRatioExceeded: ratioExceeded,
      reason: '',
    );
  }

  Uint8List? readEntry(Uint8List bytes, _ZipEntry entry, int maxBytes) {
    if (entry.uncompressedSize > maxBytes ||
        entry.localHeaderOffset < 0 ||
        entry.localHeaderOffset + 30 > bytes.length) {
      return null;
    }
    final int offset = entry.localHeaderOffset;
    if (_u32(bytes, offset) != 0x04034b50) return null;
    final int nameLength = _u16(bytes, offset + 26);
    final int extraLength = _u16(bytes, offset + 28);
    final int dataStart = offset + 30 + nameLength + extraLength;
    final int dataEnd = dataStart + entry.compressedSize;
    if (dataStart < 0 || dataEnd > bytes.length) return null;
    final Uint8List data = bytes.sublist(dataStart, dataEnd);
    try {
      if (entry.compressionMethod == 0) {
        return data.length == entry.uncompressedSize ? data : null;
      }
      final _BoundedBytesSink output = _BoundedBytesSink(maxBytes);
      final ByteConversionSink decoder = ZLibDecoder(
        raw: true,
      ).startChunkedConversion(output);
      decoder
        ..add(data)
        ..close();
      return output.bytes.length == entry.uncompressedSize
          ? Uint8List.fromList(output.bytes)
          : null;
    } on Object {
      return null;
    }
  }
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

bool _isApkEntry(_ZipEntry entry) => _extension(entry.name) == 'apk';

bool _isNestedArchive(String name) =>
    const <String>{
      'zip',
      'jar',
      'rar',
      '7z',
      'tar',
      'gz',
    }.contains(_extension(name)) &&
    !name.startsWith('META-INF/');

bool _isExecutableLike(String name) => const <String>{
  'apk',
  'dex',
  'so',
  'elf',
  'exe',
  'dll',
  'bin',
  'sh',
  'bat',
  'cmd',
  'js',
  'ps1',
  'py',
}.contains(_extension(name));

bool _isInspectableTextEntry(_ZipEntry entry) =>
    entry.uncompressedSize <= 256 * 1024 &&
    const <String>{
      'txt',
      'json',
      'xml',
      'html',
      'htm',
      'js',
      'csv',
      'md',
    }.contains(_extension(entry.name));

bool _unsafePath(String name) =>
    name.isEmpty ||
    name.contains('\u0000') ||
    name.startsWith('/') ||
    name.split('/').any((part) => part == '..');

String _extension(String name) => name.split('.').last.toLowerCase();

List<String> _extractUrls(String source) {
  final RegExp pattern = RegExp(
    r'''https?://[^\s<>()\[\]{}"']+''',
    caseSensitive: false,
  );
  final Set<String> values = <String>{};
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final String value = match.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), '');
    if (value.length <= 2048) values.add(value);
    if (values.length >= 50) break;
  }
  return values.toList(growable: false);
}

File? _fileFromReference(String reference) {
  if (reference.startsWith('content://') || reference.startsWith('picker://')) {
    return null;
  }
  return reference.startsWith('file://')
      ? File.fromUri(Uri.parse(reference))
      : File(reference);
}

Map<String, List<String>> _freezeEvidence(Map<String, List<String>> evidence) =>
    Map<String, List<String>>.unmodifiable(
      evidence.map(
        (String key, List<String> value) => MapEntry<String, List<String>>(
          key,
          List<String>.unmodifiable(value),
        ),
      ),
    );

void _mergeEvidence(
  Map<String, List<String>> destination,
  Map<String, List<String>> source,
) {
  for (final MapEntry<String, List<String>> entry in source.entries) {
    destination.putIfAbsent(entry.key, () => <String>[]).addAll(entry.value);
  }
}

bool _isThreatIndicator(String value) {
  final String candidate = value.toLowerCase();
  const List<String> analysisOnly = <String>[
    'apk_analysis_',
    'apk_invalid_input',
    'apk_source_unavailable',
    'apk_size_limit',
    'apk_manifest_analysis_incomplete',
    'apk_dex_analysis_incomplete',
    'signature_analysis_unavailable',
  ];
  return !analysisOnly.any(candidate.startsWith) && value.trim().isNotEmpty;
}

int _findEocd(Uint8List bytes) {
  final int lower = bytes.length > 65557 ? bytes.length - 65557 : 0;
  for (int index = bytes.length - 22; index >= lower; index--) {
    if (_u32(bytes, index) == 0x06054b50) return index;
  }
  return -1;
}

int _u16(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _u32(Uint8List bytes, int offset) =>
    _u16(bytes, offset) | (_u16(bytes, offset + 2) << 16);
