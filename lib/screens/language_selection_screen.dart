import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../core/localization/app_localizations_helper.dart';
import '../core/localization/supported_language.dart';
import '../l10n/app_localizations.dart';
import '../services/language_preference_service.dart';
import '../services/localization_service.dart';
import 'onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  SupportedLanguage? _selectedLanguage;
  bool _isSaving = false;

  void _selectLanguage(SupportedLanguage language) {
    if (!language.isAvailable) return;
    LocalizationService.instance.setLocale(language.code);
    setState(() => _selectedLanguage = language);
  }

  Future<void> _openMoreLanguages() async {
    final SupportedLanguage? selectedLanguage =
        await showModalBottomSheet<SupportedLanguage>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) =>
              _LanguagePickerSheet(selectedLanguage: _selectedLanguage),
        );

    if (selectedLanguage != null) _selectLanguage(selectedLanguage);
  }

  Future<void> _continue() async {
    final SupportedLanguage? selectedLanguage = _selectedLanguage;
    if (selectedLanguage == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await LanguagePreferenceService.instance.save(selectedLanguage);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
                  final CyberWindowSize windowSize = CyberBreakpoints.fromWidth(
                    constraints.maxWidth,
                  );
                  final bool compact = windowSize == CyberWindowSize.compact;

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
                            vertical: CyberSpacing.xl,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Header(
                                  compact: compact,
                                  title: localizations.languageSelectionTitle,
                                  description: localizations
                                      .languageSelectionDescription,
                                ),
                                CyberSpacing.vertical(CyberSpacing.xxl),
                                ...SupportedLanguage.primary.map(
                                  (SupportedLanguage language) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: CyberSpacing.sm,
                                    ),
                                    child: _LanguageOption(
                                      language: language,
                                      selected: _selectedLanguage == language,
                                      selectedLabel: localizations
                                          .languageSelectionSelected,
                                      notSelectedLabel: localizations
                                          .languageSelectionNotSelected,
                                      onTap: () => _selectLanguage(language),
                                    ),
                                  ),
                                ),
                                CyberButton(
                                  label: localizations.languageSelectionMore,
                                  variant: CyberButtonVariant.tertiary,
                                  onPressed: _openMoreLanguages,
                                  icon: const Icon(Icons.language_rounded),
                                  semanticLabel:
                                      localizations.languageSelectionMore,
                                ),
                                CyberSpacing.vertical(CyberSpacing.md),
                                CyberButton(
                                  label: _isSaving
                                      ? localizations.languageSelectionSaving
                                      : localizations.languageSelectionContinue,
                                  onPressed: _selectedLanguage == null
                                      ? null
                                      : _continue,
                                  isLoading: _isSaving,
                                  expand: true,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  semanticLabel:
                                      localizations.languageSelectionContinue,
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.compact,
    required this.title,
    required this.description,
  });

  final bool compact;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: compact ? 48 : 56,
          height: compact ? 48 : 56,
          decoration: BoxDecoration(
            color: CyberColors.surface,
            borderRadius: CyberRadius.largeRadius,
            border: Border.all(color: CyberColors.border),
          ),
          child: const Icon(
            Icons.translate_rounded,
            color: CyberColors.primary,
          ),
        ),
        CyberSpacing.vertical(CyberSpacing.xl),
        Text(title, style: theme.textTheme.headlineMedium),
        CyberSpacing.vertical(CyberSpacing.sm),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: CyberColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.selectedLabel,
    required this.notSelectedLabel,
    required this.onTap,
  });

  final SupportedLanguage language;
  final bool selected;
  final String selectedLabel;
  final String notSelectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label:
          '${language.nativeName}, '
          '${selected ? selectedLabel : notSelectedLabel}',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: CyberDimensions.controlHeight + CyberSpacing.md,
          ),
          child: CyberCard(
            variant: selected
                ? CyberCardVariant.action
                : CyberCardVariant.standard,
            onTap: onTap,
            padding: const EdgeInsets.symmetric(
              horizontal: CyberSpacing.lg,
              vertical: CyberSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? CyberColors.brandAccent
                      : CyberColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.selectedLanguage});

  final SupportedLanguage? selectedLanguage;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SupportedLanguage> get _filteredLanguages {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return SupportedLanguage.all;

    return SupportedLanguage.all
        .where((SupportedLanguage language) {
          return language.nativeName.toLowerCase().contains(query) ||
              language.englishName.toLowerCase().contains(query) ||
              language.code.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = appLocalizationsFor(
      LocalizationService.instance.currentLocale.value,
    );
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.68;
    final List<SupportedLanguage> languages = _filteredLanguages;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: CyberSpacing.md,
          right: CyberSpacing.md,
          top: CyberSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + CyberSpacing.md,
        ),
        child: Material(
          color: CyberColors.background,
          borderRadius: CyberRadius.standardRadius,
          child: Padding(
            padding: const EdgeInsets.all(CyberSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.languageSelectionMoreTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                CyberSpacing.vertical(CyberSpacing.sm),
                CyberSearchField(
                  controller: _searchController,
                  hintText: localizations.languageSelectionSearchHint,
                  onChanged: (String value) => setState(() => _query = value),
                ),
                CyberSpacing.vertical(CyberSpacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: languages.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(CyberSpacing.xl),
                          child: Text(
                            localizations.languageSelectionNoResults,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: languages.length,
                          separatorBuilder: (context, index) =>
                              CyberSpacing.vertical(CyberSpacing.xs),
                          itemBuilder: (context, index) {
                            final SupportedLanguage language = languages[index];
                            final bool selected =
                                widget.selectedLanguage == language;
                            return _PickerLanguageOption(
                              language: language,
                              selected: selected,
                              selectedLabel:
                                  localizations.languageSelectionSelected,
                              notSelectedLabel:
                                  localizations.languageSelectionNotSelected,
                              comingSoonLabel:
                                  localizations.languageSelectionComingSoon,
                              onTap: language.isAvailable
                                  ? () => Navigator.of(context).pop(language)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerLanguageOption extends StatelessWidget {
  const _PickerLanguageOption({
    required this.language,
    required this.selected,
    required this.selectedLabel,
    required this.notSelectedLabel,
    required this.comingSoonLabel,
    required this.onTap,
  });

  final SupportedLanguage language;
  final bool selected;
  final String selectedLabel;
  final String notSelectedLabel;
  final String comingSoonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String status = language.isAvailable
        ? (selected ? selectedLabel : notSelectedLabel)
        : comingSoonLabel;
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap != null,
      selected: selected,
      label: '${language.nativeName}, ${language.englishName}, $status',
      child: ExcludeSemantics(
        child: CyberCard(
          variant: selected
              ? CyberCardVariant.action
              : CyberCardVariant.listRow,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(
            horizontal: CyberSpacing.md,
            vertical: CyberSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.nativeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      language.englishName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CyberColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (language.isAvailable)
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? CyberColors.brandAccent
                      : CyberColors.textTertiary,
                )
              else
                Text(
                  comingSoonLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CyberColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
