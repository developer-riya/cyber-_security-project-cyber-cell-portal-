import 'package:cloud_firestore/cloud_firestore.dart';

enum CyberCellStatus {
  submitted('Submitted'),
  accepted('Accepted'),
  underReview('Under Review'),
  informationRequired('Additional Information Required'),
  caseUpdated('Case Updated'),
  closed('Closed');

  const CyberCellStatus(this.label);
  final String label;
  static CyberCellStatus fromValue(Object? value) => values.firstWhere(
    (item) => item.label == value,
    orElse: () => CyberCellStatus.submitted,
  );
}

class CyberCellCase {
  const CyberCellCase({required this.id, required this.data});
  factory CyberCellCase.fromMap(Map<String, dynamic> map) => CyberCellCase(
    id: (map['caseId'] ?? map['id'] ?? '').toString(),
    data: map,
  );
  factory CyberCellCase.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => CyberCellCase.fromMap({'id': snapshot.id, ...?snapshot.data()});

  final String id;
  final Map<String, dynamic> data;
  String get incidentType =>
      (data['incidentType'] ?? 'Cybercrime Report').toString();
  String get description => (data['description'] ?? '').toString();
  String get riskLevel => (data['riskLevel'] ?? 'UNKNOWN').toString();
  String get priority => (data['priority'] ?? 'NORMAL').toString();
  CyberCellStatus get status => CyberCellStatus.fromValue(data['status']);
  int get riskScore => (data['riskScore'] as num?)?.toInt() ?? 0;
}
