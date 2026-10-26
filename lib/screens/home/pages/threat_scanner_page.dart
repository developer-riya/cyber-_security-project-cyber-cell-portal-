import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/cyber_design_system.dart';
import '../../../models/incoming_share_payload.dart';
import '../../../models/threat_analysis.dart';
import '../../../models/cyber_risk_signal.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/localization_service.dart';
import '../../../services/manual_file_upload_service.dart';
import '../../../services/share_threat_analysis_service.dart';
import '../../../services/threat_analysis_engine.dart';
import '../../share_to_scan_screen.dart';
import '../widgets/home_shared_widgets.dart';

class ThreatScannerPage extends StatefulWidget {
  const ThreatScannerPage({super.key, this.incomingShare, this.uploadService});

  final IncomingSharePayload? incomingShare;
  final ManualFileUploadService? uploadService;

  @override
  State<ThreatScannerPage> createState() => _ThreatScannerPageState();
}

class _ThreatScannerPageState extends State<ThreatScannerPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _appController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ThreatAnalysisEngine _analysisEngine = const ThreatAnalysisEngine();
  late final ManualFileUploadService _uploadService;
  ShareThreatAnalysis? _shareAnalysis;
  ThreatAnalysisResult? _analysisResult;
  ThreatAnalysisStage _analysisStage = ThreatAnalysisStage.receiving;
  bool _isSubmitting = false;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _uploadService = widget.uploadService ?? ManualFileUploadService();
    _applyIncomingShare();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _appController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyIncomingShare() {
    final IncomingSharePayload? payload = widget.incomingShare;
    if (payload == null) return;

    if (payload.urls.isNotEmpty) {
      _urlController.text = payload.urls.first;
    } else if (payload.text != null) {
      _noteController.text = payload.text!;
    }

    if (payload.attachments.isNotEmpty) {
      final String attachments = payload.attachments
          .map((attachment) => attachment.displayName)
          .join(', ');
      _noteController.text = _noteController.text.isEmpty
          ? 'Shared attachment: $attachments'
          : '${_noteController.text}\nShared attachment: $attachments';
    }
    _runIncomingAnalysis();
  }

  Future<void> _runIncomingAnalysis() async {
    final IncomingSharePayload? payload = widget.incomingShare;
    if (payload == null) return;
    if (mounted) {
      setState(() {
        _shareAnalysis = null;
        _analysisResult = null;
        _analysisStage = ThreatAnalysisStage.receiving;
      });
    }
    final ThreatAnalysisRun run = await _analysisEngine.analyze(
      payload,
      onStage: (stage) {
        if (mounted) setState(() => _analysisStage = stage);
      },
    );
    if (!mounted) return;
    setState(() {
      _shareAnalysis = run.analysis;
      _analysisResult = run.result;
    });
  }

  Future<void> _reanalyzeIncomingShare() => _runIncomingAnalysis();

  Future<void> _pickFiles({required bool apkOnly}) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final IncomingSharePayload? payload = await _uploadService.pickFiles(
        apkOnly: apkOnly,
      );
      if (!mounted || payload == null) return;
      try {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShareToScanScreen(payload: payload),
          ),
        );
      } finally {
        _uploadService.releasePayload(payload);
      }
    } on ManualFilePickerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cyber Uday could not open the file chooser.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _submitThreat() async {
    if (_urlController.text.isEmpty &&
        _appController.text.isEmpty &&
        _noteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('scanner_fill_one'),
          ),
        ),
      );
      return;
    }

    if (_urlController.text.trim().isNotEmpty) {
      setState(() {
        _shareAnalysis = null;
        _analysisResult = null;
        _analysisStage = ThreatAnalysisStage.receiving;
      });
      final ThreatAnalysisRun run = await _analysisEngine.analyze(
        IncomingSharePayload.fromManualUrl(
          _urlController.text,
          note: _noteController.text,
        ),
        onStage: (stage) {
          if (mounted) setState(() => _analysisStage = stage);
        },
      );
      if (!mounted) return;
      setState(() {
        _shareAnalysis = run.analysis;
        _analysisResult = run.result;
      });
    }

    if (AuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign in to save this scan or create a report. Your shared item remains on this screen.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseService.instance.submitThreat({
        'headline': 'Threat Scan Request',
        'source': widget.incomingShare == null
            ? 'Scanner Page'
            : 'Android Share Target',
        'url': _urlController.text,
        'appName': _appController.text,
        'note': _noteController.text,
        if (widget.incomingShare != null)
          'sharedMimeType': widget.incomingShare!.mimeType,
        if (widget.incomingShare != null)
          'sharedAttachmentCount': widget.incomingShare!.attachments.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('scanner_submitted'),
            ),
          ),
        );
        _urlController.clear();
        _appController.clear();
        _noteController.clear();
      }
    } catch (_) {
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
    final bool fromShare = widget.incomingShare != null;
    return ListView(
      padding: CyberSpacing.pagePadding,
      children: [
        HeroBanner(
          title: fromShare
              ? 'Shared content ready to check'
              : LocalizationService.instance.translate('scanner_page_title'),
          subtitle: fromShare
              ? 'Cyber Uday is reviewing the item you explicitly shared. No link or file is opened automatically.'
              : LocalizationService.instance.translate('scanner_page_subtitle'),
        ),
        if (fromShare && _analysisResult == null) ...[
          CyberSpacing.vertical(CyberSpacing.lg),
          _AnalysisProgressCard(stage: _analysisStage),
        ],
        if (_shareAnalysis != null && _analysisResult != null) ...[
          CyberSpacing.vertical(CyberSpacing.lg),
          _ShareAnalysisCard(
            analysis: _shareAnalysis!,
            result: _analysisResult!,
            onAnalyzeAgain: _reanalyzeIncomingShare,
          ),
          if (fromShare) ...[
            CyberSpacing.vertical(CyberSpacing.md),
            _ShareAssistantCard(
              payload: widget.incomingShare!,
              analysis: _shareAnalysis!,
              result: _analysisResult!,
            ),
          ],
        ],
        CyberSpacing.vertical(CyberSpacing.lg),
        SectionCard(
          title: LocalizationService.instance.translate('scanner_submit_title'),
          subtitle: fromShare
              ? 'Review the received details before saving a report. Saving requires sign-in.'
              : LocalizationService.instance.translate(
                  'scanner_submit_subtitle',
                ),
          child: Column(
            children: [
              FieldPlaceholder(
                label: LocalizationService.instance.translate(
                  'scanner_link_label',
                ),
                controller: _urlController,
              ),
              const SizedBox(height: 12),
              FieldPlaceholder(
                label: LocalizationService.instance.translate(
                  'scanner_app_label',
                ),
                controller: _appController,
              ),
              const SizedBox(height: 12),
              FieldPlaceholder(
                label: LocalizationService.instance.translate(
                  'scanner_note_label',
                ),
                controller: _noteController,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose content from this device',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionChipWidget(
                    label: 'Upload APK',
                    icon: Icons.android_rounded,
                    onTap: _isPicking ? null : () => _pickFiles(apkOnly: true),
                  ),
                  ActionChipWidget(
                    label: 'Upload file',
                    icon: Icons.upload_file_rounded,
                    onTap: _isPicking ? null : () => _pickFiles(apkOnly: false),
                  ),
                  if (fromShare)
                    ActionChipWidget(
                      label: 'Analyze shared item',
                      icon: Icons.search_rounded,
                      onTap: _reanalyzeIncomingShare,
                    ),
                  ActionChipWidget(
                    label: LocalizationService.instance.translate(
                      'scanner_submit',
                    ),
                    icon: Icons.verified_user_outlined,
                    isLoading: _isSubmitting,
                    onTap: _submitThreat,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareAssistantCard extends StatelessWidget {
  const _ShareAssistantCard({
    required this.payload,
    required this.analysis,
    required this.result,
  });

  final IncomingSharePayload payload;
  final ShareThreatAnalysis analysis;
  final ThreatAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CyberCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_moon_rounded,
                color: theme.colorScheme.secondary,
              ),
              CyberSpacing.horizontal(CyberSpacing.xs),
              Text('Cyber Uday Assistant', style: theme.textTheme.titleMedium),
            ],
          ),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(
            'This ${payload.primaryType.label.toLowerCase()} stays in this scanner. It is not sent to external AI automatically.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          CyberSpacing.vertical(CyberSpacing.sm),
          Wrap(
            spacing: CyberSpacing.sm,
            runSpacing: CyberSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showWhy(context),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('Why is it suspicious?'),
              ),
              TextButton.icon(
                onPressed: () => _showNextSteps(context),
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('What should I do?'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWhy(BuildContext context) {
    final List<String> indicators = result.evidence;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Why this result?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(analysis.message),
              if (indicators.isNotEmpty) ...[
                CyberSpacing.vertical(CyberSpacing.sm),
                for (final String indicator in indicators)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CyberSpacing.xs),
                    child: Text('- $indicator'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNextSteps(BuildContext context) {
    final bool highRisk =
        result.verdict == ThreatVerdict.high ||
        result.verdict == ThreatVerdict.critical ||
        result.verdict == ThreatVerdict.medium;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What to do next'),
        content: Text(
          highRisk
              ? 'Do not open the link or file. Do not reply with passwords, OTPs, or banking details. Verify the sender through a trusted contact method, then save a report below if you need help.'
              : 'Treat this as a preliminary result only. Verify the sender independently and do not share passwords, OTPs, or banking details. You can save a report below if something still feels wrong.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

class _ShareAnalysisCard extends StatelessWidget {
  const _ShareAnalysisCard({
    required this.analysis,
    required this.result,
    required this.onAnalyzeAgain,
  });

  final ShareThreatAnalysis analysis;
  final ThreatAnalysisResult result;
  final VoidCallback onAnalyzeAgain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CyberRiskSignal signal = CyberRiskSignal.fromResult(result);
    final (
      CyberCardVariant variant,
      CyberStatus status,
      String statusLabel,
    ) = switch (signal.level) {
      CyberRiskLevel.low => (
        CyberCardVariant.status,
        CyberStatus.safe,
        signal.label,
      ),
      CyberRiskLevel.caution => (
        CyberCardVariant.standard,
        CyberStatus.warning,
        signal.label,
      ),
      CyberRiskLevel.high || CyberRiskLevel.critical => (
        CyberCardVariant.criticalAlert,
        CyberStatus.danger,
        signal.label,
      ),
      CyberRiskLevel.unknown => (
        CyberCardVariant.standard,
        CyberStatus.neutral,
        signal.label,
      ),
    };

    return CyberCard(
      variant: variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CyberStatusIndicator(status: status, label: statusLabel),
          CyberSpacing.vertical(CyberSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(signal.label, style: theme.textTheme.headlineSmall),
              ),
              Text(
                '${signal.score} / 100',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(signal.explanation, style: theme.textTheme.bodyMedium),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(analysis.title, style: theme.textTheme.titleLarge),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(analysis.message, style: theme.textTheme.bodyMedium),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(
            'Path: ${analysis.analyzerName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(
            'Initial analysis • ${result.durationMs} ms',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          if (analysis.indicators.isNotEmpty) ...[
            CyberSpacing.vertical(CyberSpacing.md),
            Text(
              result.verdict == ThreatVerdict.unknown
                  ? 'WHY THIS RESULT'
                  : 'WHY WE FLAGGED IT',
              style: theme.textTheme.titleSmall,
            ),
            CyberSpacing.vertical(CyberSpacing.xs),
            for (final String indicator in analysis.indicators)
              Padding(
                padding: const EdgeInsets.only(bottom: CyberSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: theme.colorScheme.secondary,
                    ),
                    CyberSpacing.horizontal(CyberSpacing.xs),
                    Expanded(
                      child: Text(indicator, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
          if (result.structuredEvidence.isNotEmpty) ...[
            CyberSpacing.vertical(CyberSpacing.sm),
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'View technical analysis',
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  for (final MapEntry<String, List<String>> category
                      in result.structuredEvidence.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CyberSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.key,
                            style: theme.textTheme.labelMedium,
                          ),
                          for (final String item in category.value)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: CyberSpacing.xxs,
                              ),
                              child: Text(
                                '- $item',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (analysis.recommendations.isNotEmpty) ...[
            CyberSpacing.vertical(CyberSpacing.sm),
            Text('WHAT YOU SHOULD DO', style: theme.textTheme.titleSmall),
            CyberSpacing.vertical(CyberSpacing.xs),
            for (final String recommendation in analysis.recommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: CyberSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    CyberSpacing.horizontal(CyberSpacing.xs),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            CyberSpacing.vertical(CyberSpacing.sm),
            Text(
              signal.recommendedAction,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (kDebugMode)
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Development details'),
                children: [
                  _DevelopmentDetail(
                    label: 'Request ID',
                    value: result.requestId,
                  ),
                  _DevelopmentDetail(
                    label: 'Detected type',
                    value: result.detectedType?.label ?? 'Not available',
                  ),
                  _DevelopmentDetail(
                    label: 'SHA-256',
                    value: result.sha256 ?? 'Not available for this reference',
                  ),
                  _DevelopmentDetail(
                    label: 'Processing time',
                    value: '${result.durationMs} ms',
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAnalyzeAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Analyze again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisProgressCard extends StatelessWidget {
  const _AnalysisProgressCard({required this.stage});

  final ThreatAnalysisStage stage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ThreatAnalysisStage> stages = ThreatAnalysisStage.values;
    final int currentIndex = stages.indexOf(stage);
    return CyberCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.secondary,
                ),
              ),
              CyberSpacing.horizontal(CyberSpacing.sm),
              Text(
                'Cyber Uday is analyzing this item...',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          CyberSpacing.vertical(CyberSpacing.sm),
          Text(
            _stageLabel(stage),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          CyberSpacing.vertical(CyberSpacing.sm),
          LinearProgressIndicator(
            value: (currentIndex + 1) / stages.length,
            color: theme.colorScheme.secondary,
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
          CyberSpacing.vertical(CyberSpacing.xs),
          Text(
            'First-pass analysis is bounded and will never treat a timeout as safe.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }

  static String _stageLabel(ThreatAnalysisStage stage) => switch (stage) {
    ThreatAnalysisStage.receiving => 'Receiving content',
    ThreatAnalysisStage.identifying => 'Identifying content type',
    ThreatAnalysisStage.extractingIndicators => 'Extracting indicators',
    ThreatAnalysisStage.checkingThreats => 'Checking threats',
    ThreatAnalysisStage.calculatingRisk => 'Calculating risk',
    ThreatAnalysisStage.preparingResult => 'Preparing result',
  };
}

class _DevelopmentDetail extends StatelessWidget {
  const _DevelopmentDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: CyberSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
