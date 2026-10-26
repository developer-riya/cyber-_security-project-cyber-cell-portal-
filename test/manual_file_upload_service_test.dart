import 'dart:typed_data';

import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/services/manual_file_picker.dart';
import 'package:cyberuday/services/manual_file_upload_service.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/security_pipeline_config.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:cyberuday/services/web_picked_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selected Web bytes preserve filename, MIME type, size, and hash',
    () async {
      final _FakeManualFilePicker picker = _FakeManualFilePicker(
        ManualPickedFile(
          name: 'evidence.png',
          sizeBytes: 8,
          mimeType: 'image/png',
          bytes: Uint8List.fromList(const <int>[1, 2, 3, 4, 5, 6, 7, 8]),
        ),
      );
      final ManualFileUploadService service = ManualFileUploadService(
        picker: picker,
      );

      final IncomingSharePayload? payload = await service.pickFiles();
      final IncomingShareAttachment attachment = payload!.attachments.single;

      expect(picker.calls, 1);
      expect(picker.lastApkOnly, isFalse);
      expect(attachment.fileName, 'evidence.png');
      expect(attachment.mimeType, 'image/png');
      expect(attachment.sizeBytes, 8);
      expect(attachment.sha256, hasLength(64));
      expect(attachment.uri, startsWith('web-memory://'));
      expect(WebPickedFileStore.contains(attachment.uri), isTrue);

      service.releasePayload(payload);
      expect(WebPickedFileStore.contains(attachment.uri), isFalse);
    },
  );

  test('APK selection preserves the APK request and MIME metadata', () async {
    final _FakeManualFilePicker picker = _FakeManualFilePicker(
      ManualPickedFile(
        name: 'update.apk',
        sizeBytes: 4,
        mimeType: 'application/vnd.android.package-archive',
        bytes: Uint8List.fromList(const <int>[0x50, 0x4b, 0x03, 0x04]),
      ),
    );
    final ManualFileUploadService service = ManualFileUploadService(
      picker: picker,
    );

    final IncomingSharePayload? payload = await service.pickFiles(
      apkOnly: true,
    );

    expect(picker.lastApkOnly, isTrue);
    expect(payload!.primaryType, IncomingShareContentType.apk);
    expect(
      payload.attachments.single.mimeType,
      'application/vnd.android.package-archive',
    );
    service.releasePayload(payload);
  });

  test('cancel returns to the scanner without creating a payload', () async {
    final _FakeManualFilePicker picker = _FakeManualFilePicker(null);
    final ManualFileUploadService service = ManualFileUploadService(
      picker: picker,
    );

    expect(await service.pickFiles(), isNull);
    expect(picker.calls, 1);
  });

  test(
    'oversized browser file is rejected before bytes are retained',
    () async {
      const SecurityPipelineConfig config = SecurityPipelineConfig();
      final _FakeManualFilePicker picker = _FakeManualFilePicker(
        const ManualPickedFile(
          name: 'oversized.zip',
          sizeBytes: 25 * 1024 * 1024 + 1,
          mimeType: 'application/zip',
        ),
      );
      final ManualFileUploadService service = ManualFileUploadService(
        picker: picker,
        pipelineConfig: config,
      );

      expect(
        service.pickFiles,
        throwsA(
          isA<ManualFilePickerException>().having(
            (ManualFilePickerException error) => error.message,
            'message',
            contains('25 MB'),
          ),
        ),
      );
    },
  );

  test('selected bytes reach the existing threat-analysis boundary', () async {
    final _FakeManualFilePicker picker = _FakeManualFilePicker(
      ManualPickedFile(
        name: 'note.txt',
        sizeBytes: 5,
        mimeType: 'text/plain',
        bytes: Uint8List.fromList(const <int>[104, 101, 108, 108, 111]),
      ),
    );
    final ManualFileUploadService service = ManualFileUploadService(
      picker: picker,
    );
    final IncomingSharePayload payload = (await service.pickFiles())!;
    final _CapturingQuarantineStorage storage = _CapturingQuarantineStorage();
    final ThreatAnalysisEngine engine = ThreatAnalysisEngine(
      quarantineStorage: storage,
      analysisExecutor: (_) async => const ShareThreatAnalysis(
        risk: ShareThreatRisk.unsupported,
        status: ShareAnalysisStatus.analysisUnavailable,
        title: 'Static analysis unavailable',
        message: 'No safe verdict was assigned.',
        indicators: <String>[],
        recommendations: <String>['Keep the item closed.'],
        analyzerName: 'Existing analysis boundary',
      ),
    );

    final ThreatAnalysisRun run = await engine.analyze(payload);

    expect(
      storage.storedRequest?.references.single,
      startsWith('web-memory://'),
    );
    expect(storage.deleted, isTrue);
    expect(run.result.verdict, ThreatVerdict.unknown);
    service.releasePayload(payload);
  });
}

class _FakeManualFilePicker implements ManualFilePicker {
  _FakeManualFilePicker(this.result);

  final ManualPickedFile? result;
  int calls = 0;
  bool? lastApkOnly;

  @override
  Future<ManualPickedFile?> pickFile({
    required bool apkOnly,
    required int maxBytes,
  }) async {
    calls++;
    lastApkOnly = apkOnly;
    return result;
  }
}

class _CapturingQuarantineStorage implements QuarantineStorage {
  ThreatAnalysisRequest? storedRequest;
  bool deleted = false;
  QuarantineRecord? _record;

  @override
  Future<QuarantineRecord> store(
    ThreatAnalysisRequest request, {
    required DateTime expiresAt,
  }) async {
    storedRequest = request;
    _record = QuarantineRecord(
      requestId: request.requestId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      metadata: const <String, Object?>{'temporaryContent': true},
    );
    return _record!;
  }

  @override
  Future<void> delete(String requestId) async {
    deleted = true;
    _record = null;
  }

  @override
  Future<bool> exists(String requestId) async => _record != null;

  @override
  Future<QuarantineRecord?> get(String requestId) async => _record;
}
