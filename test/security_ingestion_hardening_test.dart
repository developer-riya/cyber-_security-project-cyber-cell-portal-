import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/services/file_hash_service.dart';
import 'package:cyberuday/services/file_type_inspector.dart';
import 'package:cyberuday/services/file_type_validation.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/security_audit_logger.dart';
import 'package:cyberuday/services/security_pipeline_config.dart';
import 'package:cyberuday/services/threat_analysis_cancellation.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('temporary untrusted-content quarantine', () {
    test(
      'copies bytes under a generated temporary directory and cleans up',
      () async {
        final Directory fixtureDirectory = await Directory.systemTemp
            .createTemp('cyber-uday-fixture-');
        addTearDown(() => fixtureDirectory.delete(recursive: true));
        final File source = File('${fixtureDirectory.path}/source.pdf');
        await source.writeAsBytes(_validPdf());
        const TemporaryQuarantineStorage storage = TemporaryQuarantineStorage();
        final ThreatAnalysisRequest request = await _requestFor(
          source,
          fileName: 'source.pdf',
          mimeType: 'application/pdf',
          id: 'quarantine-copy',
        );

        final QuarantineRecord record = await storage.store(
          request,
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        );
        final File quarantined = File.fromUri(
          Uri.parse(record.contents.single.reference),
        );

        expect(record.contents, hasLength(1));
        expect(quarantined.path, isNot(source.path));
        expect(await quarantined.exists(), isTrue);
        expect(await quarantined.readAsBytes(), await source.readAsBytes());

        await storage.delete(request.requestId);
        expect(await quarantined.exists(), isFalse);
        expect(await storage.exists(request.requestId), isFalse);
      },
    );

    test(
      'cancellation after quarantine returns UNKNOWN and cleans up',
      () async {
        final ThreatAnalysisCancellationToken cancellation =
            ThreatAnalysisCancellationToken();
        final InMemorySecurityAuditLogger audit = InMemorySecurityAuditLogger();
        final _CancellingStorage storage = _CancellingStorage(cancellation);
        final ThreatAnalysisEngine engine = ThreatAnalysisEngine(
          quarantineStorage: storage,
          auditLogger: audit,
        );
        final IncomingSharePayload payload =
            IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
              'id': 'cancelled-request',
              'receivedAt': 1,
              'text': 'https://example.com',
              'items': const <Object?>[],
            });

        final ThreatAnalysisRun run = await engine.analyze(
          payload,
          cancellationToken: cancellation,
        );

        expect(run.result.verdict, ThreatVerdict.unknown);
        expect(await storage.exists('cancelled-request'), isFalse);
        expect(
          audit.events.map((event) => event.type),
          contains(SecurityAuditEventType.quarantineCleanup),
        );
      },
    );

    test(
      'async timeout returns UNKNOWN and cleans up quarantine metadata',
      () async {
        final InMemorySecurityAuditLogger audit = InMemorySecurityAuditLogger();
        const InMemoryQuarantineStorage storage = InMemoryQuarantineStorage();
        final ThreatAnalysisEngine engine = ThreatAnalysisEngine(
          config: const SecurityPipelineConfig(
            maxAnalysisTime: Duration(milliseconds: 1),
          ),
          quarantineStorage: storage,
          auditLogger: audit,
          analysisExecutor: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            throw StateError('The result should have timed out first.');
          },
        );
        final IncomingSharePayload payload =
            IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
              'id': 'timeout-request',
              'receivedAt': 1,
              'text': 'https://example.com',
              'items': const <Object?>[],
            });

        final ThreatAnalysisRun run = await engine.analyze(payload);

        expect(run.result.verdict, ThreatVerdict.unknown);
        expect(run.result.status, ThreatResultStatus.timeout);
        expect(await storage.exists('timeout-request'), isFalse);
        expect(
          audit.events.map((event) => event.type),
          contains(SecurityAuditEventType.timeout),
        );
      },
    );
  });

  group('bounded deterministic hashing', () {
    test(
      'same content has the same SHA-256 and different content changes it',
      () async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'cyber-uday-hash-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final File first = File('${directory.path}/first.bin');
        final File duplicate = File('${directory.path}/duplicate.bin');
        final File different = File('${directory.path}/different.bin');
        await first.writeAsBytes(const <int>[1, 2, 3, 4]);
        await duplicate.writeAsBytes(const <int>[1, 2, 3, 4]);
        await different.writeAsBytes(const <int>[4, 3, 2, 1]);

        final String? firstHash = await sha256ForReference(
          first.uri.toString(),
          maxBytes: 4,
        );
        final String? duplicateHash = await sha256ForReference(
          duplicate.uri.toString(),
          maxBytes: 4,
        );
        final String? differentHash = await sha256ForReference(
          different.uri.toString(),
          maxBytes: 4,
        );

        expect(firstHash, isNotNull);
        expect(firstHash, duplicateHash);
        expect(firstHash, isNot(differentHash));
        expect(
          await sha256ForReference(first.uri.toString(), maxBytes: 3),
          isNull,
        );
        expect(
          await sha256ForReference('content://example/item', maxBytes: 4),
          isNull,
        );
      },
    );
  });

  group('bounded structural file validation', () {
    test('accepts harmless PNG and PDF fixtures', () async {
      final _FixtureFiles files = await _FixtureFiles.create();
      addTearDown(files.dispose);
      final List<FileTypeValidationResult> png = await _inspect(
        files.png,
        fileName: 'safe.png',
        mimeType: 'image/png',
      );
      final List<FileTypeValidationResult> pdf = await _inspect(
        files.pdf,
        fileName: 'safe.pdf',
        mimeType: 'application/pdf',
      );

      expect(png.single.mismatch, isFalse);
      expect(png.single.structurallyValid, isTrue);
      expect(pdf.single.mismatch, isFalse);
      expect(pdf.single.structurallyValid, isTrue);
    });

    test(
      'detects harmless filename/signature mismatches and invalid PDF',
      () async {
        final _FixtureFiles files = await _FixtureFiles.create();
        addTearDown(files.dispose);
        final List<FileTypeValidationResult> fakePdf = await _inspect(
          files.fakePdf,
          fileName: 'invoice.pdf',
          mimeType: 'application/pdf',
        );
        final List<FileTypeValidationResult> fakeJpg = await _inspect(
          files.fakeJpg,
          fileName: 'photo.jpg',
          mimeType: 'image/jpeg',
        );
        final List<FileTypeValidationResult> invalidPdf = await _inspect(
          files.invalidPdf,
          fileName: 'broken.pdf',
          mimeType: 'application/pdf',
        );

        expect(fakePdf.single.blocksAnalysis, isTrue);
        expect(fakeJpg.single.blocksAnalysis, isTrue);
        expect(invalidPdf.single.blocksAnalysis, isTrue);
      },
    );

    test('requires APK structure beyond a ZIP header', () async {
      final _FixtureFiles files = await _FixtureFiles.create();
      addTearDown(files.dispose);
      final List<FileTypeValidationResult> renamedZip = await _inspect(
        files.zip,
        fileName: 'renamed.apk',
        mimeType: 'application/vnd.android.package-archive',
      );
      final List<FileTypeValidationResult> validApkStructure = await _inspect(
        files.apkStructure,
        fileName: 'fixture.apk',
        mimeType: 'application/vnd.android.package-archive',
      );
      final List<FileTypeValidationResult> malformedApk = await _inspect(
        files.malformedApk,
        fileName: 'broken.apk',
        mimeType: 'application/vnd.android.package-archive',
      );

      expect(renamedZip.single.blocksAnalysis, isTrue);
      expect(validApkStructure.single.mismatch, isFalse);
      expect(validApkStructure.single.structurallyValid, isTrue);
      expect(malformedApk.single.blocksAnalysis, isTrue);
    });

    test(
      'enforces archive file-count, extracted-size, and nested-depth limits',
      () async {
        final _FixtureFiles files = await _FixtureFiles.create();
        addTearDown(files.dispose);
        final FileTypeInspector fileCountInspector = FileTypeInspector(
          config: const SecurityPipelineConfig(maxArchiveFiles: 1),
        );
        final FileTypeInspector sizeInspector = FileTypeInspector(
          config: const SecurityPipelineConfig(maxExtractedSizeBytes: 3),
        );
        final FileTypeInspector compressedSizeInspector = FileTypeInspector(
          config: const SecurityPipelineConfig(maxArchiveSizeBytes: 3),
        );
        final List<FileTypeValidationResult> tooMany = await _inspect(
          files.zipWithTwoFiles,
          fileName: 'many.zip',
          mimeType: 'application/zip',
          inspector: fileCountInspector,
        );
        final List<FileTypeValidationResult> tooLarge = await _inspect(
          files.zip,
          fileName: 'large.zip',
          mimeType: 'application/zip',
          inspector: sizeInspector,
        );
        final List<FileTypeValidationResult> nested = await _inspect(
          files.nestedZip,
          fileName: 'nested.zip',
          mimeType: 'application/zip',
        );
        final List<FileTypeValidationResult> compressedTooLarge =
            await _inspect(
              files.zip,
              fileName: 'compressed-too-large.zip',
              mimeType: 'application/zip',
              inspector: compressedSizeInspector,
            );

        expect(tooMany.single.blocksAnalysis, isTrue);
        expect(tooLarge.single.blocksAnalysis, isTrue);
        expect(nested.single.blocksAnalysis, isTrue);
        expect(compressedTooLarge.single.blocksAnalysis, isTrue);
      },
    );
  });
}

