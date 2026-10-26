import 'package:flutter/material.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/localization_service.dart';

class ScanSystemPage extends StatelessWidget {
  const ScanSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;

    return ListView(
      children: [
        HeroBanner(
          title: LocalizationService.instance.translate('scan_page_title'),
          subtitle: LocalizationService.instance.translate(
            'scan_page_subtitle',
          ),
        ),
        const SizedBox(height: 18),
        mobile
            ? const Column(
                children: [
                  MobileScanCard(),
                  SizedBox(height: 14),
                  ComputerScanCard(),
                ],
              )
            : const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: MobileScanCard()),
                  SizedBox(width: 14),
                  Expanded(child: ComputerScanCard()),
                ],
              ),
      ],
    );
  }
}

class MobileScanCard extends StatelessWidget {
  const MobileScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('scan_mobile_title'),
      subtitle: LocalizationService.instance.translate('scan_mobile_subtitle'),
      child: ActionChipWidget(
        label: LocalizationService.instance.translate('scan_mobile_action'),
        icon: Icons.phone_android_rounded,
      ),
    );
  }
}

class ComputerScanCard extends StatelessWidget {
  const ComputerScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: LocalizationService.instance.translate('scan_computer_title'),
      subtitle: LocalizationService.instance.translate(
        'scan_computer_subtitle',
      ),
      child: ActionChipWidget(
        label: LocalizationService.instance.translate('scan_computer_action'),
        icon: Icons.computer_rounded,
      ),
    );
  }
}
