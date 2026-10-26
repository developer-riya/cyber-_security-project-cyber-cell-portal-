import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/incoming_share_payload.dart';

/// Receives only content that a person explicitly shares with Cyber Uday.
///
/// Android supplies transient content URIs. This service keeps metadata only;
/// it never opens, copies, executes, or uploads an attachment by itself.
/// A future iOS Share Extension can publish the same normalized payload through
/// this boundary without changing the Threat Scanner UI.
class IncomingShareService {
  IncomingShareService({EventChannel? channel})
    : _channel = channel ?? const EventChannel(_channelName);

  static const String _channelName = 'cyberuday/incoming_share';
  static final IncomingShareService instance = IncomingShareService();

  final EventChannel _channel;
  final StreamController<IncomingSharePayload> _liveShares =
      StreamController<IncomingSharePayload>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  IncomingSharePayload? _launchPayload;
  bool _initialized = false;
  bool _liveRoutingEnabled = false;

  Stream<IncomingSharePayload> get liveShares => _liveShares.stream;

  Future<void> initialize() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _initialized = true;
    _subscription = _channel.receiveBroadcastStream().listen(
      _receivePlatformPayload,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Incoming share channel failed: ${error.runtimeType}');
      },
    );
  }

  IncomingSharePayload? takeLaunchPayload() {
    final IncomingSharePayload? payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  void enableLiveRouting() {
    _liveRoutingEnabled = true;
  }

  @visibleForTesting
  void receivePlatformPayloadForTesting(Map<Object?, Object?> payload) {
    _receivePlatformPayload(payload);
  }

  void _receivePlatformPayload(dynamic rawPayload) {
    if (rawPayload is! Map<Object?, Object?>) return;
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      rawPayload,
    );
    if (_liveRoutingEnabled) {
      _liveShares.add(payload);
      return;
    }
    _launchPayload = payload;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _liveShares.close();
  }
}
