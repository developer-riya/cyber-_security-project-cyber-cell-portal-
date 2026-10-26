import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../services/localization_service.dart';
import 'ai_chatbot.dart';

class CyberSmartAssistant extends StatelessWidget {
  const CyberSmartAssistant({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  void _open(BuildContext context) {
    final BuildContext hostContext = context;
    final bool mobile = MediaQuery.sizeOf(context).width < 600;
    if (mobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: CyberMotion.standard,
                reverseDuration: CyberMotion.fast,
                curve: CyberMotion.standardCurve,
                reverseCurve: Curves.easeInCubic,
              ),
        builder: (panelContext) => _AssistantPanel(
          mobile: true,
          onNavigate: (index) {
            Navigator.of(panelContext).pop();
            onNavigate(index);
          },
          onAsk: () {
            Navigator.of(panelContext).pop();
            _openChat(thisContext: hostContext);
          },
        ),
      );
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: LocalizationService.instance.translate('assistant_close'),
      barrierColor: Colors.transparent,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : CyberMotion.standard,
      pageBuilder: (dialogContext, animation, secondaryAnimation) => SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(
              right: CyberSpacing.lg,
              bottom: CyberSpacing.lg,
            ),
            child: SizedBox(
              width: 368,
              height: 560,
              child: _AssistantPanel(
                onNavigate: (index) {
                  Navigator.of(dialogContext).pop();
                  onNavigate(index);
                },
                onAsk: () {
                  Navigator.of(dialogContext).pop();
                  _openChat(thisContext: hostContext);
                },
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: CyberMotion.standardCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            alignment: Alignment.bottomRight,
            child: child,
          ),
        );
      },
    );
  }

  void _openChat({required BuildContext thisContext}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!thisContext.mounted) return;
      showModalBottomSheet<void>(
        context: thisContext,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AiChatbot(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String tooltip = LocalizationService.instance.translate(
      'assistant_open',
    );
    return Semantics(
      button: true,
      label: tooltip,
      child: FloatingActionButton(
        heroTag: 'cyber-uday-smart-assistant',
        tooltip: tooltip,
        onPressed: () => _open(context),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 1,
        child: const Icon(Icons.shield_moon_rounded),
      ),
    );
  }
}

class _AssistantPanel extends StatelessWidget {
  const _AssistantPanel({
    required this.onNavigate,
    required this.onAsk,
    this.mobile = false,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onAsk;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LocalizationService localization = LocalizationService.instance;
    final Widget panel = Material(
      color: theme.colorScheme.surface,
      borderRadius: CyberRadius.largeRadius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: CyberRadius.largeRadius,
          boxShadow: CyberElevation.raised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CyberSpacing.md,
                CyberSpacing.md,
                CyberSpacing.xs,
                CyberSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: CyberRadius.standardRadius,
                    ),
                    child: Icon(
                      Icons.shield_moon_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  CyberSpacing.horizontal(CyberSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.translate('assistant_title'),
                          style: theme.textTheme.titleMedium,
                        ),
                        CyberSpacing.vertical(CyberSpacing.xxs),
                        Text(
                          localization.translate('assistant_subtitle'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.64,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: localization.translate('assistant_close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CyberSpacing.md,
                CyberSpacing.md,
                CyberSpacing.md,
                CyberSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  localization.translate('assistant_prompt'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: CyberSpacing.sm),
                child: Column(
                  children: [
                    _AssistantAction(
                      icon: Icons.link_rounded,
                      label: localization.translate('assistant_check_link'),
                      onTap: () => onNavigate(1),
                    ),
                    _AssistantAction(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: localization.translate('assistant_scammed'),
                      onTap: () => onNavigate(3),
                    ),
                    _AssistantAction(
                      icon: Icons.account_balance_outlined,
                      label: localization.translate('assistant_bank_security'),
                      onTap: () => onNavigate(4),
                    ),
                    _AssistantAction(
                      icon: Icons.phonelink_lock_outlined,
                      label: localization.translate('assistant_phone_hacked'),
                      onTap: () => onNavigate(6),
                    ),
                    _AssistantAction(
                      icon: Icons.emergency_outlined,
                      label: localization.translate('assistant_emergency'),
                      onTap: () => onNavigate(2),
                    ),
                    _AssistantAction(
                      icon: Icons.campaign_outlined,
                      label: localization.translate('assistant_report_crime'),
                      onTap: () => onNavigate(3),
                    ),
                    _AssistantAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: localization.translate('assistant_ask'),
                      onTap: onAsk,
                    ),
                  ],
                ),
              ),
            ),
            if (mobile) CyberSpacing.vertical(CyberSpacing.xs),
          ],
        ),
      ),
    );
    return mobile
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: panel,
          )
        : panel;
  }
}

class _AssistantAction extends StatelessWidget {
  const _AssistantAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CyberSettingsRow(
      icon: icon,
      title: label,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      semanticLabel: label,
    );
  }
}
