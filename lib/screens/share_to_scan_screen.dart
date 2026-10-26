import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../models/incoming_share_payload.dart';
import 'auth_gate.dart';
import 'home/pages/threat_scanner_page.dart';

/// Review surface shown only after a person explicitly shares content with
/// Cyber Uday. It does not open a link or attachment on the user's behalf.
class ShareToScanScreen extends StatelessWidget {
  const ShareToScanScreen({super.key, required this.payload});

  final IncomingSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool multiple = payload.isMultiple;
    final bool manualUpload =
        payload.sourceApplication == 'Cyber Uday file picker';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cyber Uday'),
        leading: IconButton(
          tooltip: 'Not now',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _dismiss(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: CyberSpacing.pagePadding,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: CyberDimensions.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: CyberRadius.standardRadius,
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      CyberSpacing.horizontal(CyberSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Let\'s check this before you open it.',
                              style: theme.textTheme.titleLarge,
                            ),
                            CyberSpacing.vertical(CyberSpacing.xxs),
                            CyberStatusIndicator(
                              status: CyberStatus.neutral,
                              label: manualUpload
                                  ? 'Selected from device'
                                  : 'Received from Share',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  CyberSpacing.vertical(CyberSpacing.xl),
                  CyberCard(
                    variant: CyberCardVariant.elevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          multiple
                              ? '${payload.attachments.length} items received'
                              : payload.displayTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        CyberSpacing.vertical(CyberSpacing.xs),
                        Text(
                          manualUpload
                              ? 'Cyber Uday only received the item you selected. It has not opened, executed, or uploaded anything.'
                              : 'Cyber Uday only received the item you chose to share. It has not opened, executed, or uploaded anything.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                        CyberSpacing.vertical(CyberSpacing.lg),
                        if (payload.text != null)
                          _SharedTextPreview(payload: payload),
                        if (payload.text != null &&
                            payload.attachments.isNotEmpty)
                          CyberSpacing.vertical(CyberSpacing.sm),
                        for (final IncomingShareAttachment attachment
                            in payload.attachments) ...[
                          _SharedAttachmentRow(attachment: attachment),
                          if (attachment != payload.attachments.last)
                            const Divider(height: CyberSpacing.lg),
                        ],
                      ],
                    ),
                  ),
                  CyberSpacing.vertical(CyberSpacing.lg),
                  CyberButton(
                    label: 'Analyze safely',
                    icon: const Icon(Icons.search_rounded),
                    expand: true,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            _SharedThreatScannerScreen(payload: payload),
                      ),
                    ),
                  ),
                  CyberSpacing.vertical(CyberSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: () => _dismiss(context),
                      child: const Text('Not now'),
                    ),
                  ),
                  CyberSpacing.vertical(CyberSpacing.sm),
                  Text(
                    'This preliminary check is local. It does not monitor other apps or open shared links and files automatically.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismiss(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }
}

class _SharedThreatScannerScreen extends StatelessWidget {
  const _SharedThreatScannerScreen({required this.payload});

  final IncomingSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Threat Scanner')),
      body: SafeArea(child: ThreatScannerPage(incomingShare: payload)),
    );
  }
}

class _SharedTextPreview extends StatelessWidget {
  const _SharedTextPreview({required this.payload});

  final IncomingSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String preview = payload.primaryType == IncomingShareContentType.link
        ? payload.urls.first
        : payload.text!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CyberSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: CyberRadius.standardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type: ${payload.primaryType.label}',
            style: theme.textTheme.labelMedium,
          ),
          CyberSpacing.vertical(CyberSpacing.xs),
          SelectableText(
            preview,
            maxLines: 5,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SharedAttachmentRow extends StatelessWidget {
  const _SharedAttachmentRow({required this.attachment});

  final IncomingShareAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _iconFor(attachment.contentType),
          color: theme.colorScheme.secondary,
        ),
        CyberSpacing.horizontal(CyberSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(attachment.displayName, style: theme.textTheme.titleMedium),
              CyberSpacing.vertical(CyberSpacing.xxs),
              Text(
                'Type: ${attachment.contentType.label}${_sizeLabel(attachment.sizeBytes)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
              if (!attachment.isAccessible || attachment.error != null) ...[
                CyberSpacing.vertical(CyberSpacing.xxs),
                Text(
                  attachment.error ??
                      'Cyber Uday could not access this shared file. Please try sharing it again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(IncomingShareContentType type) => switch (type) {
    IncomingShareContentType.image => Icons.image_outlined,
    IncomingShareContentType.pdf => Icons.picture_as_pdf_outlined,
    IncomingShareContentType.document => Icons.description_outlined,
    IncomingShareContentType.link => Icons.link_rounded,
    IncomingShareContentType.message => Icons.chat_bubble_outline_rounded,
    IncomingShareContentType.apk => Icons.android_rounded,
    IncomingShareContentType.archive => Icons.folder_zip_outlined,
    IncomingShareContentType.audio => Icons.audio_file_outlined,
    IncomingShareContentType.video => Icons.video_file_outlined,
    IncomingShareContentType.executable => Icons.warning_amber_rounded,
    IncomingShareContentType.script => Icons.code_rounded,
    IncomingShareContentType.unsupported => Icons.insert_drive_file_outlined,
  };

  static String _sizeLabel(int? bytes) {
    if (bytes == null || bytes < 0) return '';
    if (bytes < 1024) return ' • $bytes B';
    if (bytes < 1024 * 1024) {
      return ' • ${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return ' • ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
