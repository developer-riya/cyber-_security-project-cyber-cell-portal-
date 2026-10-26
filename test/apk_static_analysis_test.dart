import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/services/apk_static_analysis.dart';
import 'package:cyberuday/services/file_type_inspector.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/security_pipeline_config.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cyber-uday-apk-test-');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('valid APK manifest and DEX receive bounded static analysis', () async {
    final File file = await _writeApk(temp, signed: true);
    final ApkStaticAnalysisResult result = await LocalApkStaticAnalyzer()
        .analyze(
          reference: file.path,
          fileName: 'sample.apk',
          mimeType: 'application/vnd.android.package-archive',
        );

    expect(result.status, ApkAnalysisStatus.complete);
    expect(result.manifest.packageName, 'com.example.sample');
    expect(result.manifest.versionName, '1.0');
    expect(result.manifest.minSdk, '24');
    expect(result.manifest.targetSdk, '35');
    expect(result.manifest.components, hasLength(1));
    expect(result.manifest.components.single.exported, isTrue);
    expect(result.manifest.components.single.intentFilterCount, 1);
    expect(result.dexCount, 1);
    expect(result.signature.analysisAvailable, isTrue);
    expect(result.evidence['APK_SIGNATURE'], isNotEmpty);
  });

  test('normal permissions are recorded without a threat signal', () async {
    final File file = await _writeApk(
      temp,
      signed: true,
      permissions: const <String>['android.permission.INTERNET'],
    );
    final ApkStaticAnalysisResult result = await _analyze(file);

    expect(result.status, ApkAnalysisStatus.complete);
    expect(
      result.manifest.permissions,
      contains('android.permission.INTERNET'),
    );
    expect(result.indicators, isEmpty);
  });

  test(
    'contextual permission combinations become structured indicators',
    () async {
      final File file = await _writeApk(
        temp,
        signed: true,
        permissions: const <String>[
          'android.permission.READ_SMS',
          'android.permission.READ_CONTACTS',
          'android.permission.INTERNET',
          'android.permission.SYSTEM_ALERT_WINDOW',
          'android.permission.BIND_ACCESSIBILITY_SERVICE',
        ],
      );
      final ApkStaticAnalysisResult result = await _analyze(file);

      expect(
        result.indicators,
        contains(startsWith('APK_PERMISSION_COMBINATION_INDICATOR')),
      );
      expect(
        result.indicators,
        contains(
          'APK_PERMISSION_COMBINATION_INDICATOR: overlay and accessibility capabilities were requested together.',
        ),
      );
    },
  );

  test(
    'DEX URL and security strings are extracted without execution',
    () async {
      final File file = await _writeApk(
        temp,
        signed: true,
        dexStrings: const <String>[
          'https://198.51.100.10/login',
          'runtime.exec',
          'request OTP password',
        ],
      );
      final ApkStaticAnalysisResult result = await _analyze(file);

      expect(result.extractedUrls, contains('https://198.51.100.10/login'));
      expect(result.indicators, contains('APK_SHELL_EXECUTION_INDICATOR'));
      expect(result.indicators, contains('APK_CREDENTIAL_STRING_INDICATOR'));
    },
  );

  test('multiple DEX files and native libraries are metadata-only', () async {
    final File file = await _writeApk(
      temp,
      signed: true,
      dexCount: 2,
      nativeLibraries: const <String>['lib/arm64-v8a/libsample.so'],
    );
    final ApkStaticAnalysisResult result = await _analyze(file);

    expect(result.dexCount, 2);
    expect(result.nativeLibraries.single.abi, 'arm64-v8a');
    expect(result.nativeLibraries.single.sha256, hasLength(64));
    expect(
      result.evidence['APK_NATIVE_LIBRARIES'],
      contains(contains('not loaded')),
    );
  });

  test('missing signature metadata is partial and never safe', () async {
    final File file = await _writeApk(temp, signed: false);
    final ApkStaticAnalysisResult result = await _analyze(file);

    expect(result.status, ApkAnalysisStatus.partial);
    expect(result.signature.analysisAvailable, isFalse);
    expect(result.indicators, contains('SIGNATURE_ANALYSIS_UNAVAILABLE'));
  });

  test('malformed APK and ordinary ZIP renamed to APK are unknown', () async {
    final File malformed = File('${temp.path}/bad.apk')
      ..writeAsBytesSync(<int>[0x50, 0x4b, 0x03]);
    final ApkStaticAnalysisResult malformedResult = await _analyze(malformed);
    expect(malformedResult.status, ApkAnalysisStatus.unknown);

    final File renamed = File('${temp.path}/renamed.apk')
      ..writeAsBytesSync(
        _zip(<String, List<int>>{'notes.txt': utf8.encode('hello')}),
      );
    final ApkStaticAnalysisResult renamedResult = await _analyze(renamed);
    expect(renamedResult.status, ApkAnalysisStatus.unknown);
  });

  test('nested and oversized inputs are bounded', () async {
    final File nested = await _writeApk(
      temp,
      signed: true,
      extraEntries: <String, List<int>>{
        'assets/inner.zip': _zip(<String, List<int>>{
          'nested.txt': <int>[1],
        }),
      },
    );
    final ApkStaticAnalysisResult nestedResult = await _analyze(nested);
    expect(nestedResult.status, ApkAnalysisStatus.partial);
    expect(
      nestedResult.evidence['APK_STRUCTURE'],
      contains(contains('NESTED_ARCHIVE')),
    );

    final File oversized = await _writeApk(temp, signed: true);
    final ApkStaticAnalysisResult oversizedResult =
        await LocalApkStaticAnalyzer(
          config: const SecurityPipelineConfig(maxFileSizeBytes: 64),
        ).analyze(
          reference: oversized.path,
          fileName: 'oversized.apk',
          mimeType: 'application/vnd.android.package-archive',
        );
    expect(oversizedResult.status, ApkAnalysisStatus.partial);
  });

  test('scanner service and file-type gate use the APK analyzer', () async {
    final File file = await _writeApk(temp, signed: true);
    final IncomingSharePayload payload = IncomingSharePayload(
      id: 'apk-service-test',
      receivedAt: DateTime(2026),
      attachments: <IncomingShareAttachment>[
        IncomingShareAttachment.fromFileReference(
          reference: file.path,
          fileName: 'sample.apk',
          sizeBytes: await file.length(),
          mimeType: 'application/vnd.android.package-archive',
        ),
      ],
      sourceApplication: 'fixture',
    );
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
    final ShareThreatAnalysis analysis =
        await const ShareThreatAnalysisService().analyzeAsync(
          payload,
          quarantine: quarantine,
        );
    expect(analysis.analyzerName, 'APK Static Analysis Intake');
    expect(analysis.structuredEvidence, contains('APK_MANIFEST'));

    final FileTypeInspector inspector = const FileTypeInspector();
    final results = await inspector.inspect(payload, quarantine);
    expect(
      results.single.detectedType,
      'application/vnd.android.package-archive',
    );
    expect(results.single.structurallyValid, isTrue);
  });
}

