import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'apk_static_analysis_models.dart';
import 'security_pipeline_config.dart';

/// Performs bounded APK inspection without extracting or executing APK code.
///
/// The parser reads ZIP metadata and only a small set of bounded entries. It
/// never loads classes, invokes a process, installs an APK, or follows a URL.
class LocalApkStaticAnalyzer implements ApkStaticAnalyzer {
  const LocalApkStaticAnalyzer({this.config = const SecurityPipelineConfig()});

  final SecurityPipelineConfig config;

  @override
  Future<ApkStaticAnalysisResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  }) async {
    final Stopwatch total = Stopwatch()..start();
    final File? source = _fileFromReference(reference);
    if (source == null || !await source.exists()) {
      return _unknown(total, 'APK_SOURCE_UNAVAILABLE');
    }
    final int size = await source.length();
    if (size == 0) return _unknown(total, 'EMPTY_APK');
    if (size > config.maxFileSizeBytes || size > config.maxArchiveSizeBytes) {
      return _partial(total, 'APK_SIZE_LIMIT_EXCEEDED');
    }

    final Uint8List bytes = await source.readAsBytes();
    final Stopwatch zipTimer = Stopwatch()..start();
    final _ZipInspection zip = _ZipInspection.parse(bytes, config);
    final int zipMs = zipTimer.elapsedMilliseconds;
    final Map<String, List<String>> evidence = <String, List<String>>{
      'APK_FEATURES': <String>[
        'SIZE_BYTES: $size',
        'ZIP_ENTRIES: ${zip.entries.length}',
        'ZIP_UNCOMPRESSED_BYTES: ${zip.totalUncompressedSize}',
      ],
      'APK_STRUCTURE': <String>[],
      'APK_MANIFEST': <String>[],
      'APK_PERMISSIONS': <String>[],
      'APK_COMPONENTS': <String>[],
      'APK_DEX_FEATURES': <String>[],
      'APK_NATIVE_LIBRARIES': <String>[],
      'APK_URLS': <String>[],
      'APK_DOMAINS': <String>[],
      'APK_STRINGS': <String>[],
      'APK_SIGNATURE': <String>[],
      'APK_SECURITY_INDICATORS': <String>[],
      'APK_ANALYSIS_STATUS': <String>[],
      'APK_PERFORMANCE': <String>[],
    };
    if (!zip.valid) {
      evidence['APK_STRUCTURE']!.add('INVALID: ${zip.reason}');
      evidence['APK_ANALYSIS_STATUS']!.add('UNKNOWN');
      evidence['APK_PERFORMANCE']!.add('zip: $zipMs ms');
      evidence['APK_PERFORMANCE']!.add(
        'total: ${total.elapsedMilliseconds} ms',
      );
      return ApkStaticAnalysisResult(
        status: ApkAnalysisStatus.unknown,
        evidence: _freezeEvidence(evidence),
        indicators: <String>['APK_INVALID_INPUT: ${zip.reason}'],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        manifest: const ApkManifestMetadata(),
        dexCount: 0,
        nativeLibraries: const <ApkNativeLibraryMetadata>[],
        signature: const ApkSignatureMetadata(
          present: false,
          entries: <String>[],
        ),
        timingsMs: <String, int>{
          'zip': zipMs,
          'total': total.elapsedMilliseconds,
        },
        error: zip.reason,
      );
    }
    evidence['APK_STRUCTURE']!.add(
      'ZIP: bounded central-directory inspection completed without extraction.',
    );
    if (zip.nestedArchive) {
      evidence['APK_STRUCTURE']!.add(
        'NESTED_ARCHIVE: nested archive entry detected; recursive inspection was not attempted.',
      );
    }
    final bool hasManifestEntry = zip.byName.containsKey('AndroidManifest.xml');
    final bool hasDexEntry = zip.entries.any(_isDexEntry);
    if (!hasManifestEntry || !hasDexEntry) {
      final String reason = !hasManifestEntry && !hasDexEntry
          ? 'AndroidManifest.xml and classes.dex are missing.'
          : !hasManifestEntry
          ? 'AndroidManifest.xml is missing.'
          : 'classes.dex is missing.';
      evidence['APK_STRUCTURE']!.add('INVALID: $reason');
      evidence['APK_ANALYSIS_STATUS']!.add('UNKNOWN');
      evidence['APK_PERFORMANCE']!.add('zip: $zipMs ms');
      evidence['APK_PERFORMANCE']!.add(
        'total: ${total.elapsedMilliseconds} ms',
      );
      return ApkStaticAnalysisResult(
        status: ApkAnalysisStatus.unknown,
        evidence: _freezeEvidence(evidence),
        indicators: <String>['APK_INVALID_INPUT: $reason'],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        manifest: const ApkManifestMetadata(),
        dexCount: 0,
        nativeLibraries: const <ApkNativeLibraryMetadata>[],
        signature: const ApkSignatureMetadata(
          present: false,
          entries: <String>[],
        ),
        timingsMs: <String, int>{
          'zip': zipMs,
          'total': total.elapsedMilliseconds,
        },
        error: reason,
      );
    }

    final List<String> indicators = <String>[];
    final Stopwatch manifestTimer = Stopwatch()..start();
    final _ZipEntry? manifestEntry = zip.byName['AndroidManifest.xml'];
    final Uint8List? manifestBytes = manifestEntry == null
        ? null
        : zip.readEntry(bytes, manifestEntry, config.maxApkManifestBytes);
    final _ManifestInspection manifest = manifestBytes == null
        ? const _ManifestInspection.invalid(
            'AndroidManifest.xml was unavailable.',
          )
        : _ManifestInspection.parse(manifestBytes);
    final int manifestMs = manifestTimer.elapsedMilliseconds;
    if (!manifest.valid) {
      evidence['APK_MANIFEST']!.add('INVALID: ${manifest.reason}');
      indicators.add('APK_MANIFEST_ANALYSIS_INCOMPLETE: ${manifest.reason}');
    } else {
      _addManifestEvidence(evidence, manifest.metadata);
      for (final String permission in manifest.metadata.permissions) {
        evidence['APK_PERMISSIONS']!.add('REQUESTED: $permission');
      }
      for (final ApkComponentMetadata component
          in manifest.metadata.components) {
        evidence['APK_COMPONENTS']!.add(
          '${component.type}: ${component.name}; exported=${component.exported?.toString() ?? 'unknown'}; intentFilters=${component.intentFilterCount}',
        );
      }
      indicators.addAll(_permissionCombinationIndicators(manifest.metadata));
      if (manifest.metadata.debuggable == true) {
        evidence['APK_SECURITY_INDICATORS']!.add(
          'DEBUGGABLE: application is marked debuggable; this is context, not proof of malware.',
        );
      }
      if (manifest.metadata.allowBackup == true) {
        evidence['APK_SECURITY_INDICATORS']!.add(
          'BACKUP_ENABLED: application allows backup; this is context, not proof of malware.',
        );
      }
    }

    final Stopwatch dexTimer = Stopwatch()..start();
    final List<_DexInspection> dexInspections = <_DexInspection>[];
    for (final _ZipEntry entry in zip.entries.where(_isDexEntry)) {
      final Uint8List? dexBytes = zip.readEntry(
        bytes,
        entry,
        config.maxApkDexBytes,
      );
      dexInspections.add(
        dexBytes == null
            ? const _DexInspection.invalid(
                'DEX entry exceeded the bounded read limit.',
              )
            : _DexInspection.parse(dexBytes, config),
      );
    }
    final int dexMs = dexTimer.elapsedMilliseconds;
    final List<String> dexText = <String>[];
    for (int index = 0; index < dexInspections.length; index++) {
      final _DexInspection dex = dexInspections[index];
      evidence['APK_DEX_FEATURES']!.add(
        'DEX_${index + 1}: valid=${dex.valid}; strings=${dex.stringCount}; methods=${dex.methodCount}; classes=${dex.classCount}',
      );
      if (!dex.valid) {
        indicators.add('APK_DEX_ANALYSIS_INCOMPLETE: ${dex.reason}');
        continue;
      }
      for (final String signal in dex.signals) {
        evidence['APK_STRINGS']!.add(signal);
      }
      dexText.addAll(dex.textSamples);
      indicators.addAll(dex.indicators);
    }
    if (dexInspections.length > 1) {
      evidence['APK_DEX_FEATURES']!.add(
        'MULTIPLE_DEX_FILES: ${dexInspections.length} DEX files were inspected.',
      );
    }

    final Stopwatch nativeTimer = Stopwatch()..start();
    final List<ApkNativeLibraryMetadata> nativeLibraries =
        <ApkNativeLibraryMetadata>[];
    for (final _ZipEntry entry in zip.entries.where(_isNativeEntry)) {
      final String abi = entry.name.split('/').length > 1
          ? entry.name.split('/')[1]
          : 'unknown';
      final Uint8List? nativeBytes = zip.readEntry(
        bytes,
        entry,
        config.maxApkNativeLibraryBytes,
      );
      final String? digest = nativeBytes == null
          ? null
          : sha256.convert(nativeBytes).toString();
      nativeLibraries.add(
        ApkNativeLibraryMetadata(
          path: entry.name,
          abi: abi,
          sizeBytes: entry.uncompressedSize,
          sha256: digest,
        ),
      );
      evidence['APK_NATIVE_LIBRARIES']!.add(
        '${entry.name}: abi=$abi; size=${entry.uncompressedSize}; hash=${digest ?? 'unavailable'}; not loaded.',
      );
    }
    final int nativeMs = nativeTimer.elapsedMilliseconds;

    final Stopwatch signatureTimer = Stopwatch()..start();
    final List<_ZipEntry> signatureEntries = zip.entries
        .where(_isSignatureEntry)
        .toList(growable: false);
    final List<String> signatureNames = <String>[];
    String? signatureDigest;
    for (final _ZipEntry entry in signatureEntries) {
      signatureNames.add(entry.name);
      final Uint8List? signatureBytes = zip.readEntry(
        bytes,
        entry,
        config.maxApkSignatureBytes,
      );
      signatureDigest ??= signatureBytes == null
          ? null
          : sha256.convert(signatureBytes).toString();
    }
    final ApkSignatureMetadata signature = ApkSignatureMetadata(
      present: signatureEntries.isNotEmpty,
      entries: List<String>.unmodifiable(signatureNames),
      digest: signatureDigest,
      analysisAvailable: signatureEntries.isNotEmpty && signatureDigest != null,
    );
    final int signatureMs = signatureTimer.elapsedMilliseconds;
    if (signature.present && signature.analysisAvailable) {
      evidence['APK_SIGNATURE']!.add(
        'SIGNATURE_BLOCK: ${signature.entries.join(', ')}; digest=${signature.digest}.',
      );
      evidence['APK_SIGNATURE']!.add(
        'CERTIFICATE_METADATA: signature block presence and digest inspected; certificate subject/issuer parsing is unavailable in this bounded client pass.',
      );
    } else {
      evidence['APK_SIGNATURE']!.add(
        'SIGNATURE_ANALYSIS_UNAVAILABLE: no bounded signature block metadata was available.',
      );
      indicators.add('SIGNATURE_ANALYSIS_UNAVAILABLE');
    }

    final List<String> textEntries = <String>[
      ...manifest.rawStrings,
      ...dexText,
    ];
    for (final _ZipEntry entry in zip.entries.where(_isInspectableTextEntry)) {
      final String? text = _decodeTextEntry(
        zip.readEntry(bytes, entry, config.maxApkAssetBytes),
      );
      if (text != null) textEntries.add(text);
    }
    final List<String> extractedUrls = _extractUrls(textEntries.join('\n'));
    for (final String url in extractedUrls) {
      evidence['APK_URLS']!.add('EXTRACTED_URL: $url');
    }
    if (extractedUrls.isNotEmpty) {
      evidence['APK_DOMAINS']!.add(
        'DOMAINS: ${extractedUrls.map(_domainLabel).join(', ')}; URLs were not opened.',
      );
    }
    for (final String sample in dexText.take(config.maxApkTextSamples)) {
      evidence['APK_STRINGS']!.add(sample);
    }

    final bool incomplete =
        !manifest.valid ||
        dexInspections.any((dex) => !dex.valid) ||
        !signature.analysisAvailable ||
        zip.partial;
    final ApkAnalysisStatus status = incomplete
        ? ApkAnalysisStatus.partial
        : ApkAnalysisStatus.complete;
    evidence['APK_ANALYSIS_STATUS']!.add(status.name.toUpperCase());
    evidence['APK_PERFORMANCE']!.addAll(<String>[
      'zip: $zipMs ms',
      'manifest: $manifestMs ms',
      'dex: $dexMs ms',
      'native: $nativeMs ms',
      'signature: $signatureMs ms',
      'total: ${total.elapsedMilliseconds} ms',
    ]);
    if (status != ApkAnalysisStatus.complete) {
      indicators.add(
        'APK_ANALYSIS_PARTIAL: incomplete evidence is not treated as safe.',
      );
    }
    return ApkStaticAnalysisResult(
      status: status,
      evidence: _freezeEvidence(evidence),
      indicators: List<String>.unmodifiable(indicators),
      extractedUrls: List<String>.unmodifiable(extractedUrls),
      textSamples: List<String>.unmodifiable(
        dexText.take(config.maxApkTextSamples),
      ),
      manifest: manifest.metadata,
      dexCount: dexInspections.length,
      nativeLibraries: List<ApkNativeLibraryMetadata>.unmodifiable(
        nativeLibraries,
      ),
      signature: signature,
      timingsMs: <String, int>{
        'zip': zipMs,
        'manifest': manifestMs,
        'dex': dexMs,
        'native': nativeMs,
        'signature': signatureMs,
        'total': total.elapsedMilliseconds,
      },
    );
  }

  ApkStaticAnalysisResult _unknown(Stopwatch total, String reason) =>
      ApkStaticAnalysisResult(
        status: ApkAnalysisStatus.unknown,
        evidence: <String, List<String>>{
          'APK_ANALYSIS_STATUS': <String>['UNKNOWN: $reason'],
        },
        indicators: <String>['APK_ANALYSIS_UNKNOWN: $reason'],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        manifest: const ApkManifestMetadata(),
        dexCount: 0,
        nativeLibraries: const <ApkNativeLibraryMetadata>[],
        signature: const ApkSignatureMetadata(
          present: false,
          entries: <String>[],
        ),
        timingsMs: <String, int>{'total': total.elapsedMilliseconds},
        error: reason,
      );

  ApkStaticAnalysisResult _partial(Stopwatch total, String reason) =>
      ApkStaticAnalysisResult(
        status: ApkAnalysisStatus.partial,
        evidence: <String, List<String>>{
          'APK_ANALYSIS_STATUS': <String>['PARTIAL: $reason'],
        },
        indicators: <String>[
          'APK_ANALYSIS_PARTIAL: $reason',
          'APK_ANALYSIS_INCOMPLETE: this is not treated as safe.',
        ],
        extractedUrls: const <String>[],
        textSamples: const <String>[],
        manifest: const ApkManifestMetadata(),
        dexCount: 0,
        nativeLibraries: const <ApkNativeLibraryMetadata>[],
        signature: const ApkSignatureMetadata(
          present: false,
          entries: <String>[],
        ),
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
  });

  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

