import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cyber_tokens.dart';

enum CyberCardVariant {
  standard,
  elevated,
  action,
  emergency,
  criticalAlert,
  status,
  compact,
  listRow,
}

class CyberCard extends StatefulWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.variant = CyberCardVariant.standard,
    this.onTap,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final CyberCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final String? semanticLabel;

  @override
  State<CyberCard> createState() => _CyberCardState();
}

class _CyberCardState extends State<CyberCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isEmergency = widget.variant == CyberCardVariant.emergency;
    final bool isCriticalAlert =
        widget.variant == CyberCardVariant.criticalAlert;
    final bool isStatus = widget.variant == CyberCardVariant.status;
    final bool isCompact = widget.variant == CyberCardVariant.compact;
    final bool isListRow = widget.variant == CyberCardVariant.listRow;
    final bool isInteractive = widget.onTap != null;
    final bool showInteractiveAccent =
        isInteractive &&
        (_hovered || _focused) &&
        !isEmergency &&
        !isCriticalAlert;
    final bool showPressedState = isInteractive && _pressed;
    final Duration motion = CyberMotion.duration(context, CyberMotion.standard);
    final Color borderColor = isCriticalAlert
        ? theme.colorScheme.error
        : isEmergency && (_hovered || _focused || showPressedState)
        ? theme.colorScheme.error
        : isEmergency
        ? theme.colorScheme.error.withValues(alpha: 0.48)
        : showPressedState
        ? theme.colorScheme.secondary
        : showInteractiveAccent
        ? theme.colorScheme.secondary
        : theme.colorScheme.outlineVariant;
    final Color baseBackgroundColor = isCriticalAlert
        ? theme.colorScheme.errorContainer
        : isStatus
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;
    final Color backgroundColor = showPressedState
        ? Color.alphaBlend(
            (isEmergency
                    ? theme.colorScheme.error
                    : theme.colorScheme.secondary)
                .withValues(alpha: 0.05),
            baseBackgroundColor,
          )
        : baseBackgroundColor;
    final List<BoxShadow> shadows = (_hovered || _focused) && isInteractive
        ? CyberElevation.raised
        : widget.variant == CyberCardVariant.elevated
        ? CyberElevation.raised
        : widget.variant == CyberCardVariant.standard
        ? CyberElevation.subtle
        : const <BoxShadow>[];
    final EdgeInsets cardPadding =
        widget.padding ??
        (isCompact || isListRow
            ? CyberSpacing.compactCardPadding
            : CyberSpacing.cardPadding);

    final Widget content = AnimatedContainer(
      duration: motion,
      curve: CyberMotion.standardCurve,
      width: double.infinity,
      padding: cardPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: CyberRadius.standardRadius,
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    final Widget interactive = !isInteractive
        ? content
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              if (!_hovered) setState(() => _hovered = true);
            },
            onExit: (_) {
              if (_hovered) setState(() => _hovered = false);
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onFocusChange: (focused) => setState(() => _focused = focused),
                onHighlightChanged: (pressed) =>
                    setState(() => _pressed = pressed),
                borderRadius: CyberRadius.standardRadius,
                hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
                focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
                highlightColor:
                    (isEmergency
                            ? theme.colorScheme.error
                            : theme.colorScheme.secondary)
                        .withValues(alpha: 0.1),
                child: content,
              ),
            ),
          );

    return Semantics(
      container: true,
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: interactive,
    );
  }
}

class CyberSettingsGroup extends StatelessWidget {
  const CyberSettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final List<Widget> children;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        if (description != null) ...[
          CyberSpacing.vertical(CyberSpacing.xxs),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
        ],
        CyberSpacing.vertical(CyberSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: CyberRadius.standardRadius,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: CyberElevation.subtle,
          ),
          child: ClipRRect(
            borderRadius: CyberRadius.standardRadius,
            child: Column(
              children: [
                for (int index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    Divider(
                      height: 1,
                      indent:
                          CyberSpacing.md +
                          CyberDimensions.iconLarge +
                          CyberSpacing.md,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CyberSettingsRow extends StatelessWidget {
  const CyberSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final Widget row = Material(
      color: Colors.transparent,
      child: ListTile(
        enabled: enabled,
        minVerticalPadding: CyberSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CyberSpacing.md,
          vertical: CyberSpacing.xs,
        ),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: CyberRadius.smallRadius,
          ),
          child: Icon(
            icon,
            color: enabled ? theme.colorScheme.secondary : foreground,
            size: CyberDimensions.iconMedium,
          ),
        ),
        title: Text(title, style: TextStyle(color: foreground)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
        mouseCursor: enabled && onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
        focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
        onTap: enabled ? onTap : null,
      ),
    );

    return Semantics(
      button: enabled && onTap != null,
      label: semanticLabel ?? title,
      child: row,
    );
  }
}

enum CyberButtonVariant { primary, secondary, tertiary, danger, success }

class CyberButton extends StatelessWidget {
  const CyberButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CyberButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final CyberButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = switch (variant) {
      CyberButtonVariant.danger => theme.colorScheme.error,
      CyberButtonVariant.success => CyberColors.success,
      _ => theme.colorScheme.secondary,
    };
    final ButtonStyle style = switch (variant) {
      CyberButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      CyberButtonVariant.secondary => OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      CyberButtonVariant.tertiary => TextButton.styleFrom(
        foregroundColor: theme.colorScheme.secondary,
      ),
      CyberButtonVariant.danger => ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
      ),
      CyberButtonVariant.success => ElevatedButton.styleFrom(
        backgroundColor: CyberColors.success,
        foregroundColor: CyberColors.onBrandAccent,
      ),
    };
    final ButtonStyle interactionStyle = style.copyWith(
      mouseCursor: WidgetStateProperty.resolveWith<MouseCursor>(
        (states) => states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return accent.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return accent.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return accent.withValues(alpha: 0.12);
        }
        return null;
      }),
      animationDuration: CyberMotion.duration(context, CyberMotion.standard),
    );
    final Widget buttonLabel = isLoading
        ? const SizedBox(
            width: CyberDimensions.iconMedium,
            height: CyberDimensions.iconMedium,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    final VoidCallback? action = isLoading ? null : onPressed;
    final Widget button = switch (variant) {
      CyberButtonVariant.primary ||
      CyberButtonVariant.danger ||
      CyberButtonVariant.success =>
        icon == null
            ? ElevatedButton(
                style: interactionStyle,
                onPressed: action,
                child: buttonLabel,
              )
            : ElevatedButton.icon(
                style: interactionStyle,
                onPressed: action,
                icon: icon!,
                label: buttonLabel,
              ),
      CyberButtonVariant.secondary =>
        icon == null
            ? OutlinedButton(
                style: interactionStyle,
                onPressed: action,
                child: buttonLabel,
              )
            : OutlinedButton.icon(
                style: interactionStyle,
                onPressed: action,
                icon: icon!,
                label: buttonLabel,
              ),
      CyberButtonVariant.tertiary =>
        icon == null
            ? TextButton(
                style: interactionStyle,
                onPressed: action,
                child: buttonLabel,
              )
            : TextButton.icon(
                style: interactionStyle,
                onPressed: action,
                icon: icon!,
                label: buttonLabel,
              ),
    };

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: SizedBox(width: expand ? double.infinity : null, child: button),
    );
  }
}