Future<ApkStaticAnalysisResult> _analyze(File file) =>
    LocalApkStaticAnalyzer().analyze(
      reference: file.path,
      fileName: 'fixture.apk',
      mimeType: 'application/vnd.android.package-archive',
    );

Future<File> _writeApk(
  Directory directory, {
  required bool signed,
  List<String> permissions = const <String>[],
  List<String> dexStrings = const <String>[],
  int dexCount = 1,
  List<String> nativeLibraries = const <String>[],
  Map<String, List<int>> extraEntries = const <String, List<int>>{},
}) async {
  final Map<String, List<int>> entries = <String, List<int>>{
    'AndroidManifest.xml': _manifest(permissions: permissions),
    for (int index = 0; index < dexCount; index++)
      index == 0 ? 'classes.dex' : 'classes${index + 1}.dex': _dex(
        strings: dexStrings,
      ),
    'resources.arsc': <int>[0, 1, 2, 3],
    for (final String path in nativeLibraries)
      path: <int>[0x7f, 0x45, 0x4c, 0x46],
    ...extraEntries,
  };
  if (signed) entries['META-INF/CERT.RSA'] = <int>[1, 2, 3, 4, 5];
  final File file = File(
    '${directory.path}/fixture-${signed ? 'signed' : 'unsigned'}.apk',
  );
  await file.writeAsBytes(_zip(entries));
  return file;
}

