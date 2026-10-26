import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryLabel,
    this.secondaryLabel,
    this.onPrimaryTap,
    this.onSecondaryTap,
  });

  final String title;
  final String subtitle;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 760;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          if (primaryLabel != null || secondaryLabel != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (primaryLabel != null)
                  SizedBox(
                    width: mobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: onPrimaryTap,
                      icon: const Icon(Icons.account_balance_rounded),
                      label: Text(primaryLabel!),
                    ),
                  ),
                if (secondaryLabel != null)
                  SizedBox(
                    width: mobile ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: onSecondaryTap,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: Text(secondaryLabel!),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class ActionChipWidget extends StatelessWidget {
  const ActionChipWidget({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  final String label;
  final dynamic icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return MouseRegion(
      cursor: isLoading || onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
        focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.secondary,
                      ),
                    )
                  : (icon is IconData
                        ? Icon(
                            icon as IconData,
                            size: 18,
                            color: theme.colorScheme.secondary,
                          )
                        : FaIcon(
                            icon,
                            size: 18,
                            color: theme.colorScheme.secondary,
                          )),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class FieldPlaceholder extends StatelessWidget {
  const FieldPlaceholder({
    super.key,
    required this.label,
    this.controller,
    this.maxLines = 2,
  });

  final String label;
  final TextEditingController? controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E4A67)),
        ),
      ),
    );
  }
}
