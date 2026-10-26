import 'package:flutter/foundation.dart';

/// Development preview access is opt-in and can never be enabled in release.
const bool cyberUdayDevelopmentAccessEnabled =
    kDebugMode &&
    bool.fromEnvironment('CYBER_UDAY_DEMO_ACCESS', defaultValue: false);
