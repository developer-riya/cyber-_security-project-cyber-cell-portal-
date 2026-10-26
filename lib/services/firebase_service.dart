import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Reports ---
  Future<String> submitReport(Map<String, dynamic> reportData) async {
    final user = _auth.currentUser;
    DocumentReference ref = await _db.collection('reports').add({
      ...reportData,
      'userId': user?.uid,
      'userEmail': user?.email,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<int> getReportsCount() {
    return _db
        .collection('reports')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<List<int>> getMonthlyReportStats() {
    return _db.collection('reports').snapshots().map((snapshot) {
      List<int> stats = List.filled(12, 0);
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        if (timestamp != null) {
          int month = timestamp.toDate().month - 1;
          stats[month]++;
        }
      }
      return stats;
    });
  }

  // --- Threat Scanner ---
  Future<void> submitThreat(Map<String, dynamic> threatData) async {
    final user = _auth.currentUser;
    await _db.collection('threats').add({
      ...threatData,
      'userId': user?.uid,
      'userEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<int> getThreatsCount() {
    return _db
        .collection('threats')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // --- Emergency Actions ---
  Future<void> logEmergencyAction(
    String actionType,
    Map<String, dynamic> details,
  ) async {
    final user = _auth.currentUser;
    await _db.collection('emergency_actions').add({
      'userId': user?.uid,
      'userEmail': user?.email,
      'action': actionType,
      'details': details,
      'status': 'Critical',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> connectBankPermission(Map<String, dynamic> details) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Please sign in before connecting bank permission.',
      );
    }

    await _db.collection('bank_connections').doc(user.uid).set({
      'userId': user.uid,
      'userEmail': user.email,
      'status': 'Permission Connected',
      'details': details,
      'connectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserBankPermission() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
          message: 'Please sign in before viewing bank permission.',
        ),
      );
    }
    return _db.collection('bank_connections').doc(user.uid).snapshots();
  }

  Stream<int> getEmergencyActionsCount() {
    return _db
        .collection('emergency_actions')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // --- Cyber News ---
  Future<void> submitNews(Map<String, dynamic> newsData) async {
    final user = _auth.currentUser;
    await _db.collection('cyber_news').add({
      ...newsData,
      'userId': user?.uid,
      'author': user?.email ?? 'Anonymous',
      'status': 'Pending',
      'publishedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getCyberNews() {
    // Simplified query to avoid index requirements and show all items with status 'Published'
    return _db
        .collection('cyber_news')
        .where('status', isEqualTo: 'Published')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          // Client-side sorting as a fallback
          docs.sort((a, b) {
            final aTime = a['publishedAt'] as Timestamp?;
            final bTime = b['publishedAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          return docs;
        });
  }

  // --- Admin Methods ---
  Stream<List<Map<String, dynamic>>> getAllReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getAllThreats() {
    return _db
        .collection('threats')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getAllEmergencyActions() {
    return _db
        .collection('emergency_actions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getAllNewsForAdmin() {
    return _db.collection('cyber_news').snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      docs.sort((a, b) {
        final aTime = a['publishedAt'] as Timestamp?;
        final bTime = b['publishedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return docs;
    });
  }

  Future<void> publishNews(String newsId) async {
    await _db.collection('cyber_news').doc(newsId).update({
      'status': 'Published',
      'publishedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNews(String newsId) async {
    await _db.collection('cyber_news').doc(newsId).delete();
  }

  Stream<int> getConnectedBanksCount() {
    return _db
        .collection('bank_connections')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getUserConnectedBanksCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<int>.value(0);
    }

    return _db
        .collection('bank_connections')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<DocumentSnapshot> getUserData() {
    return _db.collection('users').doc(_auth.currentUser?.uid).snapshots();
  }
}
