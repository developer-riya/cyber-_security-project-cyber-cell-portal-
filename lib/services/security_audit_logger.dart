enum SecurityAuditEventType {
  analysisRequested,
  uploadReceived,
  validationFailed,
  quarantined,
  hashGenerated,
  analyzerStarted,
  analyzerCompleted,
  analyzerFailed,
  timeout,
  threatIntelligenceLookup,
  threatIntelligenceLookupStarted,
  threatIntelligenceLookupCompleted,
  threatIntelligenceNotConfigured,
  threatIntelligenceTimeout,
  threatIntelligenceError,
  threatIntelligenceCacheHit,
  verdictGenerated,
  resultDelivered,
  quarantineCleanup,
}

class SecurityAuditEvent {
  const SecurityAuditEvent({
    required this.type,
    required this.requestId,
    required this.createdAt,
    this.metadata = const <String, Object?>{},
  });

  final SecurityAuditEventType type;
  final String requestId;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}

abstract interface class SecurityAuditLogger {
  void record(SecurityAuditEvent event);
}

class NoOpSecurityAuditLogger implements SecurityAuditLogger {
  const NoOpSecurityAuditLogger();

  @override
  void record(SecurityAuditEvent event) {}
}

class InMemorySecurityAuditLogger implements SecurityAuditLogger {
  final List<SecurityAuditEvent> events = <SecurityAuditEvent>[];

  @override
  void record(SecurityAuditEvent event) => events.add(event);
}
