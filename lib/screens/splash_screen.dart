import 'dart:async';

import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../models/incoming_share_payload.dart';
import '../services/incoming_share_service.dart';
import '../services/launch_flow_service.dart';
import '../services/localization_service.dart';
import 'auth_gate.dart';
import 'language_selection_screen.dart';
import 'share_to_scan_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _timer = Timer(const Duration(milliseconds: 2200), _continueFromSplash);
  }

  Future<void> _continueFromSplash() async {
    final IncomingSharePayload? sharedPayload = IncomingShareService.instance
        .takeLaunchPayload();
    final LaunchDestination? destination = sharedPayload == null
        ? await LaunchFlowService.instance.resolve()
        : null;
    if (!mounted) return;

    final Widget nextScreen = sharedPayload != null
        ? ShareToScanScreen(payload: sharedPayload)
        : destination == LaunchDestination.languageSelection
        ? const LanguageSelectionScreen()
        : const AuthGate();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IncomingShareService.instance.enableLiveRouting();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion == _reduceMotion) {
      return;
    }

    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CyberTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CyberColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final CyberWindowSize windowSize = CyberBreakpoints.fromWidth(
                constraints.maxWidth,
              );
              final bool compact = windowSize == CyberWindowSize.compact;
              final double logoSize = compact ? 112 : 148;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact
                            ? CyberSpacing.md
                            : CyberSpacing.xxl,
                        vertical: CyberSpacing.xl,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LogoMark(
                              size: logoSize,
                              animate: !_reduceMotion,
                              pulse: _pulse,
                            ),
                            CyberSpacing.vertical(
                              compact ? CyberSpacing.xl : CyberSpacing.xxl,
                            ),
                            Text(
                              'CYBER UDAY',
                              style: Theme.of(context).textTheme.headlineLarge,
                              textAlign: TextAlign.center,
                            ),
                            CyberSpacing.vertical(CyberSpacing.xs),
                            Text(
                              LocalizationService.instance.translate(
                                'brand_bodyguard',
                              ),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: CyberColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            CyberSpacing.vertical(CyberSpacing.section),
                            Semantics(
                              label: LocalizationService.instance.translate(
                                'splash_preparing',
                              ),
                              child: SizedBox(
                                width: compact ? 180 : 220,
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  borderRadius: CyberRadius.pillRadius,
                                  backgroundColor: CyberColors.disabled,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        CyberColors.brandAccent,
                                      ),
                                ),
                              ),
                            ),
                            CyberSpacing.vertical(CyberSpacing.sm),
                            Text(
                              LocalizationService.instance.translate(
                                'splash_workspace',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: CyberColors.textTertiary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.size,
    required this.animate,
    required this.pulse,
  });

  final double size;
  final bool animate;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final Widget mark = Semantics(
      image: true,
      label: LocalizationService.instance.translate('profile_avatar_label'),
      child: Image.asset(
        'assets/cyber_uday_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );

    if (!animate) {
      return mark;
    }

    return ScaleTransition(
      scale: Tween<double>(begin: 0.985, end: 1.015).animate(pulse),
      child: mark,
    );
  }
}
