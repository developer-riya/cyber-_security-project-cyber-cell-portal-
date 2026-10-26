import 'package:flutter/material.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/firebase_service.dart';
import '../../../services/pdf_service.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/ai_chatbot.dart';

class ReportCrimePage extends StatefulWidget {
  const ReportCrimePage({super.key});

  @override
  State<ReportCrimePage> createState() => _ReportCrimePageState();
}

class _ReportCrimePageState extends State<ReportCrimePage> {
  final _descController = TextEditingController();
  final _timelineController = TextEditingController();
  final _evidenceController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic>? _lastGeneratedData;

  @override
  void dispose() {
    _descController.dispose();
    _timelineController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _submitReport(String destination) async {
    if (_descController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('report_describe_first'),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    final reportData = {
      'type': 'Cybercrime Report',
      'description': _descController.text,
      'timeline': _timelineController.text,
      'evidence': _evidenceController.text,
      'destination': destination,
    };

    try {
      final id = await FirebaseService.instance.submitReport(reportData);

      if (mounted) {
        setState(() {
          _lastGeneratedData = {'id': id, ...reportData};
          _descController.clear();
          _timelineController.clear();
          _evidenceController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translateWith(
                'report_submitted',
                <String, String>{'destination': destination},
              ),
            ),
          ),
        );
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _generatePdf() {
    if (_lastGeneratedData == null) {
      if (_descController.text.isNotEmpty) {
        _lastGeneratedData = {
          'id': 'Draft',
          'type': 'Cybercrime Draft',
          'description': _descController.text,
          'timeline': _timelineController.text,
          'evidence': _evidenceController.text,
        };
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('report_fill_first'),
            ),
          ),
        );
        return;
      }
    }
    PdfService.generateReportPdf(_lastGeneratedData!);
  }

  void _openAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiChatbot(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        HeroBanner(
          title: LocalizationService.instance.translate('report_page_title'),
          subtitle: LocalizationService.instance.translate(
            'report_page_subtitle',
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: LocalizationService.instance.translate(
            'report_workflow_title',
          ),
          subtitle: LocalizationService.instance.translate(
            'report_workflow_subtitle',
          ),
          child: Column(
            children: [
              FieldPlaceholder(
                label: LocalizationService.instance.translate(
                  'report_description_label',
                ),
                controller: _descController,
              ),
              const SizedBox(height: 12),
              FieldPlaceholder(
                label: LocalizationService.instance.translate(
                  'report_timeline_label',
                ),
                controller: _timelineController,
              ),
              const SizedBox(height: 12),
              FieldPlaceholder(
                label: LocalizationService.instance.translate(
                  'report_evidence_label',
                ),
                controller: _evidenceController,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionChipWidget(
                    label: LocalizationService.instance.translate(
                      'report_chat_ai',
                    ),
                    icon: Icons.auto_awesome,
                    onTap: _openAiAssistant,
                  ),
                  ActionChipWidget(
                    label: LocalizationService.instance.translate(
                      'report_generate_pdf',
                    ),
                    icon: Icons.description_rounded,
                    onTap: _generatePdf,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: LocalizationService.instance.translate(
            'report_destination_title',
          ),
          subtitle: LocalizationService.instance.translate(
            'report_destination_subtitle',
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'report_submit_team',
                ),
                icon: Icons.support_agent_rounded,
                isLoading: _isSubmitting,
                onTap: () => _submitReport('Cyber Uday Team'),
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'report_submit_cell',
                ),
                icon: Icons.local_police_rounded,
                isLoading: _isSubmitting,
                onTap: () => _submitReport('Cyber Cell'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
