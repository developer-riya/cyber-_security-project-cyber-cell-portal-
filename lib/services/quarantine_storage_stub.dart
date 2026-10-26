import '../models/threat_analysis.dart';
import 'quarantine_storage_base.dart';
import 'web_picked_file_store.dart';

/// Web quarantine keeps explicitly selected bytes in application memory only.
/// Static analyzers that require a native filesystem remain inconclusive.
class TemporaryQuarantineStorage implements QuarantineStorage {
  const TemporaryQuarantineStorage();

  static final Map<String, QuarantineRecord> _records =
      <String, QuarantineRecord>{};

  @override
  Future<QuarantineRecord> store(
    ThreatAnalysisRequest request, {
    required DateTime expiresAt,
  }) async {
    final List<QuarantinedContent> contents = <QuarantinedContent>[];
    for (int index = 0; index < request.references.length; index++) {
      final WebPickedFileContent? content = WebPickedFileStore.read(
        request.references[index],
      );
      if (content == null) continue;
      contents.add(
        QuarantinedContent(
          attachmentIndex: index,
          reference: content.reference,
          sizeBytes: content.bytes.length,
          sha256: content.sha256,
        ),
      );
    }
    final QuarantineRecord record = QuarantineRecord(
      requestId: request.requestId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      metadata: <String, Object?>{
        'inputType': request.inputType.name,
        'attachmentCount': request.references.length,
        'temporaryContent': contents.isNotEmpty,
      },
      contents: List<QuarantinedContent>.unmodifiable(contents),
    );
    _records[request.requestId] = record;
    return record;
  }

  @override
  Future<QuarantineRecord?> get(String requestId) async => _records[requestId];

  @override
  Future<bool> exists(String requestId) async =>
      _records.containsKey(requestId);

  @override
  Future<void> delete(String requestId) async {
    final QuarantineRecord? record = _records.remove(requestId);
    for (final QuarantinedContent content
        in record?.contents ?? const <QuarantinedContent>[]) {
      WebPickedFileStore.release(content.reference);
    }
  }
}