List<int> _manifest({required List<String> permissions}) {
  final List<String> strings = <String>[
    'manifest',
    'application',
    'uses-permission',
    'uses-sdk',
    'activity',
    'intent-filter',
    'package',
    'versionCode',
    'versionName',
    'minSdkVersion',
    'targetSdkVersion',
    'label',
    'debuggable',
    'allowBackup',
    'exported',
    'name',
    'com.example.sample',
    'Sample',
    '1.0',
    'com.example.MainActivity',
    ...permissions,
  ];
  final Map<String, int> index = <String, int>{
    for (int i = 0; i < strings.length; i++) strings[i]: i,
  };
  final List<List<int>> chunks = <List<int>>[
    _start('manifest', index, <_Attr>[
      _stringAttr('package', 'com.example.sample', index),
      _intAttr('versionCode', 1, index),
      _stringAttr('versionName', '1.0', index),
    ]),
  ];
  for (final String permission in permissions) {
    chunks
      ..add(
        _start('uses-permission', index, <_Attr>[
          _stringAttr('name', permission, index),
        ]),
      )
      ..add(_end('uses-permission', index));
  }
  chunks
    ..add(
      _start('uses-sdk', index, <_Attr>[
        _intAttr('minSdkVersion', 24, index),
        _intAttr('targetSdkVersion', 35, index),
      ]),
    )
    ..add(_end('uses-sdk', index))
    ..add(
      _start('application', index, <_Attr>[
        _stringAttr('label', 'Sample', index),
        _boolAttr('debuggable', false, index),
        _boolAttr('allowBackup', true, index),
      ]),
    )
    ..add(
      _start('activity', index, <_Attr>[
        _stringAttr('name', 'com.example.MainActivity', index),
        _boolAttr('exported', true, index),
      ]),
    )
    ..add(_start('intent-filter', index, const <_Attr>[]))
    ..add(_end('intent-filter', index))
    ..add(_end('activity', index))
    ..add(_end('application', index))
    ..add(_end('manifest', index));
  final List<int> pool = _stringPool(strings);
  final int total =
      8 + pool.length + chunks.fold<int>(0, (a, b) => a + b.length);
  final List<int> result = <int>[
    ..._u16(0x0003),
    ..._u16(8),
    ..._u32(total),
    ...pool,
    ...chunks.expand((chunk) => chunk),
  ];
  return result;
}

class _Attr {
  const _Attr(this.name, this.raw, this.type, this.data);
  final String name;
  final int raw;
  final int type;
  final int data;
}

_Attr _stringAttr(String name, String value, Map<String, int> index) =>
    _Attr(name, index[value]!, 0x03, index[value]!);
_Attr _intAttr(String name, int value, Map<String, int> index) =>
    _Attr(name, 0xffffffff, 0x10, value);
_Attr _boolAttr(String name, bool value, Map<String, int> index) =>
    _Attr(name, 0xffffffff, 0x12, value ? 1 : 0);

List<int> _start(String name, Map<String, int> index, List<_Attr> attrs) {
  final List<int> result = <int>[
    ..._u16(0x0102),
    ..._u16(36),
    ..._u32(36 + attrs.length * 20),
    ..._u32(1),
    ..._u32(0xffffffff),
    ..._u32(0xffffffff),
    ..._u32(index[name]!),
    ..._u16(36),
    ..._u16(20),
    ..._u16(attrs.length),
    ..._u16(0),
    ..._u16(0),
    ..._u16(0),
  ];
  for (final _Attr attr in attrs) {
    final int? nameIndex = index[attr.name];
    if (nameIndex == null) {
      throw StateError('Missing attribute name: ${attr.name}');
    }
    result.addAll(<int>[
      ..._u32(0xffffffff),
      ..._u32(nameIndex),
      ..._u32(attr.raw),
      ..._u16(8),
      0,
      attr.type,
      ..._u32(attr.data),
    ]);
  }
  return result;
}

