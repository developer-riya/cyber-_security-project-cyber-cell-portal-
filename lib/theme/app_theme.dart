import 'package:flutter/material.dart';

import '../core/theme/cyber_theme.dart';

/// Compatibility facade for existing imports.
///
/// The product theme is owned by [CyberTheme]; keeping this facade avoids
/// breaking older screens while the app migrates to the shared system.
class AppTheme {
  static ThemeData get lightTheme => CyberTheme.lightTheme;
}
