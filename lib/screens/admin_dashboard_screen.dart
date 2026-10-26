import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      backgroundColor: const Color(0xFF040B11),
      appBar: AppBar(
        title: const Text('CYBER UDAY ADMIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: !isWide ? _buildSidebar() : null,
      body: Row(
        children: [
          if (isWide) _buildSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF07111A),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _SidebarItem(
            title: 'Overview',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            isSelected: _activeTab == 0,
            onTap: () => setState(() => _activeTab = 0),
          ),
          _SidebarItem(
            title: 'Reports',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description,
            isSelected: _activeTab == 1,
            onTap: () => setState(() => _activeTab = 1),
          ),
          _SidebarItem(
            title: 'Threats',
            icon: Icons.security_outlined,
            selectedIcon: Icons.security,
            isSelected: _activeTab == 2,
            onTap: () => setState(() => _activeTab = 2),
          ),
          _SidebarItem(
            title: 'Emergency',
            icon: Icons.emergency_outlined,
            selectedIcon: Icons.emergency,
            isSelected: _activeTab == 3,
            onTap: () => setState(() => _activeTab = 3),
          ),
          _SidebarItem(
            title: 'News Moderation',
            icon: Icons.newspaper_outlined,
            selectedIcon: Icons.newspaper,
            isSelected: _activeTab == 4,
            onTap: () => setState(() => _activeTab = 4),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_activeTab) {
      case 0:
        return const _AdminOverview();
      case 1:
        return _AdminDataList(
          stream: FirebaseService.instance.getAllReports(),
          titleKey: 'description',
          subtitleKey: 'userEmail',
          icon: Icons.description,
          hasPdf: true,
        );
      case 2:
        return _AdminDataList(
          stream: FirebaseService.instance.getAllThreats(),
          titleKey: 'headline',
          subtitleKey: 'userEmail',
          icon: Icons.security,
        );
      case 3:
        return _AdminDataList(
          stream: FirebaseService.instance.getAllEmergencyActions(),
          titleKey: 'action',
          subtitleKey: 'userEmail',
          icon: Icons.emergency,
          isCritical: true,
        );
      case 4:
        return const _AdminNewsModerationList();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected ? const Color(0xFF3FFFD7) : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Overview',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _StatCard(
              title: 'Total Reports',
              stream: FirebaseService.instance.getReportsCount(),
              color: Colors.blueAccent,
              icon: Icons.description,
            ),
            _StatCard(
              title: 'Threats Logged',
              stream: FirebaseService.instance.getThreatsCount(),
              color: Colors.orangeAccent,
              icon: Icons.security,
            ),
            _StatCard(
              title: 'Active Emergencies',
              stream: FirebaseService.instance.getEmergencyActionsCount(),
              color: Colors.redAccent,
              icon: Icons.emergency,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Stream<int> stream;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.stream,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF10273A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              return Text(
                '${snapshot.data ?? 0}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminNewsModerationList extends StatelessWidget {
  const _AdminNewsModerationList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.instance.getAllNewsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final newsItems = snapshot.data ?? [];
        if (newsItems.isEmpty) {
          return const Center(child: Text('No news submissions.'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Submissions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: newsItems.length,
                itemBuilder: (context, index) {
                  final item = newsItems[index];
                  final bool isPublished = item['status'] == 'Published';

                  return Card(
                    color: const Color(0xFF10273A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      title: Text(
                        item['headline'] ?? 'Untitled News',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'By: ${item['author']} • Status: ${item['status']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPublished)
                            IconButton(
                              icon: const Icon(
                                Icons.publish,
                                color: Colors.greenAccent,
                              ),
                              onPressed: () => FirebaseService.instance
                                  .publishNews(item['id']),
                              tooltip: 'Publish',
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                FirebaseService.instance.deleteNews(item['id']),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminDataList extends StatelessWidget {
  const _AdminDataList({
    required this.stream,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    this.hasPdf = false,
    this.isCritical = false,
  });

  final Stream<List<Map<String, dynamic>>> stream;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final bool hasPdf;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No data found.'));

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              color: const Color(0xFF10273A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isCritical
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  icon,
                  color: isCritical
                      ? Colors.redAccent
                      : const Color(0xFF3FFFD7),
                ),
                title: Text(
                  item[titleKey] ?? 'Untitled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(item[subtitleKey] ?? 'Unknown User'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPdf)
                      IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Color(0xFF3FFFD7),
                        ),
                        onPressed: () => PdfService.generateReportPdf(item),
                      ),
                    const Icon(Icons.chevron_right, color: Colors.white24),
                  ],
                ),
                onTap: () => _showDetailsSheet(context, item),
              ),
            );
          },
        );
      },
    );
  }

  //here is show detials sheet
  void _showDetailsSheet(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07111A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Interaction Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 40),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: data.entries.map((e) {
                    if (e.key == 'id' ||
                        e.key == 'createdAt' ||
                        e.key == 'publishedAt') {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: Color(0xFF3FFFD7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            e.value.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
