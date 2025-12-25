import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  UserService(this._db);

  final FirebaseFirestore _db;

  /// Kullanıcı doc'u yoksa oluşturur (varsa dokunmaz).
  Future<void> ensureUserDoc({
    required String uid,
    required String email,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();

    if (snap.exists) return;

    final username = _deriveUsername(email);

    await ref.set({
      'username': username,
      'totalScore': 0,
      'weeklyScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _deriveUsername(String email) {
    final beforeAt = email.split('@').first;
    return beforeAt.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '');
  }
}