class CyberIconButton extends StatelessWidget {
  const CyberIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isSelected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
      isSelected: isSelected,
      mouseCursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
    );
  }
}

class CyberAmbientPointer extends StatefulWidget {
  const CyberAmbientPointer({super.key, required this.child});

  final Widget child;

  @override
  State<CyberAmbientPointer> createState() => _CyberAmbientPointerState();
}

class _CyberAmbientPointerState extends State<CyberAmbientPointer> {
  Offset? _pointerPosition;

  void _updatePointer(PointerHoverEvent event) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final Offset nextPosition = event.localPosition;
    if (_pointerPosition != null &&
        (nextPosition - _pointerPosition!).distanceSquared < 16) {
      return;
    }
    setState(() => _pointerPosition = nextPosition);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Offset? position = _pointerPosition;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget ambient = position == null || reduceMotion
        ? const SizedBox.shrink()
        : AnimatedPositioned(
            duration: CyberMotion.duration(context, CyberMotion.standard),
            curve: CyberMotion.standardCurve,
            left: position.dx - 170,
            top: position.dy - 170,
            child: IgnorePointer(
              child: SizedBox(
                width: 340,
                height: 340,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.secondary.withValues(alpha: 0.035),
                        theme.colorScheme.onSurface.withValues(alpha: 0.018),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
            ),
          );

    return MouseRegion(
      onHover: _updatePointer,
      onExit: (_) {
        if (_pointerPosition != null) setState(() => _pointerPosition = null);
      },
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [widget.child, ambient],
      ),
    );
  }
}

class CyberInput extends StatelessWidget {
  const CyberInput({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class CyberSearchField extends StatelessWidget {
  const CyberSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return CyberInput(
      controller: controller,
      hintText: hintText,
      prefixIcon: const Icon(Icons.search_rounded),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
    );
  }
}

class CyberOtpInput extends StatelessWidget {
  const CyberOtpInput({
    super.key,
    this.controller,
    this.length = 6,
    this.label = 'Verification code',
    this.onChanged,
  });

  final TextEditingController? controller;
  final int length;
  final String label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: length,
      onChanged: onChanged,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }
}

class CyberDropdown<T> extends StatelessWidget {
  const CyberDropdown({
    super.key,
    required this.items,
    this.value,
    this.label,
    this.errorText,
    this.enabled = true,
    this.onChanged,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final String? label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }
}

enum CyberStatus { neutral, safe, success, warning, danger }

class CyberStatusIndicator extends StatelessWidget {
  const CyberStatusIndicator({
    super.key,
    required this.status,
    required this.label,
    this.showIcon = true,
  });

  final CyberStatus status;
  final String label;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (
      Color foreground,
      Color background,
      IconData icon,
    ) = switch (status) {
      CyberStatus.neutral => (
        theme.colorScheme.onSurface,
        theme.colorScheme.surfaceContainerHighest,
        Icons.info_outline_rounded,
      ),
      CyberStatus.safe || CyberStatus.success => (
        CyberColors.success,
        CyberColors.successContainer,
        Icons.check_circle_outline_rounded,
      ),
      CyberStatus.warning => (
        CyberColors.warning,
        CyberColors.warningContainer,
        Icons.warning_amber_rounded,
      ),
      CyberStatus.danger => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer,
        Icons.error_outline_rounded,
      ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CyberSpacing.sm,
          vertical: CyberSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: CyberRadius.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon, size: CyberDimensions.iconSmall, color: foreground),
              CyberSpacing.horizontal(CyberSpacing.xs),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
