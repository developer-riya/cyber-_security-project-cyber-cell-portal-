import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  AppCheckService._();

  static final AppCheckService instance = AppCheckService._();

  static const bool _enabled = bool.fromEnvironment(
    'CYBER_UDAY_APP_CHECK_ENABLED',
    defaultValue: false,
  );
  static const String _webSiteKey = String.fromEnvironment(
    'CYBER_UDAY_APP_CHECK_WEB_SITE_KEY',
  );

  bool _active = false;

  bool get isActive => _active;

  Future<void> initialize() async {
    if (!_enabled) return;
    if (kIsWeb && _webSiteKey.trim().isEmpty) return;
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: kIsWeb ? ReCaptchaV3Provider(_webSiteKey.trim()) : null,
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      _active = true;
    } catch (error) {
      debugPrint(
        'Firebase App Check initialization failed: ${error.runtimeType}',
      );
    }
  }

  Future<String?> token() async {
    if (!_active) return null;
    try {
      return await FirebaseAppCheck.instance.getLimitedUseToken();
    } catch (_) {
      return null;
    }
  }
}
