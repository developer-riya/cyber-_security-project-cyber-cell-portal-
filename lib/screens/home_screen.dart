import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../core/localization/supported_language.dart';
import '../services/auth_service.dart';
import '../services/language_preference_service.dart';
import '../services/localization_service.dart';
import 'admin_login_screen.dart';
import 'cyber_cell_login_screen.dart';
import 'home/pages/dashboard_page.dart';
import 'home/pages/report_crime_page.dart';
import 'home/pages/case_tracking_page.dart';
import 'home/pages/threat_scanner_page.dart';
import 'home/pages/cyber_news_page.dart';
import 'home/pages/rewards_page.dart';
import 'home/pages/contact_us_page.dart';
import 'home/pages/sessions_page.dart';
import 'home/pages/scan_system_page.dart';
import 'home/pages/emergency_contacts_page.dart';
import 'home/pages/bank_security_page.dart';
import 'home/pages/developers_page.dart';
import 'profile_screen.dart';
import '../widgets/cyber_smart_assistant.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool mobile = MediaQuery.sizeOf(context).width < 900;

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.currentLocale,
      builder: (context, locale, _) {
        final ThemeData theme = Theme.of(context);
        final List<_ShellDestination> destinations = [
          _ShellDestination(
            title: LocalizationService.instance.translate('dashboard'),
            icon: Icons.dashboard_rounded,
            section: LocalizationService.instance.translate('nav_protection'),
            builder: (context) => DashboardPage(
              user: AuthService.instance.currentUser,
              onNavigate: (index) {
                setState(() => _selectedIndex = index);
              },
              onDevelopersTap: () {
                setState(() => _selectedIndex = 11);
              },
            ),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('threat_scanner'),
            icon: Icons.travel_explore_rounded,
            section: LocalizationService.instance.translate('nav_protection'),
            builder: (context) => const ThreatScannerPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('emergency'),
            icon: Icons.emergency_rounded,
            section: LocalizationService.instance.translate('nav_protection'),
            builder: (context) => const EmergencyContactsPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('report_crime'),
            icon: Icons.campaign_rounded,
            section: LocalizationService.instance.translate('nav_protection'),
            builder: (context) => const ReportCrimePage(),
          ),
          const _ShellDestination(
            title: 'My Cases',
            icon: Icons.track_changes_rounded,
            section: 'Support',
            builder: _buildCaseTracking,
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('bank_security'),
            icon: Icons.account_balance_outlined,
            section: LocalizationService.instance.translate('nav_protection'),
            builder: (context) => const BankSecurityPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('cyber_news'),
            icon: Icons.newspaper_rounded,
            section: LocalizationService.instance.translate('nav_support'),
            builder: (context) => const CyberNewsPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('scan_system'),
            icon: Icons.phonelink_lock_rounded,
            section: LocalizationService.instance.translate('nav_support'),
            builder: (context) => const ScanSystemPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('rewards'),
            icon: Icons.workspace_premium_rounded,
            section: LocalizationService.instance.translate('nav_support'),
            builder: (context) => const RewardsPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('sessions'),
            icon: Icons.groups_rounded,
            section: LocalizationService.instance.translate('nav_support'),
            builder: (context) => const SessionsPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('contact_us'),
            icon: Icons.support_agent_rounded,
            section: LocalizationService.instance.translate('nav_support'),
            builder: (context) => const ContactUsPage(),
          ),
          _ShellDestination(
            title: LocalizationService.instance.translate('developers'),
            icon: Icons.engineering_rounded,
            section: LocalizationService.instance.translate('nav_about'),
            builder: (context) => const DevelopersPage(),
          ),
        ];

        final destination = destinations[_selectedIndex];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.shield_moon_rounded,
                  color: theme.colorScheme.secondary,
                  size: CyberDimensions.iconMedium,
                ),
                CyberSpacing.horizontal(CyberSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CYBER UDAY',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      Text(
                        destination.title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.64,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              _LanguageSelector(),
              _ProfileButton(
                user: AuthService.instance.currentUser,
                onHelpTap: () => setState(() => _selectedIndex = 9),
              ),
            ],
          ),
          drawer: mobile
              ? _ShellDrawer(
                  destinations: destinations,
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  onAdminTap: _openAdmin,
                  onCyberCellTap: _openCyberCell,
                )
              : null,
          body: Container(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (!mobile)
                    _ShellRail(
                      destinations: destinations,
                      selectedIndex: _selectedIndex,
                      onSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                      onCyberCellTap: _openCyberCell,
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 12 : 0,
                        12,
                        mobile ? 12 : 18,
                        18,
                      ),
                      child: destination.builder(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: CyberSmartAssistant(
            onNavigate: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }

  void _openAdmin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen()));
  }

  void _openCyberCell() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CyberCellLoginScreen()),
    );
  }

  static Widget _buildCaseTracking(BuildContext context) =>
      const CaseTrackingPage();
}

