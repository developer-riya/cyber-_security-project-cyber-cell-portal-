import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CyberLayout extends StatelessWidget {
  const CyberLayout({
    super.key,
    required this.heroTag,
    required this.title,
    required this.subtitle,
    required this.panel,
    this.sideNote,
  });

  final String heroTag;
  final String title;
  final String subtitle;
  final Widget panel;
  final Widget? sideNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _CyberBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 980;
                final bool androidCompact =
                    !kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android &&
                    constraints.maxWidth < 720;

                if (androidCompact) {
                  return _AndroidCompactLayout(
                    heroTag: heroTag,
                    title: title,
                    subtitle: subtitle,
                    panel: panel,
                    sideNote: sideNote,
                  );
                }

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 20 : 32,
                        vertical: compact ? 18 : 28,
                      ),
                      child: compact
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _HeroBlock(
                                  heroTag: heroTag,
                                  title: title,
                                  subtitle: subtitle,
                                ),
                                const SizedBox(height: 20),
                                _PanelCard(child: panel),
                                if (sideNote != null) ...[
                                  const SizedBox(height: 16),
                                  sideNote!,
                                ],
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 28),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _HeroBlock(
                                          heroTag: heroTag,
                                          title: title,
                                          subtitle: subtitle,
                                          alignStart: true,
                                        ),
                                        if (sideNote != null) ...[
                                          const SizedBox(height: 20),
                                          sideNote!,
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 470,
                                  ),
                                  child: _PanelCard(child: panel),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 28,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF1E4A67)),
                color: const Color(0xFF091520).withValues(alpha: 0.78),
              ),
              child: Text(
                'THREAT LEVEL: GUARDED',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF3FFFD7),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AndroidCompactLayout extends StatelessWidget {
  const _AndroidCompactLayout({
    required this.heroTag,
    required this.title,
    required this.subtitle,
    required this.panel,
    this.sideNote,
  });

  final String heroTag;
  final String title;
  final String subtitle;
  final Widget panel;
  final Widget? sideNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E4A67)),
                color: const Color(0xFF091520).withValues(alpha: 0.84),
              ),
              child: Text(
                'THREAT LEVEL: GUARDED',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF3FFFD7),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3FFFD7), Color(0xFF5AB2FF)],
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_moon_rounded,
                    color: Color(0xFF07111A),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heroTag,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF3FFFD7),
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(title, style: theme.textTheme.headlineMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB6C9D9),
              ),
            ),
            const SizedBox(height: 18),
            _PanelCard(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: panel,
              ),
            ),
            if (sideNote != null) ...[const SizedBox(height: 14), sideNote!],
          ],
        ),
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.heroTag,
    required this.title,
    required this.subtitle,
    this.alignStart = false,
  });

  final String heroTag;
  final String title;
  final String subtitle;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF3FFFD7), Color(0xFF5AB2FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x663FFFD7),
                blurRadius: 32,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_moon_rounded,
            color: Color(0xFF07111A),
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          heroTag,
          style: theme.textTheme.labelLarge?.copyWith(
            color: const Color(0xFF3FFFD7),
            letterSpacing: 2.4,
          ),
          textAlign: alignStart ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.headlineLarge,
          textAlign: alignStart ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFB6C9D9),
            ),
            textAlign: alignStart ? TextAlign.start : TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1823).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF1E4A67)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CyberBackdrop extends StatelessWidget {
  const _CyberBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040B11), Color(0xFF07111A), Color(0xFF0B2030)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowOrb(
              size: 280,
              color: const Color(0xFF3FFFD7).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -30,
            child: _GlowOrb(
              size: 340,
              color: const Color(0xFF5AB2FF).withValues(alpha: 0.14),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 90, spreadRadius: 26),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF1A3B53).withValues(alpha: 0.32)
      ..strokeWidth = 1;

    const double gap = 36;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