class _ZipInspection {
  const _ZipInspection({
    required this.valid,
    required this.entries,
    required this.byName,
    required this.totalUncompressedSize,
    required this.nestedArchive,
    required this.partial,
    required this.reason,
  });

  final bool valid;
  final List<_ZipEntry> entries;
  final Map<String, _ZipEntry> byName;
  final int totalUncompressedSize;
  final bool nestedArchive;
  final bool partial;
  final String reason;

  static _ZipInspection parse(Uint8List bytes, SecurityPipelineConfig config) {
    final int eocd = _findEocd(bytes);
    if (eocd < 0 || eocd + 22 > bytes.length) {
      return const _ZipInspection.invalid('ZIP end record is missing.');
    }
    if (_u16(bytes, eocd + 4) != 0 || _u16(bytes, eocd + 6) != 0) {
      return const _ZipInspection.invalid(
        'Multi-disk ZIP archives are unsupported.',
      );
    }
    final int entryCount = _u16(bytes, eocd + 10);
    final int directorySize = _u32(bytes, eocd + 12);
    final int directoryOffset = _u32(bytes, eocd + 16);
    if (entryCount > config.maxArchiveFiles ||
        directoryOffset + directorySize > bytes.length) {
      return const _ZipInspection.invalid('ZIP resource limits were exceeded.');
    }
    final List<_ZipEntry> entries = <_ZipEntry>[];
    final Map<String, _ZipEntry> byName = <String, _ZipEntry>{};
    int cursor = directoryOffset;
    int total = 0;
    bool nested = false;
    for (int index = 0; index < entryCount; index++) {
      if (cursor + 46 > bytes.length || _u32(bytes, cursor) != 0x02014b50) {
        return const _ZipInspection.invalid(
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
        return const _ZipInspection.invalid(
          'ZIP entry exceeds archive bounds.',
        );
      }
      final String name = utf8.decode(
        bytes.sublist(nameStart, nameStart + nameLength),
        allowMalformed: true,
      );
      if (_unsafePath(name)) {
        return const _ZipInspection.invalid(
          'ZIP contains a path-traversal entry.',
        );
      }
      if (compressed > config.maxArchiveSizeBytes ||
          uncompressed > config.maxExtractedSizeBytes ||
          total > config.maxExtractedSizeBytes - uncompressed) {
        return const _ZipInspection.invalid(
          'ZIP declared resource limits were exceeded.',
        );
      }
      final _ZipEntry entry = _ZipEntry(
        name: name,
        compressionMethod: _u16(bytes, cursor + 10),
        compressedSize: compressed,
        uncompressedSize: uncompressed,
        localHeaderOffset: _u32(bytes, cursor + 42),
      );
      if (entry.compressionMethod != 0 && entry.compressionMethod != 8) {
        return const _ZipInspection.invalid(
          'ZIP compression method is unsupported.',
        );
      }
      entries.add(entry);
      byName[name] = entry;
      total += uncompressed;
      nested = nested || _isNestedArchiveName(name);
      cursor = next;
    }
    final bool partial = nested;
    return _ZipInspection(
      valid: true,
      entries: List<_ZipEntry>.unmodifiable(entries),
      byName: Map<String, _ZipEntry>.unmodifiable(byName),
      totalUncompressedSize: total,
      nestedArchive: nested,
      partial: partial,
      reason: '',
    );
  }

  const _ZipInspection.invalid(this.reason)
    : valid = false,
      entries = const <_ZipEntry>[],
      byName = const <String, _ZipEntry>{},
      totalUncompressedSize = 0,
      nestedArchive = false,
      partial = false;

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
    final Uint8List compressed = bytes.sublist(dataStart, dataEnd);
    try {
      if (entry.compressionMethod == 0) {
        return compressed.length == entry.uncompressedSize ? compressed : null;
      }
      final _BoundedBytesSink output = _BoundedBytesSink(maxBytes);
      final ByteConversionSink decoder = ZLibDecoder(
        raw: true,
      ).startChunkedConversion(output);
      decoder
        ..add(compressed)
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
      throw StateError('Bounded APK decompression limit exceeded.');
    }
    bytes.addAll(chunk);
  }

