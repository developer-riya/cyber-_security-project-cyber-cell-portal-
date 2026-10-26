import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../core/localization/app_localizations_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/localization_service.dart';
import '../services/onboarding_preference_service.dart';
import 'auth_gate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.destinationBuilder});

  /// Used by widget tests to observe the navigation boundary without changing
  /// the production destination, which remains [AuthGate].
  final WidgetBuilder? destinationBuilder;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 3;

  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToNextPage() async {
    if (_pageIndex == _pageCount - 1 || _isCompleting) {
      await _completeOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await OnboardingPreferenceService.instance.markComplete();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.destinationBuilder?.call(context) ?? const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _skip() => _completeOnboarding();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.currentLocale,
      builder: (BuildContext context, String localeCode, Widget? child) {
        final AppLocalizations localizations = appLocalizationsFor(localeCode);
        return Theme(
          data: CyberTheme.lightTheme,
          child: Scaffold(
            backgroundColor: CyberColors.background,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact =
                      CyberBreakpoints.fromWidth(constraints.maxWidth) ==
                      CyberWindowSize.compact;
                  final bool reduceMotion =
                      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                  final bool shortViewport = constraints.maxHeight < 700;
                  final double pageViewportHeight = shortViewport
                      ? (compact ? 360 : 390)
                      : (compact ? 500 : 520);
                  final List<_OnboardingPageData> pages = _pages(localizations);

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact
                                ? CyberSpacing.md
                                : CyberSpacing.xxl,
                            vertical: CyberSpacing.md,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: CyberDimensions.controlHeight,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _pageIndex < _pageCount - 1
                                        ? CyberButton(
                                            label: localizations.onboardingSkip,
                                            variant:
                                                CyberButtonVariant.tertiary,
                                            onPressed: _isCompleting
                                                ? null
                                                : _skip,
                                            semanticLabel:
                                                localizations.onboardingSkip,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                Text(
                                  localizations.onboardingBrandLine,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: CyberColors.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                CyberSpacing.vertical(CyberSpacing.sm),
                                SizedBox(
                                  height: pageViewportHeight,
                                  child: PageView.builder(
                                    controller: _pageController,
                                    itemCount: pages.length,
                                    onPageChanged: (int index) =>
                                        setState(() => _pageIndex = index),
                                    itemBuilder: (context, index) {
                                      final _OnboardingPageData page =
                                          pages[index];
                                      return _OnboardingPage(
                                        page: page,
                                        compact: compact,
                                      );
                                    },
                                  ),
                                ),
                                Semantics(
                                  liveRegion: true,
                                  label: localizations.onboardingPageIndicator(
                                    _pageIndex + 1,
                                    _pageCount,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List<Widget>.generate(
                                      _pageCount,
                                      (int index) => AnimatedContainer(
                                        duration: reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        width: index == _pageIndex ? 28 : 8,
                                        height: 8,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: CyberSpacing.xxs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: index == _pageIndex
                                              ? CyberColors.brandAccent
                                              : CyberColors.disabled,
                                          borderRadius: CyberRadius.pillRadius,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                CyberSpacing.vertical(CyberSpacing.xl),
                                CyberButton(
                                  label: _pageIndex == _pageCount - 1
                                      ? localizations.onboardingGetStarted
                                      : localizations.onboardingContinue,
                                  onPressed: _isCompleting
                                      ? null
                                      : _goToNextPage,
                                  isLoading: _isCompleting,
                                  expand: true,
                                  icon: Icon(
                                    _pageIndex == _pageCount - 1
                                        ? Icons.arrow_forward_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                                  semanticLabel: _pageIndex == _pageCount - 1
                                      ? localizations.onboardingGetStarted
                                      : localizations.onboardingContinue,
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
      },
    );
  }

  List<_OnboardingPageData> _pages(AppLocalizations localizations) {
    return <_OnboardingPageData>[
      _OnboardingPageData(
        title: localizations.onboardingPage1Title,
        description: localizations.onboardingPage1Description,
        visualLabel: localizations.onboardingPage1VisualLabel,
        visualType: _OnboardingVisualType.mark,
      ),
      _OnboardingPageData(
        title: localizations.onboardingPage2Title,
        description: localizations.onboardingPage2Description,
        visualLabel: localizations.onboardingPage2VisualLabel,
        visualType: _OnboardingVisualType.detect,
      ),
      _OnboardingPageData(
        title: localizations.onboardingPage3Title,
        description: localizations.onboardingPage3Description,
        visualLabel: localizations.onboardingPage3VisualLabel,
        visualType: _OnboardingVisualType.protect,
      ),
    ];
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.visualLabel,
    required this.visualType,
  });

  final String title;
  final String description;
  final String visualLabel;
  final _OnboardingVisualType visualType;
}

enum _OnboardingVisualType { mark, detect, protect }

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page, required this.compact});

  final _OnboardingPageData page;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: CyberSpacing.xs),
      child: Column(
        children: [
          _OnboardingVisual(
            type: page.visualType,
            label: page.visualLabel,
            compact: compact,
          ),
          CyberSpacing.vertical(compact ? CyberSpacing.xl : CyberSpacing.xxl),
          Text(
            page.title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          CyberSpacing.vertical(CyberSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 590),
            child: Text(
              page.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: CyberColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({
    required this.type,
    required this.label,
    required this.compact,
  });

  final _OnboardingVisualType type;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: Container(
        width: double.infinity,
        height: compact ? 190 : 220,
        decoration: BoxDecoration(
          color: CyberColors.surface,
          borderRadius: CyberRadius.largeRadius,
          border: Border.all(color: CyberColors.border),
          boxShadow: CyberElevation.subtle,
        ),
        child: switch (type) {
          _OnboardingVisualType.mark => const _MarkVisual(),
          _OnboardingVisualType.detect => const _DetectVisual(),
          _OnboardingVisualType.protect => const _ProtectVisual(),
        },
      ),
    );
  }
}

class _MarkVisual extends StatelessWidget {
  const _MarkVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/cyber_uday_mark.png',
        width: 128,
        height: 128,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _DetectVisual extends StatelessWidget {
  const _DetectVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _VisualTile(icon: Icons.link_rounded),
          SizedBox(width: CyberSpacing.sm),
          _VisualTile(icon: Icons.chat_bubble_outline_rounded),
          SizedBox(width: CyberSpacing.sm),
          _VisualTile(icon: Icons.report_outlined),
        ],
      ),
    );
  }
}

class _ProtectVisual extends StatelessWidget {
  const _ProtectVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: CyberSpacing.md,
        runSpacing: CyberSpacing.md,
        children: const [
          _VisualTile(icon: Icons.person_outline_rounded),
          _VisualTile(icon: Icons.family_restroom_rounded),
          _VisualTile(icon: Icons.business_center_outlined),
          _VisualTile(icon: Icons.account_balance_wallet_outlined),
        ],
      ),
    );
  }
}

class _VisualTile extends StatelessWidget {
  const _VisualTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: CyberColors.surfaceSubtle,
        borderRadius: CyberRadius.largeRadius,
        border: Border.all(color: CyberColors.border),
      ),
      child: Icon(icon, color: CyberColors.brandAccent),
    );
  }
}
