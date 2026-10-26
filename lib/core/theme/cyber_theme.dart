import 'package:flutter/material.dart';

import 'cyber_tokens.dart';

abstract final class CyberTypography {
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      height: 1.1,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.25,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, height: 1.4),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
  );
}

abstract final class CyberTheme {
  static ThemeData get lightTheme => _buildTheme(
    ColorScheme.fromSeed(
      seedColor: CyberColors.brandAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: CyberColors.primary,
      onPrimary: CyberColors.onPrimary,
      secondary: CyberColors.brandAccent,
      onSecondary: CyberColors.onBrandAccent,
      surface: CyberColors.surface,
      onSurface: CyberColors.textPrimary,
      error: CyberColors.danger,
      onError: CyberColors.textOnDark,
      outline: CyberColors.border,
      surfaceContainerHighest: CyberColors.surfaceSubtle,
    ),
  );

  static ThemeData _buildTheme(ColorScheme scheme) {
    final TextTheme textTheme = CyberTypography.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: CyberRadius.standardRadius,
      borderSide: BorderSide(color: scheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: CyberColors.background,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: CyberRadius.standardRadius,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, CyberDimensions.controlHeight),
          padding: CyberSpacing.buttonPadding,
          shape: const RoundedRectangleBorder(
            borderRadius: CyberRadius.standardRadius,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, CyberDimensions.controlHeight),
          padding: CyberSpacing.buttonPadding,
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(
            borderRadius: CyberRadius.standardRadius,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          minimumSize: const Size(0, CyberDimensions.controlHeight),
          padding: CyberSpacing.buttonPadding,
          shape: const RoundedRectangleBorder(
            borderRadius: CyberRadius.standardRadius,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberColors.surface,
        contentPadding: CyberSpacing.fieldPadding,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.secondary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72)),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.58)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(CyberDimensions.iconButtonSize),
          foregroundColor: scheme.onSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: CyberRadius.standardRadius,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: CyberRadius.standardRadius,
        ),
      ),
    );
  }
}