Future<List<FileTypeValidationResult>> _inspect(
  File file, {
  required String fileName,
  required String mimeType,
  FileTypeInspector inspector = const FileTypeInspector(),
}) async {
  const TemporaryQuarantineStorage storage = TemporaryQuarantineStorage();
  final ThreatAnalysisRequest request = await _requestFor(
    file,
    fileName: fileName,
    mimeType: mimeType,
    id: 'fixture-${DateTime.now().microsecondsSinceEpoch}',
  );
  final QuarantineRecord record = await storage.store(
    request,
    expiresAt: DateTime.now().add(const Duration(minutes: 1)),
  );
  try {
    return await inspector.inspect(
      _payloadFor(file, fileName, mimeType, request.requestId),
      record,
    );
  } finally {
    await storage.delete(request.requestId);
  }
}

Future<ThreatAnalysisRequest> _requestFor(
  File file, {
  required String fileName,
  required String mimeType,
  required String id,
}) async => ThreatAnalysisRequest.fromPayload(
  _payloadFor(file, fileName, mimeType, id),
);

IncomingSharePayload _payloadFor(
  File file,
  String fileName,
  String mimeType,
  String id,
) => IncomingSharePayload(
  id: id,
  receivedAt: DateTime.fromMillisecondsSinceEpoch(1),
  attachments: <IncomingShareAttachment>[
    IncomingShareAttachment.fromFileReference(
      reference: file.uri.toString(),
      fileName: fileName,
      sizeBytes: file.lengthSync(),
      mimeType: mimeType,
    ),
  ],
);

