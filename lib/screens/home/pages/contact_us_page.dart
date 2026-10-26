import 'package:flutter/material.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/localization_service.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        HeroBanner(
          title: LocalizationService.instance.translate('contact_page_title'),
          subtitle: LocalizationService.instance.translate(
            'contact_page_subtitle',
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: LocalizationService.instance.translate(
            'contact_options_title',
          ),
          subtitle: LocalizationService.instance.translate(
            'contact_options_subtitle',
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'contact_call_team',
                ),
                icon: Icons.call_rounded,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'contact_collaborate',
                ),
                icon: Icons.handshake_rounded,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'contact_investment',
                ),
                icon: Icons.trending_up_rounded,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate('contact_help'),
                icon: Icons.support_agent_rounded,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'contact_company',
                ),
                icon: Icons.apartment_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: LocalizationService.instance.translate(
            'contact_helpline_title',
          ),
          subtitle: LocalizationService.instance.translate(
            'contact_helpline_subtitle',
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'emergency_ambulance',
                ),
                icon: Icons.emergency,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate(
                  'emergency_cyber_cell',
                ),
                icon: Icons.local_police,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate('contact_fire'),
                icon: Icons.local_fire_department,
              ),
              ActionChipWidget(
                label: LocalizationService.instance.translate('contact_team'),
                icon: Icons.support_agent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
