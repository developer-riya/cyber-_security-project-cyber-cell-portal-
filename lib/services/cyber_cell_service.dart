import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/cyber_cell_case.dart';

class CyberCellAccessException implements Exception {
  const CyberCellAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CyberCellService {
  CyberCellService._();
  static final CyberCellService instance = CyberCellService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _apiBase = String.fromEnvironment(
    'CYBER_CELL_API_BASE',
    defaultValue:
        'https://asia-south1-cyber-uday-20.cloudfunctions.net/cyberCellApi',
  );

  Stream<List<CyberCellCase>> watchMyCases() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <CyberCellCase>[]);
    return _db
        .collection('case_tracking')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CyberCellCase.fromSnapshot).toList(),
        );
  }

  Future<Map<String, dynamic>> dashboard() => _get('/dashboard');
  Future<List<CyberCellCase>> cases() async =>
      ((await _get('/cases'))['cases'] as List<dynamic>)
          .map(
            (item) =>
                CyberCellCase.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
  Future<CyberCellCase> caseDetails(String caseId) async =>
      CyberCellCase.fromMap(
        Map<String, dynamic>.from(
          (await _get('/cases/$caseId'))['case'] as Map,
        ),
      );
  Future<void> updateStatus(
    String caseId,
    CyberCellStatus status, {
    String note = '',
  }) => _patch('/cases/$caseId/status', {'status': status.label, 'note': note});
  Future<void> requestInformation(String caseId, String message) =>
      _post('/cases/$caseId/request-info', {'message': message});
  Future<void> addUpdate(String caseId, String message) =>
      _post('/cases/$caseId/updates', {'message': message});
  Future<Map<String, dynamic>> _get(String path) => _request('GET', path);
  Future<void> _patch(String path, Map<String, dynamic> body) async {
    await _request('PATCH', path, body);
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    await _request('POST', path, body);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CyberCellAccessException('Sign in is required.');
    }
    final token = await user.getIdToken(true);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$_apiBase$path');
    late final http.Response response;
    try {
      response = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'PATCH' => await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        _ => await http.post(uri, headers: headers, body: jsonEncode(body)),
      };
    } on Exception {
      throw const CyberCellAccessException(
        'Cyber Cell service is unavailable. Deploy cyberCellApi and try again.',
      );
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 401 || response.statusCode == 403) {
      final String errorCode = (decoded['error'] ?? '').toString();
      if (errorCode == 'inactive') {
        throw const CyberCellAccessException('This account has been disabled.');
      }
      if (errorCode == 'role-missing') {
        throw const CyberCellAccessException(
          'Cyber Cell authorization has not been assigned to this account.',
        );
      }
      throw const CyberCellAccessException(
        'Your account is authenticated but is not authorized for Cyber Cell access.',
      );
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 404) {
        throw const CyberCellAccessException(
          'Cyber Cell service is not deployed. Deploy cyberCellApi and try again.',
        );
      }
      throw CyberCellAccessException(
        (decoded['error'] ?? 'Request failed.').toString(),
      );
    }
    return decoded;
  }
}
