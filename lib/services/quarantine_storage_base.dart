import '../models/threat_analysis.dart';

class QuarantinedContent {
  const QuarantinedContent({
    required this.attachmentIndex,
    required this.reference,
    required this.sizeBytes,
    this.sha256,
  });

  final int attachmentIndex;
  final String reference;
  final int sizeBytes;
  final String? sha256;
}

class QuarantineRecord {
  const QuarantineRecord({
    required this.requestId,
    required this.createdAt,
    required this.expiresAt,
    required this.metadata,
    this.directoryReference,
    this.contents = const <QuarantinedContent>[],
  });

  final String requestId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, Object?> metadata;
  final String? directoryReference;
  final List<QuarantinedContent> contents;
}

/// Storage boundary for temporary untrusted-content quarantine.
///
/// This is not an execution sandbox. Production must replace the development
/// implementation with isolated backend/object storage before deeper analysis.
abstract interface class QuarantineStorage {
  Future<QuarantineRecord> store(
    ThreatAnalysisRequest request, {
    required DateTime expiresAt,
  });

  Future<QuarantineRecord?> get(String requestId);

  Future<bool> exists(String requestId);

  Future<void> delete(String requestId);
}

/// Metadata-only test double. It intentionally never handles file bytes.
class InMemoryQuarantineStorage implements QuarantineStorage {
  const InMemoryQuarantineStorage();

  static final Map<String, QuarantineRecord> _records =
      <String, QuarantineRecord>{};

  @override
  Future<QuarantineRecord> store(
    ThreatAnalysisRequest request, {
    required DateTime expiresAt,
  }) async {
    final QuarantineRecord record = QuarantineRecord(
      requestId: request.requestId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      metadata: <String, Object?>{
        'inputType': request.inputType.name,
        'attachmentCount': request.references.length,
      },
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
    _records.remove(requestId);
  }
}
