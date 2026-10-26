import 'package:flutter/material.dart';
import '../widgets/home_shared_widgets.dart';
import '../../../services/localization_service.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final filteredExperts = _selectedCategory == 'All'
        ? _experts
        : _experts.where((e) => e.category == _selectedCategory).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroBanner(
            title: LocalizationService.instance.translate(
              'sessions_page_title',
            ),
            subtitle: LocalizationService.instance.translate(
              'sessions_page_subtitle',
            ),
          ),
          const SizedBox(height: 32),

          // Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Security', 'Legal', 'Mental Health'].map((
                cat,
              ) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text(_categoryLabel(cat)),
                    selected: isSelected,
                    onSelected: (val) =>
                        setState(() => _selectedCategory = cat),
                    selectedColor: const Color(0xFF3FFFD7),
                    backgroundColor: const Color(0xFF10273A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Responsive Grid
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 24,
              alignment: WrapAlignment.start,
              children: filteredExperts
                  .map(
                    (expert) => SizedBox(
                      width: isMobile ? double.infinity : 360,
                      child: _ExpertProfileCard(expert: expert),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'Security' => LocalizationService.instance.translate('sessions_security'),
      'Legal' => LocalizationService.instance.translate('sessions_legal'),
      'Mental Health' => LocalizationService.instance.translate(
        'sessions_mental_health',
      ),
      _ => LocalizationService.instance.translate('sessions_all'),
    };
  }
}

class _ExpertProfileCard extends StatelessWidget {
  final _Expert expert;
  const _ExpertProfileCard({required this.expert});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E2D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section with Image/Icon placeholder
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  expert.accentColor.withValues(alpha: 0.4),
                  const Color(0xFF10273A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Icon(
                    expert.icon,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Center(
                  child: Hero(
                    tag: 'expert_icon_${expert.name}',
                    child: Icon(
                      expert.icon,
                      color: expert.accentColor,
                      size: 56,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          expert.rating.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        expert.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      LocalizationService.instance.translate('sessions_online'),
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  expert.role.toUpperCase(),
                  style: TextStyle(
                    color: expert.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  expert.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.instance.translate(
                            'sessions_next_available',
                          ),
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expert.nextAvailable,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          LocalizationService.instance.translate(
                            'sessions_per_30_minutes',
                          ),
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${expert.price}',
                          style: const TextStyle(
                            color: Color(0xFF3FFFD7),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _BookingButton(expert: expert),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingButton extends StatefulWidget {
  final _Expert expert;
  const _BookingButton({required this.expert});

  @override
  State<_BookingButton> createState() => _BookingButtonState();
}

class _BookingButtonState extends State<_BookingButton> {
  bool _loading = false;

  void _handleBooking() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _loading = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1E2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          LocalizationService.instance.translate('sessions_requested'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          LocalizationService.instance.translateWith(
            'sessions_request_sent',
            <String, String>{'name': widget.expert.name},
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              LocalizationService.instance.translate('sessions_got_it'),
              style: TextStyle(
                color: Color(0xFF3FFFD7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _handleBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3FFFD7),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.black,
                ),
              )
            : Text(LocalizationService.instance.translate('sessions_book')),
      ),
    );
  }
}

class _Expert {
  final String name;
  final String role;
  final String category;
  final String description;
  final double rating;
  final int price;
  final String nextAvailable;
  final IconData icon;
  final Color accentColor;

  const _Expert({
    required this.name,
    required this.role,
    required this.category,
    required this.description,
    required this.rating,
    required this.price,
    required this.nextAvailable,
    required this.icon,
    required this.accentColor,
  });
}

const List<_Expert> _experts = [
  _Expert(
    name: 'Agent Uday',
    role: 'Cyber Intelligence Lead',
    category: 'Security',
    description:
        'Specialist in identifying threat vectors, digital footprint analysis, and proactive defense strategies for high-risk individuals.',
    rating: 4.9,
    price: 1999,
    nextAvailable: 'Today, 4:00 PM',
    icon: Icons.shield_rounded,
    accentColor: Colors.blueAccent,
  ),
  _Expert(
    name: 'Adv. Megha S.',
    role: 'Cyber Law Consultant',
    category: 'Legal',
    description:
        'Expert in IT Act, digital evidence handling, and legal procedures for financial fraud recovery and data privacy cases.',
    rating: 4.8,
    price: 1499,
    nextAvailable: 'Tomorrow, 11:00 AM',
    icon: Icons.gavel_rounded,
    accentColor: Colors.orangeAccent,
  ),
  _Expert(
    name: 'Dr. Sarah',
    role: 'Crisis Psychologist',
    category: 'Mental Health',
    description:
        'Providing immediate psychological support for victims of online blackmail, harassment, and severe digital trauma.',
    rating: 4.9,
    price: 1299,
    nextAvailable: 'Today, 6:30 PM',
    icon: Icons.favorite_rounded,
    accentColor: Colors.pinkAccent,
  ),
  _Expert(
    name: 'Dev Rohan',
    role: 'Application Architect',
    category: 'Security',
    description:
        'Expert in secure code review, infrastructure hardening, and recovering hijacked corporate assets and web properties.',
    rating: 4.7,
    price: 2499,
    nextAvailable: '25th Apr, 10:00 AM',
    icon: Icons.code_rounded,
    accentColor: Colors.tealAccent,
  ),
];
