import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/cyber_design_system.dart';
import '../../../services/firebase_service.dart';
import '../../../services/hacker_news_service.dart';
import '../../../services/localization_service.dart';
import '../widgets/cyber_news_preview.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.onNavigate,
    this.onDevelopersTap,
    this.latestNewsFuture,
  });

  final User? user;
  final ValueChanged<int> onNavigate;
  final VoidCallback? onDevelopersTap;
  final Future<List<HackerNewsStory>>? latestNewsFuture;

  @override
  Widget build(BuildContext context) {
    final ThemeData productTheme = CyberTheme.lightTheme;
    return Theme(
      data: productTheme,
      child: Builder(
        builder: (context) {
          final String name = _displayName(user);
          final String greeting = LocalizationService.instance.translate(
            'dashboard_greeting',
          );

          return ListView(
            padding: CyberSpacing.pagePadding,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: CyberDimensions.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $name',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    CyberSpacing.vertical(CyberSpacing.xs),
                    Text(
                      LocalizationService.instance.translate('dashboard_intro'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    CyberSpacing.vertical(CyberSpacing.xl),
                    const _ProtectionOverview(),
                    CyberSpacing.vertical(CyberSpacing.section),
                    _SectionHeading(
                      title: LocalizationService.instance.translate(
                        'dashboard_quick_actions',
                      ),
                      subtitle: LocalizationService.instance.translate(
                        'dashboard_quick_actions_subtitle',
                      ),
                    ),
                    CyberSpacing.vertical(CyberSpacing.md),
                    _QuickActions(onNavigate: onNavigate),
                    CyberSpacing.vertical(CyberSpacing.xl),
                    _EmergencyAction(
                      onPressed: () => _confirmEmergency(context),
                    ),
                    CyberSpacing.vertical(CyberSpacing.xl),
                    _SectionHeading(
                      title: LocalizationService.instance.translate(
                        'dashboard_activity_title',
                      ),
                      subtitle: LocalizationService.instance.translate(
                        'dashboard_activity_subtitle',
                      ),
                    ),
                    CyberSpacing.vertical(CyberSpacing.md),
                    const _EmptyActivityCard(),
                    CyberSpacing.vertical(CyberSpacing.xl),
                    _BankSecurityTeaser(onTap: () => onNavigate(4)),
                    CyberSpacing.vertical(CyberSpacing.xl),
                    CyberNewsPreview(
                      onViewAll: () => onNavigate(5),
                      storiesFuture: latestNewsFuture,
                    ),
                    CyberSpacing.vertical(CyberSpacing.xl),
                    _SectionHeading(
                      title: LocalizationService.instance.translate(
                        'dashboard_services_title',
                      ),
                      subtitle: LocalizationService.instance.translate(
                        'dashboard_services_subtitle',
                      ),
                    ),
                    CyberSpacing.vertical(CyberSpacing.md),
                    _AdditionalServices(
                      onNavigate: onNavigate,
                      onDevelopersTap: onDevelopersTap,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmEmergency(BuildContext context) async {
    final String platform = Theme.of(context).platform.toString();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocalizationService.instance.translate('hacked_title')),
        content: Text(LocalizationService.instance.translate('hacked_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocalizationService.instance.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(LocalizationService.instance.translate('hacked_btn')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseService.instance.logEmergencyAction('I AM HACKED', {
        'platform': platform,
        'context': 'Citizen Dashboard Emergency Action',
        'isEmergency': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate(
                'dashboard_emergency_logged',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('dashboard_action_failed'),
            ),
          ),
        );
      }
    }
  }

  static String _displayName(User? user) {
    final String? displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final String? email = user?.email?.trim();
    if (email == null || email.isEmpty) return 'there';
    return email.split('@').first;
  }
}

class _ProtectionOverview extends StatelessWidget {
  const _ProtectionOverview();

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      variant: CyberCardVariant.status,
      padding: const EdgeInsets.all(CyberSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 620;
          final Widget copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationService.instance.translate(
                  'dashboard_protection_title',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              CyberSpacing.vertical(CyberSpacing.xs),
              Text(
                LocalizationService.instance.translate(
                  'dashboard_protection_description',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          );
          final Widget status = CyberStatusIndicator(
            status: CyberStatus.neutral,
            label: LocalizationService.instance.translate(
              'dashboard_protection_status',
            ),
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProtectionIcon(),
                    CyberSpacing.vertical(CyberSpacing.md),
                    copy,
                    CyberSpacing.vertical(CyberSpacing.md),
                    status,
                  ],
                )
              : Row(
                  children: [
                    _ProtectionIcon(),
                    CyberSpacing.horizontal(CyberSpacing.lg),
                    Expanded(child: copy),
                    CyberSpacing.horizontal(CyberSpacing.lg),
                    status,
                  ],
                );
        },
      ),
    );
  }
}

class _ProtectionIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: CyberRadius.standardRadius,
      ),
      child: Icon(
        Icons.shield_outlined,
        color: theme.colorScheme.secondary,
        size: CyberDimensions.iconLarge,
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final double width =
            (constraints.maxWidth - ((columns - 1) * CyberSpacing.md)) /
            columns;

        final List<_DashboardAction> actions = [
          _DashboardAction(
            label: LocalizationService.instance.translate(
              'dashboard_action_scanner',
            ),
            description: LocalizationService.instance.translate(
              'dashboard_action_scanner_description',
            ),
            icon: Icons.travel_explore_rounded,
            onTap: () => onNavigate(1),
          ),
          _DashboardAction(
            label: LocalizationService.instance.translate(
              'dashboard_action_report',
            ),
            description: LocalizationService.instance.translate(
              'dashboard_action_report_description',
            ),
            icon: Icons.campaign_rounded,
            onTap: () => onNavigate(3),
          ),
          _DashboardAction(
            label: LocalizationService.instance.translate(
              'dashboard_action_emergency',
            ),
            description: LocalizationService.instance.translate(
              'dashboard_action_emergency_description',
            ),
            icon: Icons.emergency_rounded,
            onTap: () => onNavigate(2),
            variant: CyberCardVariant.emergency,
          ),
        ];

        return Wrap(
          spacing: CyberSpacing.md,
          runSpacing: CyberSpacing.md,
          children: actions
              .map((action) => SizedBox(width: width, child: action))
              .toList(),
        );
      },
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
    this.variant = CyberCardVariant.action,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final CyberCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final bool danger = variant == CyberCardVariant.emergency;
    return CyberCard(
      variant: variant,
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: danger
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: CyberRadius.standardRadius,
            ),
            child: Icon(
              icon,
              color: danger
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.secondary,
              size: CyberDimensions.iconLarge,
            ),
          ),
          CyberSpacing.vertical(CyberSpacing.md),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      variant: CyberCardVariant.criticalAlert,
      padding: const EdgeInsets.all(CyberSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 660;
          final ThemeData theme = Theme.of(context);
          final Widget copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: CyberDimensions.iconLarge,
                  ),
                  CyberSpacing.horizontal(CyberSpacing.xs),
                  Expanded(
                    child: Text(
                      LocalizationService.instance.translate('hacked_btn'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              CyberSpacing.vertical(CyberSpacing.sm),
              Text(
                LocalizationService.instance.translate(
                  'dashboard_emergency_description',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          );
          final Widget button = CyberButton(
            label: LocalizationService.instance.translate('dashboard_get_help'),
            variant: CyberButtonVariant.danger,
            icon: const Icon(Icons.security_update_warning_rounded),
            onPressed: onPressed,
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    CyberSpacing.vertical(CyberSpacing.md),
                    button,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    CyberSpacing.horizontal(CyberSpacing.lg),
                    button,
                  ],
                );
        },
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      variant: CyberCardVariant.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: CyberRadius.standardRadius,
            ),
            child: Icon(
              Icons.inbox_outlined,
              color: Theme.of(context).colorScheme.secondary,
              size: CyberDimensions.iconMedium,
            ),
          ),
          CyberSpacing.horizontal(CyberSpacing.md),
          Expanded(
            child: Text(
              LocalizationService.instance.translate(
                'dashboard_activity_empty',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankSecurityTeaser extends StatelessWidget {
  const _BankSecurityTeaser({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CyberCard(
      variant: CyberCardVariant.standard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget copy = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: CyberRadius.standardRadius,
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  color: theme.colorScheme.secondary,
                  size: CyberDimensions.iconLarge,
                ),
              ),
              CyberSpacing.horizontal(CyberSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.instance.translate(
                        'bank_security_title',
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    CyberSpacing.vertical(CyberSpacing.xxs),
                    Text(
                      LocalizationService.instance.translate(
                        'dashboard_bank_security_description',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final Widget action = CyberButton(
            label: LocalizationService.instance.translate(
              'dashboard_bank_security_view',
            ),
            variant: CyberButtonVariant.tertiary,
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: onTap,
          );

          return constraints.maxWidth < 620
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    CyberSpacing.vertical(CyberSpacing.sm),
                    action,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    CyberSpacing.horizontal(CyberSpacing.lg),
                    action,
                  ],
                );
        },
      ),
    );
  }
}

class _AdditionalServices extends StatelessWidget {
  const _AdditionalServices({required this.onNavigate, this.onDevelopersTap});

  final ValueChanged<int> onNavigate;
  final VoidCallback? onDevelopersTap;

  @override
  Widget build(BuildContext context) {
    final List<_ServiceLink> services = [
      _ServiceLink(
        LocalizationService.instance.translate('cyber_news'),
        Icons.newspaper_rounded,
        () => onNavigate(5),
      ),
      _ServiceLink(
        LocalizationService.instance.translate('rewards'),
        Icons.workspace_premium_rounded,
        () => onNavigate(7),
      ),
      _ServiceLink(
        LocalizationService.instance.translate('sessions'),
        Icons.groups_rounded,
        () => onNavigate(8),
      ),
      _ServiceLink(
        LocalizationService.instance.translate('scan_system'),
        Icons.phonelink_lock_rounded,
        () => onNavigate(6),
      ),
      _ServiceLink(
        LocalizationService.instance.translate('contact_us'),
        Icons.support_agent_rounded,
        () => onNavigate(9),
      ),
      _ServiceLink(
        LocalizationService.instance.translate('developers'),
        Icons.engineering_rounded,
        onDevelopersTap ?? () => onNavigate(10),
      ),
    ];

    return CyberCard(
      variant: CyberCardVariant.standard,
      padding: const EdgeInsets.all(CyberSpacing.md),
      child: Wrap(
        spacing: CyberSpacing.xs,
        runSpacing: CyberSpacing.xs,
        children: services
            .map(
              (service) => TextButton.icon(
                onPressed: service.onTap,
                icon: Icon(service.icon, size: CyberDimensions.iconMedium),
                label: Text(service.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ServiceLink {
  const _ServiceLink(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        CyberSpacing.vertical(CyberSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}
