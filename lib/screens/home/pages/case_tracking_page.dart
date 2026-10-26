import 'package:flutter/material.dart';
import '../../../models/cyber_cell_case.dart';
import '../../../services/cyber_cell_service.dart';

class CaseTrackingPage extends StatelessWidget {
  const CaseTrackingPage({super.key});
  @override Widget build(BuildContext context) => StreamBuilder<List<CyberCellCase>>(stream: CyberCellService.instance.watchMyCases(), builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    if (snapshot.data!.isEmpty) return const Center(child: Text('Your Cyber Cell case updates will appear here.'));
    return ListView(padding: const EdgeInsets.all(16), children: snapshot.data!.map((item) => Card(child: ExpansionTile(title: Text(item.id), subtitle: Text(item.status.label), children: [Padding(padding: const EdgeInsets.all(16), child: _Timeline(current: item.status))]))).toList());
  });
}
class _Timeline extends StatelessWidget { const _Timeline({required this.current}); final CyberCellStatus current; @override Widget build(BuildContext context) { final index = CyberCellStatus.values.indexOf(current); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: CyberCellStatus.values.asMap().entries.map((entry) => ListTile(leading: Icon(entry.key <= index ? Icons.check_circle : Icons.radio_button_unchecked, color: entry.key <= index ? Colors.teal : Colors.grey), title: Text(entry.value.label))).toList()); } }