  @override
  void close() {}
}

class _ManifestInspection {
  const _ManifestInspection(
    this.valid,
    this.metadata,
    this.rawStrings,
    this.reason,
  );

  const _ManifestInspection.invalid(this.reason)
    : valid = false,
      metadata = const ApkManifestMetadata(),
      rawStrings = const <String>[];

  final bool valid;
  final ApkManifestMetadata metadata;
  final List<String> rawStrings;
  final String reason;

  static _ManifestInspection parse(Uint8List bytes) {
    if (bytes.length < 8 || _u16(bytes, 0) != 0x0003) {
      return const _ManifestInspection.invalid(
        'AndroidManifest.xml is not binary XML.',
      );
    }
    final _StringPool pool = _StringPool.parse(bytes);
    if (!pool.valid) return _ManifestInspection.invalid(pool.reason);
    final List<String> permissions = <String>[];
    final List<ApkComponentMetadata> components = <ApkComponentMetadata>[];
    final List<_OpenComponent> open = <_OpenComponent>[];
    String? packageName;
    String? label;
    String? versionCode;
    String? versionName;
    String? minSdk;
    String? targetSdk;
    bool? debuggable;
    bool? allowBackup;
    final List<String> stack = <String>[];
    int offset = _u16(bytes, 2);
    while (offset + 8 <= bytes.length) {
      final int type = _u16(bytes, offset);
      final int headerSize = _u16(bytes, offset + 2);
      final int chunkSize = _u32(bytes, offset + 4);
      if (headerSize < 8 ||
          chunkSize < headerSize ||
          offset + chunkSize > bytes.length) {
        return _ManifestInspection.invalid(
          'Binary XML chunk bounds are invalid.',
        );
      }
      if (type == 0x0102 && headerSize >= 36) {
        final int nameIndex = _u32(bytes, offset + 20);
        final String element = pool.value(nameIndex) ?? 'unknown';
        final Map<String, Object?> attrs = _attributes(
          bytes,
          offset,
          headerSize,
          pool,
        );
        final String normalized = _shortName(element);
        stack.add(normalized);
        if (normalized == 'manifest') {
          packageName = attrs['package'] as String? ?? packageName;
          versionCode = _valueString(attrs, 'versionCode') ?? versionCode;
          versionName = _valueString(attrs, 'versionName') ?? versionName;
        } else if (normalized == 'uses-permission' ||
            normalized == 'uses-permission-sdk-23') {
          final String? permission = _valueString(attrs, 'name');
          if (permission != null && permission.isNotEmpty) {
            permissions.add(permission);
          }
        } else if (normalized == 'uses-sdk') {
          minSdk = _valueString(attrs, 'minSdkVersion') ?? minSdk;
          targetSdk = _valueString(attrs, 'targetSdkVersion') ?? targetSdk;
        } else if (normalized == 'application') {
          label = _valueString(attrs, 'label') ?? label;
          debuggable = _boolValue(attrs['debuggable']) ?? debuggable;
          allowBackup = _boolValue(attrs['allowBackup']) ?? allowBackup;
        } else if (_componentTypes.contains(normalized)) {
          final _OpenComponent component = _OpenComponent(
            type: normalized,
            name: _valueString(attrs, 'name') ?? 'unknown',
            exported: _boolValue(attrs['exported']),
          );
          open.add(component);
        } else if (normalized == 'intent-filter' && open.isNotEmpty) {
          open.last.intentFilterCount++;
        }
      } else if (type == 0x0103 && headerSize >= 24) {
        final int nameIndex = _u32(bytes, offset + 20);
        final String element = _shortName(pool.value(nameIndex) ?? '');
        if (_componentTypes.contains(element) && open.isNotEmpty) {
          final _OpenComponent component = open.removeLast();
          components.add(
            ApkComponentMetadata(
              type: component.type,
              name: component.name,
              exported: component.exported,
              intentFilterCount: component.intentFilterCount,
            ),
          );
        }
        if (stack.isNotEmpty) stack.removeLast();
      }
      offset += chunkSize;
    }
    if (stack.isNotEmpty) {
      return const _ManifestInspection.invalid(
        'Binary XML element stack is incomplete.',
      );
    }
    final ApkManifestMetadata metadata = ApkManifestMetadata(
      packageName: packageName,
      applicationLabel: label,
      versionCode: versionCode,
      versionName: versionName,
      minSdk: minSdk,
      targetSdk: targetSdk,
      debuggable: debuggable,
      allowBackup: allowBackup,
      permissions: List<String>.unmodifiable(permissions),
      components: List<ApkComponentMetadata>.unmodifiable(components),
    );
    return _ManifestInspection(true, metadata, pool.values, '');
  }
}

