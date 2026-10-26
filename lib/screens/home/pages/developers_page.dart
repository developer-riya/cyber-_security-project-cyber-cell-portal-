import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/home_shared_widgets.dart';
import '../../../services/localization_service.dart';

class DevelopersPage extends StatelessWidget {
  const DevelopersPage({super.key, this.standalone = false});

  final bool standalone;

  static const List<_DeveloperProfile> _developers = [
    _DeveloperProfile(
      name: 'Uday Payghon',
      role: 'Founder & CEO • Cyber Security Architect',
      email: 'udaypayghon@gmail.com',
      linkedIn: 'https://www.linkedin.com/in/uday-payghon/',
      github: 'https://github.com/udaypayghon',
      accent: Color(0xFF3FFFD7),
    ),
    _DeveloperProfile(
      name: 'Manjushree  Dighe',
      role: 'Spring Boot Architecture',
      email: 'dighemanju11@gmail.com',
      accent: Color(0xFFFFC857),
    ),
    _DeveloperProfile(
      name: 'Anushka  Shinde',
      role: 'AI & Frontend',
      email: 'anushkashinde568@gmail.com',
      accent: Color(0xFFFF5C8A),
    ),
    _DeveloperProfile(
      name: 'Riya Pagar',
      role: 'Web UI & UX',
      email: 'riyapagar18@gmail.com',
      accent: Color(0xFF8EF6FF),
    ),
    _DeveloperProfile(
      name: 'Sagar Jadhav',
      role: 'Flutter Developer & AI Engineer',
      email: 'Add later',
      linkedIn: 'Add later',
      github: 'Add later',
      accent: Color(0xFF5AB2FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        HeroBanner(
          title: 'Cyber Uday',
          subtitle: LocalizationService.instance.translate(
            'developers_description',
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: LocalizationService.instance.translate('developers_header'),
          subtitle: LocalizationService.instance.translate(
            'developers_description',
          ),
          child: const _DevelopersGrid(developers: _developers),
        ),
      ],
    );

    if (!standalone) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.instance.translate('developers')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF040B11), Color(0xFF07111A), Color(0xFF0B2030)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _DevelopersGrid extends StatelessWidget {
  const _DevelopersGrid({required this.developers});

  final List<_DeveloperProfile> developers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: developers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 300,
          ),
          itemBuilder: (context, index) {
            return _DeveloperCard(profile: developers[index]);
          },
        );
      },
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.profile});

  final _DeveloperProfile profile;

  Future<void> _open(BuildContext context, String value) async {
    if (value == 'Add later') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('developers_link_pending'),
          ),
        ),
      );
      return;
    }

    final uri = value.contains('@') && !value.startsWith('http')
        ? Uri(scheme: 'mailto', path: value)
        : Uri.parse(value);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('link_open_failed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D1B29),
        border: Border.all(color: const Color(0xFF1E4A67)),
        boxShadow: [
          BoxShadow(
            color: profile.accent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1B29),
            profile.accent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InitialsAvatar(profile: profile),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.role,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: profile.accent,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _ContactButton(
            label: profile.email,
            icon: Icons.alternate_email_rounded,
            onTap: () => _open(context, profile.email),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ContactButton(
                  label: 'LinkedIn',
                  icon: Icons.work_outline_rounded,
                  disabled: profile.linkedIn == null,
                  onTap: () => _open(context, profile.linkedIn ?? 'Add later'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactButton(
                  label: 'GitHub',
                  icon: Icons.code_rounded,
                  disabled: profile.github == null,
                  onTap: () => _open(context, profile.github ?? 'Add later'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.profile});

  final _DeveloperProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [profile.accent, const Color(0xFF5AB2FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: profile.accent.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        profile.initials,
        style: const TextStyle(
          color: Color(0xFF07111A),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: disabled ? null : onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

class _DeveloperProfile {
  const _DeveloperProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.accent,
    this.linkedIn,
    this.github,
  });

  final String name;
  final String role;
  final String email;
  final Color accent;
  final String? linkedIn;
  final String? github;

  String get initials {
    return name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
  }
}
