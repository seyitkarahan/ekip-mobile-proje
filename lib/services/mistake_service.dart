import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MistakeService {
  /// Bir kelime sorusunda yanlış cevap verildiğinde çağır.
  static Future<void> saveWordMistake({
    required String wordId,
    required String english,
    required String turkish,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('mistakes')
        .doc('word_$wordId');

    await docRef.set({
      'type': 'word',
      'wordId': wordId,
      'english': english,
      'turkish': turkish,
      'wrongCount': FieldValue.increment(1),
      'lastWrongAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Review’de veya normal quizde doğru yaptıkça hatayı azaltmak için.
  static Future<void> resolveWordMistake({
    required String wordId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('mistakes')
        .doc('word_$wordId');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final current = (data['wrongCount'] ?? 1) as int;
      final newCount = current - 1;

      if (newCount <= 0) {
        tx.delete(docRef);
      } else {
        tx.update(docRef, {'wrongCount': newCount});
      }
    });
  }
}
