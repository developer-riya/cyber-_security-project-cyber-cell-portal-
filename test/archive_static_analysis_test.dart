import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/services/archive_static_analysis.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/security_pipeline_config.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:cyberuday/services/threat_input_validator.dart';

late Directory _directory;

void main() {
  setUp(() async {
    _directory = await Directory.systemTemp.createTemp(
      'cyber-uday-archive-test-',
    );
  });

  tearDown(() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  });

  test('normal ZIP receives bounded inventory and no threat signal', () async {
    final File file = await _write(<String, List<int>>{
      'notes/readme.txt': utf8.encode('This is a harmless archive.'),
      'data.json': utf8.encode('{"status":"ok"}'),
    });
    final ArchiveStaticAnalysisResult result = await _analyze(file);

    expect(result.status, ArchiveAnalysisStatus.complete);
    expect(result.entries, hasLength(2));
    expect(result.indicators, isEmpty);
    expect(result.evidence['ARCHIVE_FEATURES'], contains('FORMAT: ZIP'));
  });

  test('malformed and renamed non-ZIP inputs are UNKNOWN', () async {
    final File malformed = File('${_directory.path}/bad.zip')
      ..writeAsBytesSync(const <int>[0x50, 0x4b, 0x03]);
    final File renamed = File('${_directory.path}/renamed.zip')
      ..writeAsBytesSync(utf8.encode('not an archive'));

    expect((await _analyze(malformed)).status, ArchiveAnalysisStatus.unknown);
    expect((await _analyze(renamed)).status, ArchiveAnalysisStatus.unknown);
  });

  test('unsafe paths and duplicate collisions are rejected', () async {
    final File unsafe = await _write(<String, List<int>>{
      '../outside.txt': <int>[1],
    });
    final File collision = await _write(<String, List<int>>{
      'file.txt': <int>[1],
    }, duplicateName: 'FILE.TXT');

    expect((await _analyze(unsafe)).status, ArchiveAnalysisStatus.unknown);
    expect((await _analyze(collision)).status, ArchiveAnalysisStatus.unknown);
  });

  test('compression ratio and nested archive limits produce PARTIAL', () async {
    final File ratio = await _write(<String, List<int>>{
      'payload.bin': <int>[1],
    }, declaredUncompressedSize: 10000);
    final File nested = await _write(<String, List<int>>{
      'inner.zip': _zip(<String, List<int>>{
        'nested.txt': <int>[1],
      }),
    });

    final ArchiveStaticAnalysisResult ratioResult = await _analyze(ratio);
    final ArchiveStaticAnalysisResult nestedResult = await _analyze(nested);
    final ArchiveStaticAnalysisResult oversizedResult =
        await const LocalArchiveStaticAnalyzer(
          config: SecurityPipelineConfig(maxArchiveSizeBytes: 3),
        ).analyze(
          reference: nested.path,
          fileName: 'oversized.zip',
          mimeType: 'application/zip',
        );
    expect(ratioResult.status, ArchiveAnalysisStatus.partial);
    expect(
      ratioResult.indicators,
      contains(startsWith('ARCHIVE_COMPRESSION_RATIO_INDICATOR')),
    );
    expect(nestedResult.status, ArchiveAnalysisStatus.partial);
    expect(
      nestedResult.indicators,
      contains(startsWith('ARCHIVE_NESTED_ARCHIVE_INDICATOR')),
    );
    expect(oversizedResult.status, ArchiveAnalysisStatus.partial);
  });

  test('executable-looking entries are evidence only', () async {
    final File file = await _write(<String, List<int>>{
      'scripts/install.sh': utf8.encode('#!/bin/sh\necho safe'),
      'bin/tool.elf': <int>[0x7f, 0x45, 0x4c, 0x46],
    });
    final ArchiveStaticAnalysisResult result = await _analyze(file);

    expect(result.status, ArchiveAnalysisStatus.complete);
    expect(
      result.indicators,
      contains(startsWith('ARCHIVE_EXECUTABLE_CONTENT_INDICATOR')),
    );
  });

  test(
    'bounded text reuses URL and text evidence without network access',
    () async {
      final File file = await _write(<String, List<int>>{
        'message.txt': utf8.encode(
          'Urgent verify your password at https://198.51.100.10/login',
        ),
      });
      final ArchiveStaticAnalysisResult result = await _analyze(file);

      expect(result.extractedUrls, contains('https://198.51.100.10/login'));
      expect(result.evidence['ARCHIVE_TEXT'], isNotEmpty);
      final ShareThreatAnalysis analysis = await _serviceAnalysis(file);
      expect(analysis.analyzerName, 'Archive Static Analysis Intake');
      expect(analysis.indicators, isNotEmpty);
    },
  );

  test('APK entries delegate to the existing APK analyzer', () async {
    final File file = await _write(<String, List<int>>{
      'apps/sample.apk': _zip(<String, List<int>>{
        'AndroidManifest.xml': const <int>[3, 0, 8, 0],
        'classes.dex': const <int>[0x64, 0x65, 0x78, 0x0a],
      }),
    });
    final ArchiveStaticAnalysisResult result = await _analyze(file);

    expect(result.apkResults, hasLength(1));
    expect(result.evidence['ARCHIVE_APK_DELEGATION'], isNotEmpty);
    expect(result.status, ArchiveAnalysisStatus.partial);
  });

  test(
    'unsupported archive source and invalid content URI remain UNKNOWN',
    () async {
      final File rar = File('${_directory.path}/archive.rar')
        ..writeAsBytesSync(const <int>[0x52, 0x61, 0x72, 0x21]);
      expect((await _analyze(rar)).status, ArchiveAnalysisStatus.unknown);

      final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
        <Object?, Object?>{
          'id': 'unavailable-archive',
          'receivedAt': 1,
          'items': <Object?>[
            <Object?, Object?>{
              'uri': 'content://revoked/archive.zip',
              'mimeType': 'application/zip',
              'contentType': 'archive',
              'fileName': 'archive.zip',
              'isAccessible': false,
              'error': 'The source app did not grant access to this file.',
            },
          ],
        },
      );
      final ThreatValidationResult validation = const ThreatInputValidator()
          .validate(payload, ThreatAnalysisRequest.fromPayload(payload));
      expect(validation.isValid, isFalse);
      expect(validation.errors.single, contains('source app'));
    },
  );

  test('shared item count is bounded before analysis', () {
    final IncomingSharePayload payload = IncomingSharePayload(
      id: 'many-items',
      receivedAt: DateTime(2026),
      attachments: List<IncomingShareAttachment>.generate(
        11,
        (int index) => IncomingShareAttachment.fromFileReference(
          reference: 'content://example/$index.zip',
          fileName: '$index.zip',
          sizeBytes: 1,
          mimeType: 'application/zip',
        ),
      ),
    );
    final ThreatValidationResult validation = const ThreatInputValidator()
        .validate(payload, ThreatAnalysisRequest.fromPayload(payload));
    expect(validation.isValid, isFalse);
    expect(validation.errors, contains(contains('item count')));
  });

  test('Android manifest exposes bounded share targets only', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.intent.action.SEND'));
    expect(manifest, contains('android.intent.action.SEND_MULTIPLE'));
    expect(manifest, contains('text/plain'));
    expect(manifest, contains('image/*'));
    expect(manifest, contains('application/pdf'));
    expect(manifest, contains('application/vnd.android.package-archive'));
    expect(manifest, contains('application/zip'));
    expect(manifest, isNot(contains('android:mimeType="*/*"')));
  });
}