class _OpenComponent {
  _OpenComponent({
    required this.type,
    required this.name,
    required this.exported,
  });

  final String type;
  final String name;
  final bool? exported;
  int intentFilterCount = 0;
}

class _StringPool {
  const _StringPool(this.valid, this.values, this.reason);

  const _StringPool.invalid(this.reason)
    : valid = false,
      values = const <String>[];

  final bool valid;
  final List<String> values;
  final String reason;

  static _StringPool parse(Uint8List bytes) {
    if (bytes.length < 28 || _u16(bytes, 0) != 0x0003) {
      return const _StringPool.invalid('Binary XML header is invalid.');
    }
    int offset = _u16(bytes, 2);
    while (offset + 8 <= bytes.length) {
      final int type = _u16(bytes, offset);
      final int headerSize = _u16(bytes, offset + 2);
      final int chunkSize = _u32(bytes, offset + 4);
      if (chunkSize < headerSize || offset + chunkSize > bytes.length) {
        return const _StringPool.invalid(
          'Binary XML string-pool bounds are invalid.',
        );
      }
      if (type == 0x0001) {
        if (headerSize < 28 || chunkSize < headerSize) {
          return const _StringPool.invalid(
            'Binary XML string pool is malformed.',
          );
        }
        final int count = _u32(bytes, offset + 8);
        final int flags = _u32(bytes, offset + 16);
        final int stringsOffset = _u32(bytes, offset + 20);
        final int offsetsStart = offset + headerSize;
        final int stringsStart = offset + stringsOffset;
        if (count > 50000 ||
            offsetsStart + count * 4 > bytes.length ||
            stringsStart > bytes.length) {
          return const _StringPool.invalid(
            'Binary XML string pool exceeds limits.',
          );
        }
        final bool utf8 = flags & 0x100 != 0;
        final List<String> values = <String>[];
        for (int index = 0; index < count; index++) {
          final int relative = _u32(bytes, offsetsStart + index * 4);
          final int start = stringsStart + relative;
          if (start < stringsStart || start >= bytes.length) {
            values.add('');
            continue;
          }
          final String? value = utf8
              ? _decodeUtf8String(bytes, start)
              : _decodeUtf16String(bytes, start);
          values.add(value ?? '');
        }
        return _StringPool(true, List<String>.unmodifiable(values), '');
      }
      offset += chunkSize;
    }
    return const _StringPool.invalid('Binary XML string pool was not found.');
  }

