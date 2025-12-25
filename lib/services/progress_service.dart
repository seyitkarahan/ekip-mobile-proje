import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressService {
  ProgressService(this._db);
  final FirebaseFirestore _db;

  /// Kullanıcı bir dersi tamamlayınca çağır
  Future<void> markLessonCompleted({
    required String uid,
    required String moduleId,
    required String lessonId,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('completedLessons')
    // doc id: moduleId + "_" + lessonId (senin mevcut yapın)
        .doc('${moduleId}_$lessonId');

    await ref.set({
      'moduleId': moduleId,
      'lessonId': lessonId,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Bu modülde tamamlanan lessonId'leri (subcollection) Set<String> olarak stream eder
  /// users/{uid}/completedLessons altında:
  /// { moduleId: "...", lessonId: "..." }
  ///
  /// Ek güvenlik:
  /// - lessonId alanı boşsa docId'den (moduleId prefix'i ile) fallback okur.
  Stream<Set<String>> completedLessonIdsForModuleStream({
    required String uid,
    required String moduleId,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('completedLessons')
        .where('moduleId', isEqualTo: moduleId)
        .snapshots()
        .map((snap) {
      final set = <String>{};

      for (final d in snap.docs) {
        final data = d.data();

        // 1) Normal yol: lessonId field
        var lessonId = (data['lessonId'] ?? '').toString().trim();

        // 2) Fallback: docId -> "${moduleId}_$lessonId"
        // moduleId içinde "_" olsa bile, exact prefix ile kesiyoruz.
        if (lessonId.isEmpty) {
          final docId = d.id;
          final prefix = '${moduleId}_';
          if (docId.startsWith(prefix) && docId.length > prefix.length) {
            lessonId = docId.substring(prefix.length).trim();
          }
        }

        if (lessonId.isNotEmpty) set.add(lessonId);
      }

      return set;
    });
  }

  /// ✅ ESKİ sistemden (users/{uid}.completedLessons array) -> YENİ sisteme (subcollection)
  /// NOT: Kullanıcı doc’undaki array’i SİLMEZ. Sadece subcollection’a kopyalar.
  Future<void> migrateArrayCompletedLessonsToSubcollection({
    required String uid,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final data = userSnap.data();
    if (data == null) return;

    final migratedFlag = data['completedLessonsMigrated'];
    final already = migratedFlag is bool ? migratedFlag : false;
    if (already) return;

    // ✅ SAFE: completedLessons list değilse patlamasın
    final rawAny = data['completedLessons'];
    final List<dynamic> raw = rawAny is List ? rawAny : const <dynamic>[];

    final lessonIds = raw
        .map((e) => e.toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (lessonIds.isEmpty) {
      await userRef.set(
        {'completedLessonsMigrated': true},
        SetOptions(merge: true),
      );
      return;
    }

    // Firestore whereIn max 10 => parça parça
    final chunks = _chunk(lessonIds, 10);

    for (final chunk in chunks) {
      // Burada chunk elemanları lessons docId olmalı (senin eski array buna göreydi)
      final snap = await _db
          .collection('lessons')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      final batch = _db.batch();

      for (final d in snap.docs) {
        final mId = (d.data()['moduleId'] ?? '').toString().trim();
        if (mId.isEmpty) continue;

        final lId = d.id;
        final ref = userRef.collection('completedLessons').doc('${mId}_$lId');

        batch.set(
          ref,
          {
            'moduleId': mId,
            'lessonId': lId,
            'migratedAt': FieldValue.serverTimestamp(),
            'source': 'users.completedLessons(array)',
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }

    await userRef.set(
      {'completedLessonsMigrated': true},
      SetOptions(merge: true),
    );
  }

  /// Tamamlanan ders sayısı (canlı)
  Stream<int> completedLessonsCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('completedLessons')
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Modül bazlı tamamlanan ders sayıları: {moduleId: count}
  Stream<Map<String, int>> completedByModuleStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('completedLessons')
        .snapshots()
        .map((snap) {
      final Map<String, int> map = {};
      for (final d in snap.docs) {
        final data = d.data();
        final m = (data['moduleId'] ?? '').toString().trim();
        if (m.isEmpty) continue;
        map[m] = (map[m] ?? 0) + 1;
      }
      return map;
    });
  }

  /// ✅ Modüllerin ders sayıları: {moduleId: totalLessonCount}
  /// SENİN YAPIN: dersler top-level "lessons" koleksiyonunda (moduleId alanı var)
  Future<Map<String, int>> fetchModuleLessonTotals() async {
    final lessonsSnap = await _db.collection('lessons').get();
    final Map<String, int> totals = {};

    for (final d in lessonsSnap.docs) {
      final data = d.data();
      final moduleId = (data['moduleId'] ?? '').toString().trim();
      if (moduleId.isEmpty) continue;
      totals[moduleId] = (totals[moduleId] ?? 0) + 1;
    }

    return totals;
  }

  /// --- helper: list'i parçalara böl ---
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final res = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      res.add(list.sublist(
        i,
        (i + size) > list.length ? list.length : i + size,
      ));
    }
    return res;
  }
}