int _fixtureCounter = 0;

Future<ArchiveStaticAnalysisResult> _analyze(File file) =>
    const LocalArchiveStaticAnalyzer().analyze(
      reference: file.path,
      fileName: file.path,
      mimeType: 'application/zip',
    );

Future<ShareThreatAnalysis> _serviceAnalysis(File file) async {
  final IncomingSharePayload payload =
      IncomingSharePayload.fromManualFiles(<IncomingShareAttachment>[
        IncomingShareAttachment.fromFileReference(
          reference: file.path,
          fileName: 'sample.zip',
          sizeBytes: await file.length(),
          mimeType: 'application/zip',
        ),
      ]);
  final QuarantineRecord quarantine = QuarantineRecord(
    requestId: payload.id,
    createdAt: DateTime(2026),
    expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
    metadata: const <String, Object?>{},
    contents: <QuarantinedContent>[
      QuarantinedContent(
        attachmentIndex: 0,
        reference: file.uri.toString(),
        sizeBytes: await file.length(),
      ),
    ],
  );
  return const ShareThreatAnalysisService().analyzeAsync(
    payload,
    quarantine: quarantine,
  );
}

Future<File> _write(
  Map<String, List<int>> entries, {
  String? duplicateName,
  int? declaredUncompressedSize,
}) async {
  final Map<String, List<int>> all = <String, List<int>>{...entries};
  if (duplicateName != null) all[duplicateName] = <int>[2];
  final File file = File('${_directory.path}/fixture-${_fixtureCounter++}.zip');
  await file.writeAsBytes(
    _zip(all, declaredUncompressedSize: declaredUncompressedSize),
  );
  return file;
}

List<int> _zip(
  Map<String, List<int>> entries, {
  int? declaredUncompressedSize,
}) {
  final List<int> local = <int>[];
  final List<int> central = <int>[];
  int offset = 0;
  for (final MapEntry<String, List<int>> entry in entries.entries) {
    final List<int> name = utf8.encode(entry.key);
    final List<int> data = entry.value;
    final int uncompressed = declaredUncompressedSize ?? data.length;
    final List<int> localHeader = <int>[
      ..._u32(0x04034b50),
      ..._u16(20),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(0),
      ..._u32(data.length),
      ..._u32(uncompressed),
      ..._u16(name.length),
      ..._u16(0),
      ...name,
      ...data,
    ];
    local.addAll(localHeader);
    central.addAll(<int>[
      ..._u32(0x02014b50),
      ..._u16(20),
      ..._u16(20),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(0),
      ..._u32(data.length),
      ..._u32(uncompressed),
      ..._u16(name.length),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(0),
      ..._u32(offset),
      ...name,
    ]);
    offset += localHeader.length;
  }
  return <int>[
    ...local,
    ...central,
    ..._u32(0x06054b50),
    ..._u16(0),
    ..._u16(0),
    ..._u16(entries.length),
    ..._u16(entries.length),
    ..._u32(central.length),
    ..._u32(local.length),
    ..._u16(0),
  ];
}

List<int> _u16(int value) => <int>[value & 0xff, (value >> 8) & 0xff];
List<int> _u32(int value) => <int>[..._u16(value), ..._u16(value >> 16)];