  String? value(int index) =>
      index >= 0 && index < values.length ? values[index] : null;
}

class _DexInspection {
  const _DexInspection({
    required this.valid,
    required this.stringCount,
    required this.methodCount,
    required this.classCount,
    required this.signals,
    required this.indicators,
    required this.textSamples,
    required this.reason,
  });

  const _DexInspection.invalid(this.reason)
    : valid = false,
      stringCount = 0,
      methodCount = 0,
      classCount = 0,
      signals = const <String>[],
      indicators = const <String>[],
      textSamples = const <String>[];

  final bool valid;
  final int stringCount;
  final int methodCount;
  final int classCount;
  final List<String> signals;
  final List<String> indicators;
  final List<String> textSamples;
  final String reason;

  static _DexInspection parse(Uint8List bytes, SecurityPipelineConfig config) {
    if (bytes.length < 0x70 || !_isDex(bytes)) {
      return const _DexInspection.invalid('DEX magic or header is invalid.');
    }
    final int fileSize = _u32(bytes, 0x20);
    final int stringCount = _u32(bytes, 0x38);
    final int stringOffset = _u32(bytes, 0x3c);
    final int methodCount = _u32(bytes, 0x58);
    final int classCount = _u32(bytes, 0x60);
    if (fileSize > 0 && fileSize > bytes.length ||
        stringCount > 50000 ||
        stringOffset >= bytes.length) {
      return const _DexInspection.invalid('DEX declared bounds are invalid.');
    }
    final List<String> signals = <String>[];
    final List<String> indicators = <String>[];
    final List<String> samples = <String>[];
    final Set<String> found = <String>{};
    final int inspected = stringCount > config.maxApkDexStrings
        ? config.maxApkDexStrings
        : stringCount;
    for (int index = 0; index < inspected; index++) {
      final int idOffset = stringOffset + index * 4;
      if (idOffset + 4 > bytes.length) break;
      final int valueOffset = _u32(bytes, idOffset);
      final String? value = _readDexString(bytes, valueOffset);
      if (value == null || value.isEmpty) continue;
      final String lower = value.toLowerCase();
      for (final MapEntry<String, String> signal in _dexSignals.entries) {
        if (!lower.contains(signal.key) || !found.add(signal.value)) continue;
        signals.add(
          '${signal.value}: bounded DEX string matched a security-relevant pattern.',
        );
        indicators.add(signal.value);
        samples.add('DEX_STRING_INDICATOR: ${signal.value}.');
      }
      if (_looksLikeUrl(value) && samples.length < config.maxApkTextSamples) {
        samples.add(value);
      }
    }
    return _DexInspection(
      valid: true,
      stringCount: stringCount,
      methodCount: methodCount,
      classCount: classCount,
      signals: List<String>.unmodifiable(signals),
      indicators: List<String>.unmodifiable(indicators),
      textSamples: List<String>.unmodifiable(samples),
      reason: '',
    );
  }
}