class _LanguageSelector extends StatelessWidget {
  Future<void> _saveLanguage(String code) async {
    final SupportedLanguage? language = SupportedLanguage.fromCode(code);
    if (language != null) {
      await LanguagePreferenceService.instance.save(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String locale = LocalizationService.instance.currentLocale.value;
    return PopupMenuButton<String>(
      tooltip: LocalizationService.instance.translate('profile_language'),
      offset: const Offset(0, 48),
      popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: CyberMotion.standard,
              reverseDuration: CyberMotion.fast,
              curve: CyberMotion.standardCurve,
              reverseCurve: Curves.easeInCubic,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: CyberRadius.standardRadius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      onSelected: (locale) => _saveLanguage(locale),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'en',
          child: Text(
            LocalizationService.instance.translate('language_english'),
          ),
        ),
        PopupMenuItem(
          value: 'hi',
          child: Text(LocalizationService.instance.translate('language_hindi')),
        ),
        PopupMenuItem(
          value: 'mr',
          child: Text(
            LocalizationService.instance.translate('language_marathi'),
          ),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          label:
              '${LocalizationService.instance.translate('profile_language')}: ${_languageName(locale)}',
          child: Container(
            height: 36,
            margin: const EdgeInsets.only(right: CyberSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: CyberSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: CyberRadius.standardRadius,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  size: CyberDimensions.iconMedium,
                  color: theme.colorScheme.secondary,
                ),
                CyberSpacing.horizontal(CyberSpacing.xs),
                Text(_languageName(locale), style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _languageName(String code) {
    return SupportedLanguage.fromCode(code)?.nativeName ?? 'English';
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.user, this.onHelpTap});

  final User? user;
  final VoidCallback? onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: CyberAccountMenu(
        displayName: user?.displayName,
        email: user?.email,
        photoUrl: user?.photoURL,
        onProfile: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(user: user, onHelpTap: onHelpTap),
            ),
          );
        },
        onSignOut: () => CyberAccountPreferences.confirmSignOut(
          context,
          onConfirm: () => AuthService.instance.logout(),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.title,
    required this.icon,
    required this.section,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final String section;
  final WidgetBuilder builder;
}

class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCyberCellTap,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCyberCellTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> railItems = <Widget>[];
    String? currentSection;
    for (int index = 0; index < destinations.length; index++) {
      final _ShellDestination destination = destinations[index];
      if (destination.section != currentSection) {
        if (currentSection != null) {
          railItems.add(const SizedBox(height: CyberSpacing.md));
        }
        railItems.add(_ShellSectionLabel(title: destination.section));
        currentSection = destination.section;
      }
      if (index > 0 && destination.section == currentSection) {
        railItems.add(const SizedBox(height: CyberSpacing.xs));
      }
      railItems.add(
        _RailItem(
          destination: destination,
          selected: selectedIndex == index,
          onTap: () => onSelected(index),
        ),
      );
    }
    return Container(
      width: 260,
      margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: CyberRadius.largeRadius,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandBlock(),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(child: Column(children: railItems)),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminLoginScreen(),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(LocalizationService.instance.translate('admin')),
          ),
          TextButton.icon(
            onPressed: onCyberCellTap,
            icon: const Icon(Icons.local_police_outlined),
            label: const Text('Cyber Cell Portal'),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration motion = CyberMotion.duration(context, CyberMotion.standard);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: CyberRadius.standardRadius,
        hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
        focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion,
          curve: CyberMotion.standardCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: CyberRadius.standardRadius,
            color: selected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.title,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdminTap,
    required this.onCyberCellTap,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdminTap;
  final VoidCallback onCyberCellTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> drawerItems = <Widget>[];
    String? currentSection;
    for (int index = 0; index < destinations.length; index++) {
      final _ShellDestination destination = destinations[index];
      if (destination.section != currentSection) {
        drawerItems.add(_ShellSectionLabel(title: destination.section));
        currentSection = destination.section;
      }
      drawerItems.add(
        ListTile(
          selected: selectedIndex == index,
          leading: Icon(destination.icon),
          title: Text(destination.title),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
          focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
          onTap: () {
            Navigator.of(context).pop();
            onSelected(index);
          },
        ),
      );
    }
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: _BrandBlock()),
            Expanded(child: ListView(children: drawerItems)),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(LocalizationService.instance.translate('admin')),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
              focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
              onTap: () {
                Navigator.of(context).pop();
                onAdminTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_police_outlined),
              title: const Text('Cyber Cell Portal'),
              onTap: () {
                Navigator.of(context).pop();
                onCyberCellTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: theme.colorScheme.secondaryContainer,
          ),
          child: Icon(
            Icons.shield_moon_rounded,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 14),
        Text('CYBER UDAY', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          LocalizationService.instance.translate('brand_tagline'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ShellSectionLabel extends StatelessWidget {
  const _ShellSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: CyberSpacing.xs),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
