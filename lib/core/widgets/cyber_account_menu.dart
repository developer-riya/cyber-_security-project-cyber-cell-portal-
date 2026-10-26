import 'package:flutter/material.dart';

import '../localization/supported_language.dart';
import '../theme/cyber_tokens.dart';
import '../../services/language_preference_service.dart';
import '../../services/localization_service.dart';

enum _CyberAccountMenuAction { profile, language, signOut }

class CyberAccountAvatar extends StatelessWidget {
  const CyberAccountAvatar({
    super.key,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.semanticLabel,
    this.radius = 20,
  });

  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String semanticLabel;
  final double radius;

  static String initials({String? displayName, String? email}) {
    final String? trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      final List<String> parts = trimmedName.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }

    final String? trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return trimmedEmail[0].toUpperCase();
    }
    return 'C';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? trimmedPhotoUrl = photoUrl?.trim();
    final bool hasPhoto = trimmedPhotoUrl != null && trimmedPhotoUrl.isNotEmpty;

    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          backgroundImage: hasPhoto ? NetworkImage(trimmedPhotoUrl) : null,
          child: hasPhoto
              ? null
              : Text(
                  initials(displayName: displayName, email: email),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
        ),
      ),
    );
  }
}

class CyberAccountPreferences {
  const CyberAccountPreferences._();

  static String languageName(String code) {
    final SupportedLanguage? language = SupportedLanguage.fromCode(code);
    return language?.nativeName ?? SupportedLanguage.fromCode('en')!.nativeName;
  }

  static Future<void> chooseLanguage(BuildContext context) async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CyberSpacing.xl,
                0,
                CyberSpacing.xl,
                CyberSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  LocalizationService.instance.translate('profile_language'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ...SupportedLanguage.primary.map(
              (language) => ListTile(
                title: Text(language.nativeName),
                subtitle: Text(language.englishName),
                trailing:
                    language.code ==
                        LocalizationService.instance.currentLocale.value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, language.code),
              ),
            ),
            CyberSpacing.vertical(CyberSpacing.sm),
          ],
        ),
      ),
    );

    final SupportedLanguage? language = SupportedLanguage.fromCode(code);
    if (language != null) {
      await LanguagePreferenceService.instance.save(language);
    }
  }

  static Future<void> confirmSignOut(
    BuildContext context, {
    required Future<void> Function() onConfirm,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: Text(
          LocalizationService.instance.translate('profile_signout_title'),
        ),
        content: Text(
          LocalizationService.instance.translate('profile_signout_description'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocalizationService.instance.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              LocalizationService.instance.translate('profile_signout_confirm'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onConfirm();
    }
  }
}

class CyberAccountMenu extends StatelessWidget {
  const CyberAccountMenu({
    super.key,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.onProfile,
    required this.onSignOut,
  });

  final String? displayName;
  final String? email;
  final String? photoUrl;
  final VoidCallback onProfile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = _accountName();
    final String? accountEmail = email?.trim();
    final String locale = LocalizationService.instance.currentLocale.value;

    return PopupMenuButton<_CyberAccountMenuAction>(
      tooltip: LocalizationService.instance.translate('profile_title'),
      offset: const Offset(0, 48),
      popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: CyberMotion.standard,
              reverseDuration: CyberMotion.fast,
              curve: CyberMotion.standardCurve,
              reverseCurve: Curves.easeInCubic,
            ),
      elevation: 4,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: CyberRadius.standardRadius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      onSelected: (action) async {
        switch (action) {
          case _CyberAccountMenuAction.profile:
            onProfile();
          case _CyberAccountMenuAction.language:
            await CyberAccountPreferences.chooseLanguage(context);
          case _CyberAccountMenuAction.signOut:
            await onSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_CyberAccountMenuAction>(
          enabled: false,
          height: 72,
          child: _AccountMenuHeader(name: name, email: accountEmail),
        ),
        const PopupMenuDivider(),
        _AccountMenuItem(
          value: _CyberAccountMenuAction.profile,
          icon: Icons.person_outline_rounded,
          title: LocalizationService.instance.translate('profile_title'),
        ),
        _AccountMenuItem(
          value: _CyberAccountMenuAction.language,
          icon: Icons.language_rounded,
          title: LocalizationService.instance.translate('profile_language'),
          valueLabel: CyberAccountPreferences.languageName(locale),
        ),
        const PopupMenuDivider(),
        _AccountMenuItem(
          value: _CyberAccountMenuAction.signOut,
          icon: Icons.logout_rounded,
          title: LocalizationService.instance.translate('profile_sign_out'),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          label:
              '$name, ${LocalizationService.instance.translate('profile_title')}',
          child: CyberAccountAvatar(
            displayName: displayName,
            email: email,
            photoUrl: photoUrl,
            radius: 18,
            semanticLabel: LocalizationService.instance.translate(
              'profile_avatar_label',
            ),
          ),
        ),
      ),
    );
  }

  String _accountName() {
    final String? trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    final String? trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return trimmedEmail.split('@').first;
    }
    return LocalizationService.instance.translate('profile_citizen_fallback');
  }
}

class _AccountMenuHeader extends StatelessWidget {
  const _AccountMenuHeader({required this.name, this.email});

  final String name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 236,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (email != null && email!.isNotEmpty) ...[
            CyberSpacing.vertical(CyberSpacing.xxs),
            Text(
              email!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountMenuItem extends PopupMenuItem<_CyberAccountMenuAction> {
  _AccountMenuItem({
    required _CyberAccountMenuAction value,
    required IconData icon,
    required String title,
    String? valueLabel,
  }) : super(
         value: value,
         height: CyberDimensions.controlHeight + 8,
         child: _AccountMenuItemContent(
           icon: icon,
           title: title,
           valueLabel: valueLabel,
         ),
       );
}

class _AccountMenuItemContent extends StatelessWidget {
  const _AccountMenuItemContent({
    required this.icon,
    required this.title,
    this.valueLabel,
  });

  final IconData icon;
  final String title;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: CyberDimensions.iconMedium),
        CyberSpacing.horizontal(CyberSpacing.sm),
        Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
        if (valueLabel != null) ...[
          CyberSpacing.horizontal(CyberSpacing.sm),
          Flexible(
            child: Text(
              valueLabel!,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
