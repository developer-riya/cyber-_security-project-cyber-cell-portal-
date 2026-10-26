import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/localization_service.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 900;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HeroBanner(
          title: LocalizationService.instance.translate('emergency_page_title'),
          subtitle: LocalizationService.instance.translate(
            'emergency_page_subtitle',
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              [
                    _EmergencyCard(
                      title: LocalizationService.instance.translate(
                        'emergency_police',
                      ),
                      number: '100',
                      icon: Icons.local_police_rounded,
                      color: Colors.blueAccent,
                      onTap: () => _makePhoneCall('100'),
                    ),
                    _EmergencyCard(
                      title: LocalizationService.instance.translate(
                        'emergency_ambulance',
                      ),
                      number: '102',
                      icon: Icons.medical_services_rounded,
                      color: Colors.redAccent,
                      onTap: () => _makePhoneCall('102'),
                    ),
                    _EmergencyCard(
                      title: LocalizationService.instance.translate(
                        'emergency_fire',
                      ),
                      number: '101',
                      icon: Icons.fire_truck_rounded,
                      color: Colors.orangeAccent,
                      onTap: () => _makePhoneCall('101'),
                    ),
                    _EmergencyCard(
                      title: LocalizationService.instance.translate(
                        'emergency_cyber_cell',
                      ),
                      number: '1930',
                      icon: Icons.security_rounded,
                      color: const Color(0xFF3FFFD7),
                      onTap: () => _makePhoneCall('1930'),
                    ),
                    _EmergencyCard(
                      title: LocalizationService.instance.translate(
                        'emergency_women',
                      ),
                      number: '1091',
                      icon: Icons.woman_rounded,
                      color: Colors.pinkAccent,
                      onTap: () => _makePhoneCall('1091'),
                    ),
                    _EmergencyCard(
                      title: LocalizationService.instance.translate(
                        'emergency_child',
                      ),
                      number: '1098',
                      icon: Icons.child_care_rounded,
                      color: Colors.tealAccent,
                      onTap: () => _makePhoneCall('1098'),
                    ),
                  ]
                  .map(
                    (card) => SizedBox(
                      width: isWide ? 340 : double.infinity,
                      child: card,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final String title;
  final String number;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyCard({
    required this.title,
    required this.number,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF10273A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocalizationService.instance.translateWith(
                      'call_label',
                      <String, String>{'number': number},
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.call_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
