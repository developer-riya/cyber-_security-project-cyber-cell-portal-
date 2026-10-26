import 'package:flutter/material.dart';
import '../models/cyber_cell_case.dart';
import '../services/auth_service.dart';
import '../services/cyber_cell_service.dart';

class CyberCellPortalScreen extends StatefulWidget {
  const CyberCellPortalScreen({super.key});
  @override
  State<CyberCellPortalScreen> createState() => _CyberCellPortalScreenState();
}

class _CyberCellPortalScreenState extends State<CyberCellPortalScreen> {
  String _filter = 'All';
  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cyber Cell Portal'),
      actions: [
        IconButton(
          onPressed: _logout,
          tooltip: 'Secure logout',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: FutureBuilder<List<CyberCellCase>>(
      future: CyberCellService.instance.cases(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cases = snapshot.data!
            .where((item) => _filter == 'All' || item.status.label == _filter)
            .toList();
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: CyberCellService.instance.dashboard(),
                builder: (context, stats) =>
                    _Stats(data: stats.data ?? const {}),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children:
                    ['All', ...CyberCellStatus.values.map((item) => item.label)]
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value),
                            selected: _filter == value,
                            onSelected: (_) => setState(() => _filter = value),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              ...cases.map(
                (item) => _CaseTile(
                  item: item,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CyberCellCaseDetailScreen(caseItem: item),
                    ),
                  ),
                ),
              ),
              if (cases.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No cases match this filter.')),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 5 : 2,
    childAspectRatio: 1.7,
    children: [
      _Stat('Total cases', data['totalCases']),
      _Stat('New', data['newCases']),
      _Stat('Accepted', data['acceptedCases']),
      _Stat('Under review', data['underReview']),
      _Stat('High priority', data['highPriority']),
      _Stat('Info required', data['informationRequired']),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const Spacer(),
          Text(
            '${value ?? 0}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    ),
  );
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.item, required this.onTap});
  final CyberCellCase item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(item.id),
      subtitle: Text('${item.incidentType}\n${item.status.label}'),
      isThreeLine: true,
      trailing: Chip(label: Text(item.priority)),
    ),
  );
}

class CyberCellCaseDetailScreen extends StatefulWidget {
  const CyberCellCaseDetailScreen({required this.caseItem, super.key});
  final CyberCellCase caseItem;
  @override
  State<CyberCellCaseDetailScreen> createState() =>
      _CyberCellCaseDetailScreenState();
}

class _CyberCellCaseDetailScreenState extends State<CyberCellCaseDetailScreen> {
  final _note = TextEditingController();
  bool _busy = false;
  Future<void> _run(Future<void> action) async {
    setState(() => _busy = true);
    try {
      await action;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Case updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.caseItem;
    return Scaffold(
      appBar: AppBar(title: Text(item.id)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            item.incidentType,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Risk ${item.riskLevel} • ${item.riskScore}/100 • ${item.priority}',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(item.description),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CyberCellStatus>(
            initialValue: item.status,
            items: CyberCellStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (status) {
                    if (status != null) {
                      _run(
                        CyberCellService.instance.updateStatus(
                          item.id,
                          status,
                          note: _note.text,
                        ),
                      );
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Officer note'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        CyberCellService.instance.requestInformation(
                          item.id,
                          _note.text,
                        ),
                      ),
                icon: const Icon(Icons.help_outline),
                label: const Text('Request information'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        CyberCellService.instance.addUpdate(
                          item.id,
                          _note.text,
                        ),
                      ),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add update'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
