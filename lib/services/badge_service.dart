import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeService {
  BadgeService(this._db);
  final FirebaseFirestore _db;

  /// Mevcut rozet kontrol mekanizman (ders/streak/score vb.)
  Future<void> evaluateAndGrant({
    required String uid,
    required int totalScore,
    required int currentStreak,
    required int completedLessons,
    required int completedModules,
  }) async {
    final checks = <_BadgeDef>[
      _BadgeDef(
        'first_steps',
        'İlk Adım',
        'İlk dersini tamamladın!',
        '👣',
            () => completedLessons >= 1,
      ),
      _BadgeDef(
        'five_lessons',
        '5 Ders',
        '5 ders tamamladın.',
        '📘',
            () => completedLessons >= 5,
      ),
      _BadgeDef(
        'ten_lessons',
        '10 Ders',
        '10 ders tamamladın.',
        '📚',
            () => completedLessons >= 10,
      ),
      _BadgeDef(
        'module_master',
        'Modül Ustası',
        'Bir modülü bitirdin!',
        '🏆',
            () => completedModules >= 1,
      ),
      _BadgeDef(
        'three_modules',
        '3 Modül',
        '3 modül tamamladın!',
        '🥇',
            () => completedModules >= 3,
      ),
      _BadgeDef(
        'score_100',
        '100 Puan',
        'Toplam 100 puana ulaştın.',
        '⭐',
            () => totalScore >= 100,
      ),
      _BadgeDef(
        'score_500',
        '500 Puan',
        'Toplam 500 puana ulaştın.',
        '🌟',
            () => totalScore >= 500,
      ),
      _BadgeDef(
        'score_1000',
        '1000 Puan',
        'Toplam 1000 puana ulaştın.',
        '💫',
            () => totalScore >= 1000,
      ),
      _BadgeDef(
        'streak_3',
        '3 Gün Streak',
        '3 gün üst üste çalıştın!',
        '🔥',
            () => currentStreak >= 3,
      ),
      _BadgeDef(
        'streak_7',
        '7 Gün Streak',
        '7 gün üst üste çalıştın!',
        '🚀',
            () => currentStreak >= 7,
      ),
      _BadgeDef(
        'streak_30',
        '30 Gün Streak',
        '30 gün üst üste çalıştın!',
        '👑',
            () => currentStreak >= 30,
      ),
    ];

    for (final b in checks) {
      if (b.when()) {
        await _grant(uid, b.id, b.title, b.description, b.icon);
      }
    }
  }

  /// ✅ YENİ: Daily goal rozetleri (hedefi tamamladığın gün sayısına göre)
  /// users/{uid}/dailyGoals -> achievedAt alanı olanları sayar.
  Future<void> evaluateDailyGoalBadges({required String uid}) async {
    final goalsRef = _db.collection('users').doc(uid).collection('dailyGoals');

    // achievedAt != null
    final achievedSnap = await goalsRef.where('achievedAt', isNull: false).get();
    final achievedDays = achievedSnap.docs.length;

    final checks = <_BadgeDef>[
      _BadgeDef(
        'daily_goal_1',
        'Günlük Hedef – İlk Kez',
        'Günlük hedefini ilk kez tamamladın!',
        '🎯',
            () => achievedDays >= 1,
      ),
      _BadgeDef(
        'daily_goal_7',
        'Günlük Hedef – 7 Gün',
        'Günlük hedefini toplam 7 gün tamamladın!',
        '✅',
            () => achievedDays >= 7,
      ),
      _BadgeDef(
        'daily_goal_30',
        'Günlük Hedef – 30 Gün',
        'Günlük hedefini toplam 30 gün tamamladın!',
        '🏅',
            () => achievedDays >= 30,
      ),
    ];

    for (final b in checks) {
      if (b.when()) {
        await _grant(uid, b.id, b.title, b.description, b.icon);
      }
    }
  }

  Future<void> _grant(
      String uid,
      String id,
      String title,
      String description,
      String icon,
      ) async {
    final ref = _db.collection('users').doc(uid).collection('badges').doc(id);

    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'earnedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class _BadgeDef {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool Function() when;

  _BadgeDef(this.id, this.title, this.description, this.icon, this.when);
}
