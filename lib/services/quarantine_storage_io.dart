import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/threat_analysis.dart';
import 'quarantine_storage_base.dart';
import 'security_pipeline_config.dart';

/// Development-only temporary untrusted-content quarantine.
///
/// Files are copied under an OS temporary directory with generated directory
/// and file names. They are never opened externally or executed. This is not
/// a malware sandbox and must be replaced by isolated backend/object storage
/// before production deep analysis.
class TemporaryQuarantineStorage implements QuarantineStorage {
  const TemporaryQuarantineStorage({
    this.config = const SecurityPipelineConfig(),
  });

  final SecurityPipelineConfig config;
  static final Map<String, QuarantineRecord> _records =
      <String, QuarantineRecord>{};

  @override
  Future<QuarantineRecord> store(
    ThreatAnalysisRequest request, {
    required DateTime expiresAt,
  }) async {
    if (request.references
        .where((reference) => reference.trim().isNotEmpty)
        .isEmpty) {
      final QuarantineRecord record = QuarantineRecord(
        requestId: request.requestId,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        metadata: <String, Object?>{
          'inputType': request.inputType.name,
          'attachmentCount': 0,
          'temporaryContent': false,
        },
      );
      _records[request.requestId] = record;
      return record;
    }
    final Directory directory = await Directory.systemTemp.createTemp(
      'cyber-uday-quarantine-',
    );
    final List<QuarantinedContent> contents = <QuarantinedContent>[];
    try {
      for (int index = 0; index < request.references.length; index++) {
        final String reference = request.references[index];
        if (reference.trim().isEmpty) continue;
        final File? source = _sourceFile(reference);
        if (source == null || !await source.exists()) continue;
        final File destination = File('${directory.path}/item-$index.bin');
        final bool staged = _isTemporaryStagedSource(request, index);
        final _CopiedContent copied = await _copyBounded(
          source,
          destination,
          removeSourceAfterCopy: staged,
        );
        contents.add(
          QuarantinedContent(
            attachmentIndex: index,
            reference: destination.uri.toString(),
            sizeBytes: copied.sizeBytes,
            sha256: copied.sha256,
          ),
        );
      }
      final QuarantineRecord record = QuarantineRecord(
        requestId: request.requestId,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        directoryReference: directory.uri.toString(),
        contents: List<QuarantinedContent>.unmodifiable(contents),
        metadata: <String, Object?>{
          'inputType': request.inputType.name,
          'attachmentCount': request.references.length,
          'temporaryContent': contents.isNotEmpty,
        },
      );
      _records[request.requestId] = record;
      return record;
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<QuarantineRecord?> get(String requestId) async => _records[requestId];

  @override
  Future<bool> exists(String requestId) async =>
      _records.containsKey(requestId);

  @override
  Future<void> delete(String requestId) async {
    final QuarantineRecord? record = _records.remove(requestId);
    final String? directoryReference = record?.directoryReference;
    if (directoryReference == null) return;
    final Directory directory = Directory.fromUri(
      Uri.parse(directoryReference),
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  File? _sourceFile(String reference) {
    if (reference.startsWith('content://') ||
        reference.startsWith('picker://')) {
      return null;
    }
    return reference.startsWith('file://')
        ? File.fromUri(Uri.parse(reference))
        : File(reference);
  }

  bool _isTemporaryStagedSource(ThreatAnalysisRequest request, int index) {
    final Object? values = request.metadata['temporaryQuarantineSources'];
    return values is List<Object?> &&
            index < values.length &&
            values[index] is bool
        ? values[index] as bool
        : false;
  }

  Future<_CopiedContent> _copyBounded(
    File source,
    File destination, {
    required bool removeSourceAfterCopy,
  }) async {
    final IOSink sink = destination.openWrite(mode: FileMode.writeOnly);
    final _DigestSink digestSink = _DigestSink();
    final ByteConversionSink digestConversion = sha256.startChunkedConversion(
      digestSink,
    );
    int total = 0;
    try {
      await for (final List<int> chunk in source.openRead()) {
        total += chunk.length;
        if (total > config.maxFileSizeBytes) {
          throw const FileSystemException('Quarantine size limit exceeded');
        }
        digestConversion.add(chunk);
        sink.add(chunk);
      }
      digestConversion.close();
      await sink.flush();
      await sink.close();
      if (removeSourceAfterCopy && await source.exists()) {
        await source.delete();
      }
      return _CopiedContent(
        sizeBytes: total,
        sha256: digestSink.value.toString(),
      );
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }
}

class _CopiedContent {
  const _CopiedContent({required this.sizeBytes, required this.sha256});

  final int sizeBytes;
  final String sha256;
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