const Set<String> _componentTypes = <String>{
  'activity',
  'activity-alias',
  'service',
  'receiver',
  'provider',
};

const Map<String, String> _dexSignals = <String, String>{
  'getruntime': 'APK_SHELL_EXECUTION_INDICATOR',
  'runtime.exec': 'APK_SHELL_EXECUTION_INDICATOR',
  'processbuilder': 'APK_SHELL_EXECUTION_INDICATOR',
  'dexclassloader': 'APK_DYNAMIC_CODE_INDICATOR',
  'pathclassloader': 'APK_DYNAMIC_CODE_INDICATOR',
  'loadlibrary': 'APK_NATIVE_LOADING_INDICATOR',
  'accessibilityservice': 'APK_ACCESSIBILITY_INDICATOR',
  'accessibilitynodeinfo': 'APK_ACCESSIBILITY_INDICATOR',
  'addjavascriptinterface': 'APK_WEBVIEW_INDICATOR',
  'webview': 'APK_WEBVIEW_INDICATOR',
  'sendtextmessage': 'APK_SMS_INDICATOR',
  'read_sms': 'APK_SMS_INDICATOR',
  'password': 'APK_CREDENTIAL_STRING_INDICATOR',
  'credential': 'APK_CREDENTIAL_STRING_INDICATOR',
  'otp': 'APK_CREDENTIAL_STRING_INDICATOR',
  'banking': 'APK_CREDENTIAL_STRING_INDICATOR',
  'wallet': 'APK_FINANCIAL_STRING_INDICATOR',
};

