import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  ProfileService(this._db);

  final FirebaseFirestore _db;

  Future<void> updateUsername({
    required String uid,
    required String username,
  }) async {
    final cleaned = username.trim();

    if (cleaned.isEmpty) {
      throw Exception('Kullanıcı adı boş olamaz.');
    }
    if (cleaned.length < 3) {
      throw Exception('Kullanıcı adı en az 3 karakter olmalı.');
    }
    if (cleaned.length > 20) {
      throw Exception('Kullanıcı adı en fazla 20 karakter olmalı.');
    }
    // sadece harf, sayı, _ . - izin verelim
    final ok = RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(cleaned);
    if (!ok) {
      throw Exception('Sadece harf/sayı ve _ . - karakterleri kullanılabilir.');
    }

    await _db.collection('users').doc(uid).update({
      'username': cleaned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