List<int> _end(String name, Map<String, int> index) => <int>[
  ..._u16(0x0103),
  ..._u16(24),
  ..._u32(24),
  ..._u32(1),
  ..._u32(0xffffffff),
  ..._u32(0xffffffff),
  ..._u32(index[name]!),
];

List<int> _stringPool(List<String> values) {
  final List<int> data = <int>[];
  final List<int> offsets = <int>[];
  for (final String value in values) {
    offsets.add(data.length);
    final List<int> encoded = utf8.encode(value);
    data.add(encoded.length);
    data.add(encoded.length);
    data.addAll(encoded);
    data.add(0);
  }
  final int headerSize = 28;
  final int stringsStart = headerSize + offsets.length * 4;
  final int chunkSize = stringsStart + data.length;
  return <int>[
    ..._u16(0x0001),
    ..._u16(headerSize),
    ..._u32(chunkSize),
    ..._u32(values.length),
    ..._u32(0),
    ..._u32(0x100),
    ..._u32(stringsStart),
    ..._u32(0),
    ...offsets.expand(_u32),
    ...data,
  ];
}

List<int> _dex({required List<String> strings}) {
  final List<String> values = strings.isEmpty ? <String>['safe'] : strings;
  final int idsStart = 0x70;
  final int dataStart = idsStart + values.length * 4;
  final List<int> data = <int>[];
  final List<int> offsets = <int>[];
  for (final String value in values) {
    offsets.add(dataStart + data.length);
    final List<int> encoded = utf8.encode(value);
    data.add(encoded.length);
    data.addAll(encoded);
    data.add(0);
  }
  final int fileSize = dataStart + data.length;
  final List<int> result = List<int>.filled(fileSize, 0);
  result.setRange(0, 8, utf8.encode('dex\n035\u0000'));
  _setU32(result, 0x20, fileSize);
  _setU32(result, 0x24, 0x70);
  _setU32(result, 0x38, values.length);
  _setU32(result, 0x3c, idsStart);
  _setU32(result, 0x58, 1);
  _setU32(result, 0x60, 1);
  for (int i = 0; i < offsets.length; i++) {
    _setU32(result, idsStart + i * 4, offsets[i]);
  }
  result.setRange(dataStart, fileSize, data);
  return result;
}

List<int> _zip(Map<String, List<int>> entries) {
  final List<int> local = <int>[];
  final List<int> central = <int>[];
  int offset = 0;
  for (final MapEntry<String, List<int>> entry in entries.entries) {
    final List<int> name = utf8.encode(entry.key);
    final List<int> data = entry.value;
    final int crc = _crc32(data);
    final List<int> header = <int>[
      ..._u32(0x04034b50),
      ..._u16(20),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(crc),
      ..._u32(data.length),
      ..._u32(data.length),
      ..._u16(name.length),
      ..._u16(0),
      ...name,
      ...data,
    ];
    local.addAll(header);
    central.addAll(<int>[
      ..._u32(0x02014b50),
      ..._u16(20),
      ..._u16(20),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(crc),
      ..._u32(data.length),
      ..._u32(data.length),
      ..._u16(name.length),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(0),
      ..._u32(offset),
      ...name,
    ]);
    offset += header.length;
  }
  final int directoryOffset = local.length;
  return <int>[
    ...local,
    ...central,
    ..._u32(0x06054b50),
    ..._u16(0),
    ..._u16(0),
    ..._u16(entries.length),
    ..._u16(entries.length),
    ..._u32(central.length),
    ..._u32(directoryOffset),
    ..._u16(0),
  ];
}

List<int> _u16(int value) => <int>[value & 0xff, (value >> 8) & 0xff];
List<int> _u32(int value) => <int>[..._u16(value), ..._u16(value >> 16)];

void _setU32(List<int> bytes, int offset, int value) {
  final List<int> encoded = _u32(value);
  bytes.setRange(offset, offset + 4, encoded);
}

int _crc32(List<int> bytes) {
  int crc = 0xffffffff;
  for (final int byte in bytes) {
    crc ^= byte;
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