List<String> _permissionCombinationIndicators(ApkManifestMetadata metadata) {
  final Set<String> permissions = metadata.permissions.map(_shortName).toSet();
  final bool sms = permissions.any((value) => value.contains('SMS'));
  final bool contacts = permissions.any((value) => value.contains('CONTACTS'));
  final bool internet = permissions.contains('INTERNET');
  final bool accessibility = permissions.any(
    (value) => value.contains('BIND_ACCESSIBILITY_SERVICE'),
  );
  final bool overlay = permissions.any(
    (value) => value.contains('SYSTEM_ALERT_WINDOW'),
  );
  final bool boot = permissions.any(
    (value) => value.contains('RECEIVE_BOOT_COMPLETED'),
  );
  final bool deviceAdmin = permissions.any(
    (value) => value.contains('BIND_DEVICE_ADMIN'),
  );
  final bool install = permissions.any(
    (value) => value.contains('REQUEST_INSTALL_PACKAGES'),
  );
  final List<String> indicators = <String>[];
  if (sms && contacts && internet) {
    indicators.add(
      'APK_PERMISSION_COMBINATION_INDICATOR: SMS, contacts, and network access were requested together.',
    );
  }
  if (overlay && accessibility) {
    indicators.add(
      'APK_PERMISSION_COMBINATION_INDICATOR: overlay and accessibility capabilities were requested together.',
    );
  }
  if (boot && accessibility) {
    indicators.add(
      'APK_PERSISTENCE_ACCESSIBILITY_INDICATOR: boot persistence and accessibility capabilities were requested together.',
    );
  }
  if (deviceAdmin && internet) {
    indicators.add(
      'APK_DEVICE_ADMIN_NETWORK_INDICATOR: device administration and network access were requested together.',
    );
  }
  if (install && internet) {
    indicators.add(
      'APK_PACKAGE_INSTALL_NETWORK_INDICATOR: package installation and network access were requested together.',
    );
  }
  return indicators;
}

void _addManifestEvidence(
  Map<String, List<String>> evidence,
  ApkManifestMetadata metadata,
) {
  evidence['APK_MANIFEST']!.addAll(<String>[
    if (metadata.packageName != null) 'PACKAGE: ${metadata.packageName}',
    if (metadata.applicationLabel != null)
      'APPLICATION_LABEL: ${metadata.applicationLabel}',
    if (metadata.versionCode != null) 'VERSION_CODE: ${metadata.versionCode}',
    if (metadata.versionName != null) 'VERSION_NAME: ${metadata.versionName}',
    if (metadata.minSdk != null) 'MIN_SDK: ${metadata.minSdk}',
    if (metadata.targetSdk != null) 'TARGET_SDK: ${metadata.targetSdk}',
    if (metadata.debuggable != null) 'DEBUGGABLE: ${metadata.debuggable}',
    if (metadata.allowBackup != null) 'ALLOW_BACKUP: ${metadata.allowBackup}',
  ]);
}

String? _valueString(Map<String, Object?> values, String key) {
  final Object? value = values[key];
  return value is String ? value : value?.toString();
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value == 'true'
        ? true
        : value == 'false'
        ? false
        : null;
  }
  return null;
}

Map<String, Object?> _attributes(
  Uint8List bytes,
  int offset,
  int headerSize,
  _StringPool pool,
) {
  if (offset + 36 > bytes.length) return const <String, Object?>{};
  final int attributeStart = _u16(bytes, offset + 24);
  final int attributeSize = _u16(bytes, offset + 26);
  final int count = _u16(bytes, offset + 28);
  final int start = offset + attributeStart;
  if (attributeSize < 20 || start + count * attributeSize > bytes.length) {
    return const <String, Object?>{};
  }
  final Map<String, Object?> values = <String, Object?>{};
  for (int index = 0; index < count; index++) {
    final int cursor = start + index * attributeSize;
    final String name = _shortName(pool.value(_u32(bytes, cursor + 4)) ?? '');
    final int rawValue = _u32(bytes, cursor + 8);
    final int dataType = bytes[cursor + 15];
    final int data = _u32(bytes, cursor + 16);
    final Object? value = rawValue != 0xffffffff
        ? pool.value(rawValue)
        : dataType == 0x03
        ? pool.value(data)
        : dataType == 0x12
        ? data != 0
        : data;
    values[name] = value;
  }
  return values;
}