class _FixtureFiles {
  _FixtureFiles._(this.directory);

  final Directory directory;
  late final File png = _write('safe.png', _validPng());
  late final File pdf = _write('safe.pdf', _validPdf());
  late final File fakePdf = _write('invoice.pdf', _validPng());
  late final File zip = _write(
    'safe.zip',
    _zip(<String, List<int>>{'note.txt': utf8.encode('hello')}),
  );
  late final File fakeJpg = _write('photo.jpg', zip.readAsBytesSync());
  late final File apkStructure = _write(
    'fixture.apk',
    _zip(<String, List<int>>{
      'AndroidManifest.xml': const <int>[3, 0, 8, 0],
      'classes.dex': const <int>[0x64, 0x65, 0x78, 0x0a],
    }),
  );
  late final File malformedApk = _write('broken.apk', const <int>[1, 2, 3]);
  late final File invalidPdf = _write(
    'broken.pdf',
    utf8.encode('%PDF-1.4\nno EOF'),
  );
  late final File zipWithTwoFiles = _write(
    'many.zip',
    _zip(<String, List<int>>{
      'one.txt': const <int>[1],
      'two.txt': const <int>[2],
    }),
  );
  late final File nestedZip = _write(
    'nested.zip',
    _zip(<String, List<int>>{'inner.zip': zip.readAsBytesSync()}),
  );

