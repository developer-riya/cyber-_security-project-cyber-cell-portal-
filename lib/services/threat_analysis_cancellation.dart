import 'dart:async';

/// Cooperative cancellation boundary for first-pass orchestration.
///
/// It cannot preempt synchronous CPU work. Deep analysis needs isolated workers
/// before hard cancellation can be supported.
class ThreatAnalysisCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}