String _shortName(String value) =>
    value.contains(':') ? value.split(':').last : value;

String? _decodeUtf8String(Uint8List bytes, int start) {
  final ({int value, int next})? length = _readLength8(bytes, start);
  if (length == null) return null;
  final ({int value, int next})? byteLength = _readLength8(bytes, length.next);
  if (byteLength == null || byteLength.next + byteLength.value > bytes.length) {
    return null;
  }
  return utf8.decode(
    bytes.sublist(byteLength.next, byteLength.next + byteLength.value),
    allowMalformed: true,
  );
}

String? _decodeUtf16String(Uint8List bytes, int start) {
  final ({int value, int next})? length = _readLength16(bytes, start);
  if (length == null || length.next + length.value * 2 > bytes.length) {
    return null;
  }
  final List<int> units = <int>[];
  for (int index = 0; index < length.value; index++) {
    units.add(_u16(bytes, length.next + index * 2));
  }
  return String.fromCharCodes(units);
}

({int value, int next})? _readLength8(Uint8List bytes, int offset) {
  if (offset >= bytes.length) return null;
  final int first = bytes[offset];
  return first & 0x80 == 0
      ? (value: first, next: offset + 1)
      : offset + 1 < bytes.length
      ? (value: ((first & 0x7f) << 8) | bytes[offset + 1], next: offset + 2)
      : null;
}

({int value, int next})? _readLength16(Uint8List bytes, int offset) {
  if (offset + 2 > bytes.length) return null;
  final int first = _u16(bytes, offset);
  return first & 0x8000 == 0
      ? (value: first, next: offset + 2)
      : offset + 4 <= bytes.length
      ? (
          value: ((first & 0x7fff) << 16) | _u16(bytes, offset + 2),
          next: offset + 4,
        )
      : null;
}

String? _readDexString(Uint8List bytes, int offset) {
  if (offset < 0 || offset >= bytes.length) return null;
  int cursor = offset;
  int shift = 0;
  while (cursor < bytes.length && shift < 35) {
    final int byte = bytes[cursor++];
    if (byte & 0x80 == 0) {
      final int end = bytes.indexOf(0, cursor);
      if (end < cursor) return null;
      return utf8.decode(bytes.sublist(cursor, end), allowMalformed: true);
    }
    shift += 7;
  }
  return null;
}

String? _decodeTextEntry(Uint8List? bytes) =>
    bytes == null ? null : utf8.decode(bytes, allowMalformed: true);

List<String> _extractUrls(String source) {
  final RegExp pattern = RegExp(
    r'''https?://[^\s<>()\[\]{}"']+''',
    caseSensitive: false,
  );
  final Set<String> urls = <String>{};
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final String value = match.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), '');
    if (value.length <= 2048) urls.add(value);
    if (urls.length >= 50) break;
  }
  return urls.toList(growable: false);
}

String _domainLabel(String url) => Uri.tryParse(url)?.host ?? 'unknown';

bool _looksLikeUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

bool _isDexEntry(_ZipEntry entry) =>
    RegExp(r'^classes(?:[2-9][0-9]*)?\.dex$').hasMatch(entry.name);

bool _isNativeEntry(_ZipEntry entry) =>
    entry.name.startsWith('lib/') && entry.name.endsWith('.so');

bool _isSignatureEntry(_ZipEntry entry) => RegExp(
  r'^META-INF/[^/]+\.(RSA|DSA|EC)$',
  caseSensitive: false,
).hasMatch(entry.name);

bool _isInspectableTextEntry(_ZipEntry entry) =>
    entry.name.startsWith('assets/') && entry.uncompressedSize <= 256 * 1024;

bool _isNestedArchiveName(String value) =>
    RegExp(
      r'\.(zip|jar|apk|rar|7z|tar|gz)$',
      caseSensitive: false,
    ).hasMatch(value) &&
    !value.startsWith('META-INF/');

bool _unsafePath(String value) =>
    value.startsWith('/') ||
    value.startsWith('\\') ||
    value.split('/').any((part) => part == '..');

bool _isDex(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x64 &&
    bytes[1] == 0x65 &&
    bytes[2] == 0x78 &&
    bytes[3] == 0x0a;

int _findEocd(Uint8List bytes) {
  final int lower = bytes.length > 65557 ? bytes.length - 65557 : 0;
  for (int offset = bytes.length - 22; offset >= lower; offset--) {
    if (_u32(bytes, offset) == 0x06054b50) return offset;
  }
  return -1;
}

int _u16(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _u32(Uint8List bytes, int offset) =>
    _u16(bytes, offset) | (_u16(bytes, offset + 2) << 16);

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
