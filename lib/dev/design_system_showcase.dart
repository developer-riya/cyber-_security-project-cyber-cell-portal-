import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';

/// Isolated visual validation screen. It is intentionally not wired to app navigation.
class CyberDesignSystemShowcase extends StatelessWidget {
  const CyberDesignSystemShowcase({super.key});

  static void _noop() {}

  static void _onSelection(String? value) {}

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CyberTheme.lightTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Cyber Uday Design System')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: CyberDimensions.maxContentWidth,
            ),
            child: ListView(
              padding: CyberSpacing.pagePadding,
              children: [
                Text(
                  'Foundation preview',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                CyberSpacing.vertical(CyberSpacing.xs),
                Text(
                  'Neutral-first components with semantic status colors.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                CyberSpacing.vertical(CyberSpacing.section),
                _Section(
                  title: 'Color roles',
                  child: Wrap(
                    spacing: CyberSpacing.sm,
                    runSpacing: CyberSpacing.sm,
                    children: const [
                      _ColorSwatch('Background', CyberColors.background),
                      _ColorSwatch('Surface', CyberColors.surface),
                      _ColorSwatch('Primary', CyberColors.primary),
                      _ColorSwatch('Accent', CyberColors.brandAccent),
                      _ColorSwatch('Success', CyberColors.success),
                      _ColorSwatch('Warning', CyberColors.warning),
                      _ColorSwatch('Danger', CyberColors.danger),
                    ],
                  ),
                ),
                CyberSpacing.vertical(CyberSpacing.lg),
                _Section(
                  title: 'Typography',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display',
                        style: CyberTypography.textTheme.displayLarge,
                      ),
                      Text(
                        'Headline large',
                        style: CyberTypography.textTheme.headlineLarge,
                      ),
                      Text(
                        'Title medium',
                        style: CyberTypography.textTheme.titleMedium,
                      ),
                      Text(
                        'Body text for readable product content.',
                        style: CyberTypography.textTheme.bodyLarge,
                      ),
                      Text(
                        'Label and supporting text',
                        style: CyberTypography.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                CyberSpacing.vertical(CyberSpacing.lg),
                _Section(
                  title: 'Cards and statuses',
                  child: Column(
                    children: [
                      const CyberCard(
                        child: Text('Standard card with a restrained surface.'),
                      ),
                      CyberSpacing.vertical(CyberSpacing.sm),
                      const CyberCard(
                        variant: CyberCardVariant.elevated,
                        child: Text('Elevated card for focused content.'),
                      ),
                      CyberSpacing.vertical(CyberSpacing.sm),
                      const CyberCard(
                        variant: CyberCardVariant.emergency,
                        child: Text(
                          'Emergency card uses danger semantics only.',
                        ),
                      ),
                      CyberSpacing.vertical(CyberSpacing.md),
                      const Wrap(
                        spacing: CyberSpacing.xs,
                        runSpacing: CyberSpacing.xs,
                        children: [
                          CyberStatusIndicator(
                            status: CyberStatus.safe,
                            label: 'Safe',
                          ),
                          CyberStatusIndicator(
                            status: CyberStatus.warning,
                            label: 'Review',
                          ),
                          CyberStatusIndicator(
                            status: CyberStatus.danger,
                            label: 'Critical',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                CyberSpacing.vertical(CyberSpacing.lg),
                _Section(
                  title: 'Controls',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: CyberSpacing.sm,
                        runSpacing: CyberSpacing.sm,
                        children: [
                          CyberButton(
                            label: 'Primary',
                            onPressed: _noop,
                            icon: const Icon(Icons.shield_outlined),
                          ),
                          CyberButton(
                            label: 'Secondary',
                            variant: CyberButtonVariant.secondary,
                            onPressed: _noop,
                          ),
                          CyberButton(
                            label: 'Text action',
                            variant: CyberButtonVariant.tertiary,
                            onPressed: _noop,
                          ),
                          CyberButton(
                            label: 'Emergency',
                            variant: CyberButtonVariant.danger,
                            onPressed: _noop,
                          ),
                        ],
                      ),
                      CyberSpacing.vertical(CyberSpacing.md),
                      const CyberInput(
                        label: 'Example field',
                        hintText: 'Enter a value',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      CyberSpacing.vertical(CyberSpacing.md),
                      const CyberSearchField(hintText: 'Search the workspace'),
                      CyberSpacing.vertical(CyberSpacing.md),
                      const CyberOtpInput(),
                      CyberSpacing.vertical(CyberSpacing.md),
                      CyberDropdown<String>(
                        label: 'Example selection',
                        value: 'citizen',
                        items: const [
                          DropdownMenuItem(
                            value: 'citizen',
                            child: Text('Citizen workspace'),
                          ),
                          DropdownMenuItem(
                            value: 'family',
                            child: Text('Family workspace'),
                          ),
                        ],
                        onChanged: _onSelection,
                      ),
                    ],
                  ),
                ),
                CyberSpacing.vertical(CyberSpacing.lg),
                _Section(
                  title: 'Spacing scale',
                  child: Wrap(
                    spacing: CyberSpacing.sm,
                    runSpacing: CyberSpacing.sm,
                    children: [
                      for (final double value in [
                        CyberSpacing.xxs,
                        CyberSpacing.xs,
                        CyberSpacing.sm,
                        CyberSpacing.md,
                        CyberSpacing.lg,
                        CyberSpacing.xl,
                        CyberSpacing.xxl,
                      ])
                        Chip(label: Text('${value.toInt()} px')),
                    ],
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        CyberSpacing.vertical(CyberSpacing.sm),
        child,
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label color',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: CyberRadius.standardRadius,
              border: Border.all(color: CyberColors.border),
            ),
          ),
          CyberSpacing.vertical(CyberSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
