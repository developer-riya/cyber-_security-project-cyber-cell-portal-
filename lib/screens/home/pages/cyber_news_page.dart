import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/firebase_service.dart';
import '../../../services/hacker_news_service.dart';
import '../../../services/localization_service.dart';

class CyberNewsPage extends StatelessWidget {
  const CyberNewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 960;

    return ListView(
      children: [
        HeroBanner(
          title: LocalizationService.instance.translate('news_page_title'),
          subtitle: LocalizationService.instance.translate(
            'news_page_subtitle',
          ),
        ),
        const SizedBox(height: 18),
        mobile
            ? const Column(
                children: [
                  RecentNewsCard(),
                  SizedBox(height: 14),
                  HackerNewsCard(),
                  SizedBox(height: 14),
                  CreateNewsCard(),
                ],
              )
            : const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: RecentNewsCard()),
                  SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        HackerNewsCard(),
                        SizedBox(height: 14),
                        CreateNewsCard(),
                      ],
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}

class RecentNewsCard extends StatelessWidget {
  const RecentNewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('news_recent_title'),
      subtitle: LocalizationService.instance.translate('news_recent_subtitle'),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.instance.getCyberNews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final news = snapshot.data ?? [];
          if (news.isEmpty) {
            return Text(LocalizationService.instance.translate('news_empty'));
          }

          return Column(
            children: news
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _NewsTile(
                      headline: item['headline'] ?? 'News Alert',
                      meta: 'By: ${item['author']} - Verified',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class HackerNewsCard extends StatefulWidget {
  const HackerNewsCard({super.key});

  @override
  State<HackerNewsCard> createState() => _HackerNewsCardState();
}

class _HackerNewsCardState extends State<HackerNewsCard> {
  late Future<List<HackerNewsStory>> _storiesFuture;

  @override
  void initState() {
    super.initState();
    _storiesFuture = HackerNewsService.instance.getTopStories();
  }

  void _refreshStories() {
    setState(() {
      _storiesFuture = HackerNewsService.instance.getTopStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('news_hacker_title'),
      subtitle: LocalizationService.instance.translate('news_hacker_subtitle'),
      child: FutureBuilder<List<HackerNewsStory>>(
        future: _storiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.instance.translate('news_hacker_error'),
                ),
                const SizedBox(height: 12),
                ActionChipWidget(
                  label: LocalizationService.instance.translate('retry'),
                  icon: Icons.refresh_rounded,
                  onTap: _refreshStories,
                ),
              ],
            );
          }

          final stories = snapshot.data ?? [];
          if (stories.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.instance.translate('news_hacker_empty'),
                ),
                const SizedBox(height: 12),
                ActionChipWidget(
                  label: LocalizationService.instance.translate('news_refresh'),
                  icon: Icons.refresh_rounded,
                  onTap: _refreshStories,
                ),
              ],
            );
          }

          return Column(
            children: [
              ...stories.map(
                (story) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _NewsTile(
                    headline: story.title,
                    meta:
                        '${story.score} points - ${story.commentCount} comments - by ${story.author}',
                    url: story.storyUrl,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChipWidget(
                  label: LocalizationService.instance.translate('news_refresh'),
                  icon: Icons.refresh_rounded,
                  onTap: _refreshStories,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CreateNewsCard extends StatefulWidget {
  const CreateNewsCard({super.key});

  @override
  State<CreateNewsCard> createState() => _CreateNewsCardState();
}

class _CreateNewsCardState extends State<CreateNewsCard> {
  final _headlineController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitNews() async {
    if (_headlineController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('news_fill_all'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseService.instance.submitNews({
        'headline': _headlineController.text,
        'content': _contentController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('news_submitted'),
            ),
          ),
        );
        _headlineController.clear();
        _contentController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('dashboard_action_failed'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('news_create_title'),
      subtitle: LocalizationService.instance.translate('news_create_subtitle'),
      child: Column(
        children: [
          FieldPlaceholder(
            label: LocalizationService.instance.translate(
              'news_headline_label',
            ),
            controller: _headlineController,
          ),
          const SizedBox(height: 12),
          FieldPlaceholder(
            label: LocalizationService.instance.translate('news_content_label'),
            controller: _contentController,
          ),
          const SizedBox(height: 12),
          ActionChipWidget(
            label: LocalizationService.instance.translate('news_submit_team'),
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            onTap: _submitNews,
          ),
        ],
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.headline, required this.meta, this.url});

  final String headline;
  final String meta;
  final String? url;

  Future<void> _openLink(BuildContext context) async {
    final link = url;
    if (link == null) return;

    final uri = Uri.tryParse(link);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('news_invalid_link'),
          ),
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('news_open_failed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E4A67)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (url != null) ...[
            const SizedBox(width: 10),
            const Icon(
              Icons.open_in_new_rounded,
              color: Color(0xFF3FFFD7),
              size: 18,
            ),
          ],
        ],
      ),
    );

    if (url == null) return tile;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.06),
        focusColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
        onTap: () => _openLink(context),
        child: tile,
      ),
    );
  }
}
