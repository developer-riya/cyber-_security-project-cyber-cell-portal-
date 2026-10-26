import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../core/localization/app_localizations_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/localization_service.dart';

class DemoDashboardScreen extends StatelessWidget {
  const DemoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = CyberTheme.lightTheme;

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.currentLocale,
      builder: (context, localeCode, _) {
        final AppLocalizations localizations = appLocalizationsFor(localeCode);
        return Theme(
          data: theme,
          child: Scaffold(
            appBar: AppBar(
              title: Text(localizations.authDemoTitle),
              leading: BackButton(onPressed: () => Navigator.of(context).pop()),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: CyberSpacing.pagePadding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: CyberDimensions.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CyberCard(
                          variant: CyberCardVariant.status,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: theme.colorScheme.secondary,
                              ),
                              CyberSpacing.horizontal(CyberSpacing.sm),
                              Expanded(
                                child: Text(
                                  localizations.authDemoDescription,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CyberSpacing.vertical(CyberSpacing.xl),
                        Text(
                          'CYBER UDAY',
                          style: theme.textTheme.headlineMedium,
                        ),
                        CyberSpacing.vertical(CyberSpacing.xs),
                        Text(
                          localizations.authSignInIntro,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                        CyberSpacing.vertical(CyberSpacing.lg),
                        Wrap(
                          spacing: CyberSpacing.md,
                          runSpacing: CyberSpacing.md,
                          children: [
                            _DemoMetric(
                              icon: Icons.shield_outlined,
                              label: localizations.authDemoProtectionLabel,
                              value: localizations.authDemoProtectionValue,
                            ),
                            _DemoMetric(
                              icon: Icons.travel_explore_outlined,
                              label: localizations.authDemoThreatLabel,
                              value: localizations.authDemoThreatValue,
                            ),
                            _DemoMetric(
                              icon: Icons.notifications_none_rounded,
                              label: localizations.authDemoAlertsLabel,
                              value: localizations.authDemoAlertsValue,
                            ),
                          ],
                        ),
                        CyberSpacing.vertical(CyberSpacing.xl),
                        CyberButton(
                          label: localizations.authDemoExit,
                          variant: CyberButtonVariant.secondary,
                          icon: const Icon(Icons.arrow_back_rounded),
                          expand: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DemoMetric extends StatelessWidget {
  const _DemoMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 250,
      child: CyberCard(
        variant: CyberCardVariant.standard,
        padding: CyberSpacing.compactCardPadding,
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.secondary),
            CyberSpacing.horizontal(CyberSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  CyberSpacing.vertical(CyberSpacing.xxs),
                  Text(value, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
