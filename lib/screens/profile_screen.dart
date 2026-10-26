import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class ProfileIdentity {
  const ProfileIdentity({this.displayName, this.email, this.photoUrl});

  factory ProfileIdentity.fromUser(User? user) {
    return ProfileIdentity(
      displayName: user?.displayName,
      email: user?.email,
      photoUrl: user?.photoURL,
    );
  }

  final String? displayName;
  final String? email;
  final String? photoUrl;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.user, this.identity, this.onHelpTap});

  final User? user;
  final ProfileIdentity? identity;
  final VoidCallback? onHelpTap;

  @override
  Widget build(BuildContext context) {
    final ProfileIdentity account = identity ?? _identityFromUser(user);
    final ThemeData productTheme = CyberTheme.lightTheme;

    return Theme(
      data: productTheme,
      child: ValueListenableBuilder<String>(
        valueListenable: LocalizationService.instance.currentLocale,
        builder: (context, locale, _) {
          return Scaffold(
                appBar: AppBar(
                  leading: Semantics(
                    label: LocalizationService.instance.translate(
                      'profile_back',
                    ),
                    button: true,
                    child: const BackButton(),
                  ),
                  title: Text(
                    LocalizationService.instance.translate('profile_title'),
                  ),
                ),
                body: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool desktop = constraints.maxWidth >= 900;
                      final List<Widget> groups = _buildGroups(
                        context: context,
                        locale: locale,
                      );

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          CyberSpacing.md,
                          desktop ? CyberSpacing.xxl : CyberSpacing.xl,
                          CyberSpacing.md,
                          CyberSpacing.page,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: CyberDimensions.maxContentWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (desktop) ...[
                                  _ProfileContextHeader(),
                                  CyberSpacing.vertical(CyberSpacing.lg),
                                ],
                                if (desktop)
                                  _DesktopAccountCenter(
                                    identity: account,
                                    groups: groups,
                                  )
                                else ...[
                                  _IdentityHero(
                                    identity: account,
                                    horizontal: false,
                                  ),
                                  CyberSpacing.vertical(CyberSpacing.xl),
                                  _MobileGroups(groups: groups),
                                ],
                                CyberSpacing.vertical(CyberSpacing.xl),
                                _AccountActions(
                                  onSignOut: () =>
                                      CyberAccountPreferences.confirmSignOut(
                                        context,
                                        onConfirm: () =>
                                            AuthService.instance.logout(),
                                      ),
                                  fullWidth: !desktop,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups({
    required BuildContext context,
    required String locale,
  }) {
    return [
      CyberSettingsGroup(
        title: LocalizationService.instance.translate(
          'profile_preferences_group',
        ),
        description: LocalizationService.instance.translate(
          'profile_preferences_description',
        ),
        children: [
          CyberSettingsRow(
            icon: Icons.language_rounded,
            title: LocalizationService.instance.translate('profile_language'),
            subtitle: LocalizationService.instance.translate(
              'profile_language_subtitle',
            ),
            trailing: _RowValue(
              value: CyberAccountPreferences.languageName(locale),
            ),
            onTap: () => CyberAccountPreferences.chooseLanguage(context),
          ),
        ],
      ),
      if (onHelpTap != null)
        CyberSettingsGroup(
          title: LocalizationService.instance.translate(
            'profile_support_group',
          ),
          description: LocalizationService.instance.translate(
            'profile_support_group_description',
          ),
          children: [
            CyberSettingsRow(
              icon: Icons.support_agent_rounded,
              title: LocalizationService.instance.translate('profile_help'),
              subtitle: LocalizationService.instance.translate(
                'profile_help_subtitle',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                onHelpTap!();
              },
            ),
          ],
        ),
    ];
  }

  static ProfileIdentity _identityFromUser(User? user) {
    if (user != null) return ProfileIdentity.fromUser(user);
    try {
      return ProfileIdentity.fromUser(AuthService.instance.currentUser);
    } catch (_) {
      return const ProfileIdentity();
    }
  }
}

class _ProfileContextHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocalizationService.instance.translate('profile_header_title'),
          style: theme.textTheme.headlineMedium,
        ),
        CyberSpacing.vertical(CyberSpacing.xs),
        Text(
          LocalizationService.instance.translate('profile_header_subtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.identity, required this.horizontal});

  final ProfileIdentity identity;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = _displayName(identity);
    final String? email = identity.email?.trim();
    final Widget copy = Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (email != null && email.isNotEmpty) ...[
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
        CyberSpacing.vertical(CyberSpacing.sm),
        Text(
          LocalizationService.instance.translate('profile_account_label'),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );

    return CyberCard(
      variant: CyberCardVariant.elevated,
      padding: const EdgeInsets.all(CyberSpacing.xl),
      child: Row(
        crossAxisAlignment: horizontal
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: horizontal ? 92 : 128,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: CyberRadius.pillRadius,
            ),
          ),
          CyberSpacing.horizontal(CyberSpacing.lg),
          if (horizontal) ...[
            CyberAccountAvatar(
              displayName: identity.displayName,
              email: identity.email,
              photoUrl: identity.photoUrl,
              radius: 44,
              semanticLabel: LocalizationService.instance.translate(
                'profile_avatar_label',
              ),
            ),
            CyberSpacing.horizontal(CyberSpacing.lg),
            Expanded(child: copy),
          ] else
            Expanded(
              child: Column(
                children: [
                  CyberAccountAvatar(
                    displayName: identity.displayName,
                    email: identity.email,
                    photoUrl: identity.photoUrl,
                    radius: 44,
                    semanticLabel: LocalizationService.instance.translate(
                      'profile_avatar_label',
                    ),
                  ),
                  CyberSpacing.vertical(CyberSpacing.md),
                  copy,
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _displayName(ProfileIdentity identity) {
    final String? displayName = identity.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final String? email = identity.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return LocalizationService.instance.translate('profile_citizen_fallback');
  }
}

class _DesktopAccountCenter extends StatelessWidget {
  const _DesktopAccountCenter({required this.identity, required this.groups});

  final ProfileIdentity identity;
  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 360,
          child: _IdentityHero(identity: identity, horizontal: true),
        ),
        CyberSpacing.horizontal(CyberSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int index = 0; index < groups.length; index++) ...[
                groups[index],
                if (index < groups.length - 1)
                  CyberSpacing.vertical(CyberSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileGroups extends StatelessWidget {
  const _MobileGroups({required this.groups});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < groups.length; index++) ...[
          if (index > 0) CyberSpacing.vertical(CyberSpacing.lg),
          groups[index],
        ],
      ],
    );
  }
}

class _RowValue extends StatelessWidget {
  const _RowValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        CyberSpacing.horizontal(CyberSpacing.xs),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.onSignOut, required this.fullWidth});

  final VoidCallback onSignOut;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: fullWidth ? double.infinity : 220,
        child: CyberButton(
          label: LocalizationService.instance.translate('profile_sign_out'),
          variant: CyberButtonVariant.secondary,
          icon: const Icon(Icons.logout_rounded),
          expand: true,
          onPressed: onSignOut,
        ),
      ),
    );
  }
}
