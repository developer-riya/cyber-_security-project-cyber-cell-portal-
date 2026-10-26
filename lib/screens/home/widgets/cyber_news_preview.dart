import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cyber_design_system.dart';
import '../../../services/hacker_news_service.dart';
import '../../../services/localization_service.dart';

class CyberNewsPreview extends StatefulWidget {
  const CyberNewsPreview({
    super.key,
    required this.onViewAll,
    this.storiesFuture,
  });

  final VoidCallback onViewAll;
  final Future<List<HackerNewsStory>>? storiesFuture;

  @override
  State<CyberNewsPreview> createState() => _CyberNewsPreviewState();
}

class _CyberNewsPreviewState extends State<CyberNewsPreview> {
  late Future<List<HackerNewsStory>> _storiesFuture;

  @override
  void initState() {
    super.initState();
    _storiesFuture =
        widget.storiesFuture ??
        HackerNewsService.instance.getTopStories(limit: 3);
  }

  @override
  void didUpdateWidget(CyberNewsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storiesFuture != oldWidget.storiesFuture &&
        widget.storiesFuture != null) {
      _storiesFuture = widget.storiesFuture!;
    }
  }

  void _refresh() {
    setState(() {
      _storiesFuture = HackerNewsService.instance.getTopStories(limit: 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      variant: CyberCardVariant.standard,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CyberSpacing.md,
              CyberSpacing.md,
              CyberSpacing.sm,
              CyberSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.instance.translate(
                          'dashboard_latest_news_title',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      CyberSpacing.vertical(CyberSpacing.xxs),
                      Text(
                        LocalizationService.instance.translate(
                          'dashboard_latest_news_subtitle',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  child: Text(
                    LocalizationService.instance.translate(
                      'dashboard_view_all',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          FutureBuilder<List<HackerNewsStory>>(
            future: _storiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _PreviewMessage(
                  icon: Icons.sync_rounded,
                  message: LocalizationService.instance.translate(
                    'dashboard_latest_news_loading',
                  ),
                  showProgress: true,
                );
              }

              if (snapshot.hasError) {
                return _PreviewMessage(
                  icon: Icons.cloud_off_rounded,
                  message: LocalizationService.instance.translate(
                    'dashboard_latest_news_error',
                  ),
                  actionLabel: LocalizationService.instance.translate('retry'),
                  onAction: _refresh,
                );
              }

              final List<HackerNewsStory> stories = snapshot.data ?? const [];
              if (stories.isEmpty) {
                return _PreviewMessage(
                  icon: Icons.newspaper_outlined,
                  message: LocalizationService.instance.translate(
                    'dashboard_latest_news_empty',
                  ),
                  actionLabel: LocalizationService.instance.translate('retry'),
                  onAction: _refresh,
                );
              }

              return Column(
                children: [
                  for (int index = 0; index < stories.length; index++) ...[
                    _NewsPreviewRow(story: stories[index]),
                    if (index < stories.length - 1)
                      Divider(
                        height: 1,
                        indent: CyberSpacing.md,
                        endIndent: CyberSpacing.md,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CyberSpacing.md),
      child: Row(
        children: [
          if (showProgress)
            const SizedBox(
              width: CyberDimensions.iconMedium,
              height: CyberDimensions.iconMedium,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              icon,
              color: Theme.of(context).colorScheme.secondary,
              size: CyberDimensions.iconMedium,
            ),
          CyberSpacing.horizontal(CyberSpacing.sm),
          Expanded(child: Text(message)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _NewsPreviewRow extends StatelessWidget {
  const _NewsPreviewRow({required this.story});

  final HackerNewsStory story;

  Future<void> _openStory(BuildContext context) async {
    final bool opened = await launchUrl(
      Uri.parse(story.storyUrl),
      mode: LaunchMode.platformDefault,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate(
              'dashboard_latest_news_open_failed',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime localTime = story.time.toLocal();
    final String date =
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: story.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => _openStory(context),
          borderRadius: CyberRadius.standardRadius,
          hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
          focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
          highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CyberSpacing.md,
              vertical: CyberSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: CyberRadius.smallRadius,
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    size: CyberDimensions.iconMedium,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                CyberSpacing.horizontal(CyberSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      CyberSpacing.vertical(CyberSpacing.xxs),
                      Text(
                        date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.64,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CyberSpacing.horizontal(CyberSpacing.xs),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: CyberDimensions.iconMedium,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
