import 'package:flutter/material.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/localization_service.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 960;

    return ListView(
      children: [
        HeroBanner(
          title: LocalizationService.instance.translate('rewards_page_title'),
          subtitle: LocalizationService.instance.translate(
            'rewards_page_subtitle',
          ),
        ),
        const SizedBox(height: 18),
        mobile
            ? const Column(
                children: [
                  RewardsStatusCard(),
                  SizedBox(height: 14),
                  PremiumFeaturesCard(),
                ],
              )
            : const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: RewardsStatusCard()),
                  SizedBox(width: 14),
                  Expanded(child: PremiumFeaturesCard()),
                ],
              ),
      ],
    );
  }
}

class RewardsStatusCard extends StatelessWidget {
  const RewardsStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('rewards_status_title'),
      subtitle: LocalizationService.instance.translate(
        'rewards_status_subtitle',
      ),
      child: Column(
        children: [
          _MetricStrip(
            label: LocalizationService.instance.translate('rewards_balance'),
            value: '142 coins',
          ),
          SizedBox(height: 10),
          _MetricStrip(
            label: LocalizationService.instance.translate('rewards_points'),
            value: LocalizationService.instance.translate('rewards_ready'),
          ),
          SizedBox(height: 10),
          _MetricStrip(
            label: LocalizationService.instance.translate('rewards_challenge'),
            value: '2/5 done',
          ),
        ],
      ),
    );
  }
}

class PremiumFeaturesCard extends StatelessWidget {
  const PremiumFeaturesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('rewards_premium_title'),
      subtitle: LocalizationService.instance.translate(
        'rewards_premium_subtitle',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LocalizationService.instance.translate('rewards_team_support')),
          SizedBox(height: 10),
          Text(LocalizationService.instance.translate('rewards_guidance')),
          SizedBox(height: 10),
          Text(LocalizationService.instance.translate('rewards_escalation')),
          SizedBox(height: 14),
          ActionChipWidget(
            label: LocalizationService.instance.translate('rewards_claim'),
            icon: Icons.redeem_rounded,
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E4A67)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF3FFFD7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
