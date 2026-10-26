import 'package:flutter/material.dart';

/// Semantic colors shared by the future Cyber Uday UI.
abstract final class CyberColors {
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F3F5);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFD1D5DB);
  static const Color borderStrong = Color(0xFF9CA3AF);
  static const Color primary = Color(0xFF111827);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color brandAccent = Color(0xFF0F766E);
  static const Color onBrandAccent = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF176B3A);
  static const Color successContainer = Color(0xFFE7F5EC);
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningContainer = Color(0xFFFFF4D6);
  static const Color danger = Color(0xFFB42318);
  static const Color dangerContainer = Color(0xFFFEECEB);
  static const Color info = Color(0xFF155EEF);
  static const Color infoContainer = Color(0xFFEFF4FF);
  static const Color disabled = Color(0xFFE5E7EB);
  static const Color textDisabled = Color(0xFF9CA3AF);
}

abstract final class CyberSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 40;
  static const double page = 48;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xl,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(md);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: sm,
  );
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static SizedBox vertical(double value) => SizedBox(height: value);
  static SizedBox horizontal(double value) => SizedBox(width: value);
}

abstract final class CyberRadius {
  static const double small = 4;
  static const double standard = 8;
  static const double large = 12;
  static const double extraLarge = 16;
  static const double pill = 999;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius standardRadius = BorderRadius.all(
    Radius.circular(standard),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract final class CyberElevation {
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

abstract final class CyberMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 180);
  static const Curve standardCurve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration normal) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
  }
}

abstract final class CyberDimensions {
  static const double controlHeight = 44;
  static const double fieldHeight = 48;
  static const double iconButtonSize = 44;
  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double maxContentWidth = 1200;
}

enum CyberWindowSize { compact, medium, expanded }

abstract final class CyberBreakpoints {
  static const double compactMax = 599;
  static const double mediumMax = 1023;

  static CyberWindowSize fromWidth(double width) {
    if (width <= compactMax) return CyberWindowSize.compact;
    if (width <= mediumMax) return CyberWindowSize.medium;
    return CyberWindowSize.expanded;
  }
}

extension CyberResponsiveContext on BuildContext {
  double get cyberWidth => MediaQuery.sizeOf(this).width;

  CyberWindowSize get cyberWindowSize => CyberBreakpoints.fromWidth(cyberWidth);

  bool get isCyberCompact => cyberWindowSize == CyberWindowSize.compact;
}