  static Future<_FixtureFiles> create() async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'cyber-uday-fixtures-',
    );
    return _FixtureFiles._(directory);
  }

  File _write(String name, List<int> bytes) {
    final File file = File('${directory.path}/$name');
    file.writeAsBytesSync(bytes);
    return file;
  }

  Future<void> dispose() => directory.delete(recursive: true);
}

List<int> _validPng() => const <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0,
];

List<int> _validPdf() =>
    utf8.encode('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF\n');

List<int> _zip(Map<String, List<int>> entries) {
  final BytesBuilder output = BytesBuilder(copy: false);
  final List<_ZipEntry> directory = <_ZipEntry>[];
  for (final MapEntry<String, List<int>> entry in entries.entries) {
    final List<int> name = utf8.encode(entry.key);
    final int offset = output.length;
    _u32(output, 0x04034b50);
    _u16(output, 20);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, 0);
    _u32(output, 0);
    _u32(output, entry.value.length);
    _u32(output, entry.value.length);
    _u16(output, name.length);
    _u16(output, 0);
    output.add(name);
    output.add(entry.value);
    directory.add(_ZipEntry(name, entry.value.length, offset));
  }
  final int directoryOffset = output.length;
  for (final _ZipEntry entry in directory) {
    _u32(output, 0x02014b50);
    _u16(output, 20);
    _u16(output, 20);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, 0);
    _u32(output, 0);
    _u32(output, entry.size);
    _u32(output, entry.size);
    _u16(output, entry.name.length);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, 0);
    _u32(output, 0);
    _u32(output, entry.offset);
    output.add(entry.name);
  }
  final int directorySize = output.length - directoryOffset;
  _u32(output, 0x06054b50);
  _u16(output, 0);
  _u16(output, 0);
  _u16(output, directory.length);
  _u16(output, directory.length);
  _u32(output, directorySize);
  _u32(output, directoryOffset);
  _u16(output, 0);
  return output.takeBytes();
}

void _u16(BytesBuilder builder, int value) =>
    builder.add(<int>[value & 0xff, (value >> 8) & 0xff]);

void _u32(BytesBuilder builder, int value) => builder.add(<int>[
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
]);

class _ZipEntry {
  const _ZipEntry(this.name, this.size, this.offset);

  final List<int> name;
  final int size;
  final int offset;
}

class _CancellingStorage implements QuarantineStorage {
  _CancellingStorage(this.cancellation);

  final ThreatAnalysisCancellationToken cancellation;
  final InMemoryQuarantineStorage _delegate = InMemoryQuarantineStorage();

  @override
  Future<QuarantineRecord> store(
    ThreatAnalysisRequest request, {
    required DateTime expiresAt,
  }) async {
    final QuarantineRecord record = await _delegate.store(
      request,
      expiresAt: expiresAt,
    );
    cancellation.cancel();
    return record;
  }

  @override
  Future<void> delete(String requestId) => _delegate.delete(requestId);

  @override
  Future<bool> exists(String requestId) => _delegate.exists(requestId);

  @override
  Future<QuarantineRecord?> get(String requestId) => _delegate.get(requestId);
}
