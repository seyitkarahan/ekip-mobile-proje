import 'package:cloud_firestore/cloud_firestore.dart';

import 'badge_service.dart';

enum ScoreMode { lessonQuiz, wordQuiz, review, moduleExam }

class ScoreResult {
  final int correct;
  final int total;

  final int basePoints;
  final int comboPoints;
  final int completionBonus;

  final int bestComboInRun;
  final int totalEarned;

  const ScoreResult({
    required this.correct,
    required this.total,
    required this.basePoints,
    required this.comboPoints,
    required this.completionBonus,
    required this.bestComboInRun,
    required this.totalEarned,
  });

  Map<String, int> get breakdown => {
    'basePoints': basePoints,
    'comboPoints': comboPoints,
    'completionBonus': completionBonus,
    'totalEarned': totalEarned,
  };
}

class ScoreService {
  final FirebaseFirestore _db;
  ScoreService(this._db);

  Future<ScoreResult> applyQuizResult({
    required String uid,
    required ScoreMode mode,
    required int correct,
    required int total,
    required int bestComboInRun,
  }) async {
    final result = calculateQuizScore(
      mode: mode,
      correct: correct,
      total: total,
      bestComboInRun: bestComboInRun,
    );

    if (result.totalEarned <= 0) return result;

    await addScore(
      uid: uid,
      earned: result.totalEarned,
      activity: mode.name,
    );

    return result;
  }

  Future<void> addScore({
    required String uid,
    required int earned,
    String activity = 'quiz',
  }) async {
    final userRef = _db.collection('users').doc(uid);

    final now = DateTime.now();
    final todayKey = _todayKey(now);
    final todayStr = _todayStr(now);

    final dailyRef = userRef.collection('dailyScores').doc(todayKey);
    final goalRef = userRef.collection('dailyGoals').doc(todayKey);

    bool achievedNow = false;

    await _db.runTransaction((tx) async {
      // ✅ 1) TÜM READ'LER ÖNCE
      final userSnap = await tx.get(userRef);
      final dailySnap = await tx.get(dailyRef);
      final goalSnap = await tx.get(goalRef);

      // goal bilgisi
      final goalData = goalSnap.data() ?? <String, dynamic>{};
      int targetPoints = _asInt(goalData['targetPoints']);
      if (targetPoints <= 0) targetPoints = 50;

      final alreadyAchieved = goalData['achievedAt'] != null;

      // daily score
      final oldDaily = dailySnap.exists ? _asInt(dailySnap.data()?['score']) : 0;
      final newDaily = oldDaily + earned;

      // hedef ilk kez geçildiyse
      achievedNow = (!alreadyAchieved && targetPoints > 0 && newDaily >= targetPoints);

      // ✅ 2) Sonra hesapla + write
      if (!userSnap.exists) {
        // yeni user doc
        tx.set(userRef, {
          'totalScore': earned,
          'weeklyScore': earned,
          'currentStreak': 1,
          'longestStreak': 1,

          // old (UI eski alanları okuyorsa)
          'score': earned,
          'weekly': earned,
          'streak': 1,
          'bestStreak': 1,

          'lastActiveDate': todayStr,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final data = userSnap.data() ?? {};

        final totalScore = _asInt(data['totalScore'] ?? data['score'] ?? data['points']);
        final weeklyScore = _asInt(data['weeklyScore'] ?? data['weekly'] ?? data['weeklyPoints']);

        int currentStreak = _asInt(data['currentStreak'] ?? data['streak']);
        int longestStreak = _asInt(data['longestStreak'] ?? data['bestStreak']);

        final lastActiveStr = (data['lastActiveDate'] ?? '') as String;

        final todayDate = DateTime(now.year, now.month, now.day);
        final lastDate = _parseYmd(lastActiveStr);

        if (lastDate == null) {
          currentStreak = 1;
        } else {
          final diff = todayDate.difference(lastDate).inDays;
          if (diff == 0) {
            // aynı gün
          } else if (diff == 1) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
        }

        if (currentStreak > longestStreak) longestStreak = currentStreak;

        final newTotal = totalScore + earned;
        final newWeekly = weeklyScore + earned;

        tx.set(userRef, {
          'totalScore': newTotal,
          'weeklyScore': newWeekly,
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,

          // old mirror
          'score': newTotal,
          'weekly': newWeekly,
          'streak': currentStreak,
          'bestStreak': longestStreak,

          'lastActiveDate': todayStr,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // dailyScores write
      tx.set(dailyRef, {
        'score': newDaily,
        'date': todayKey,
        'activity': activity,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // dailyGoals write (ensure doc exists + achievedAt)
      tx.set(goalRef, {
        'date': todayKey,
        'targetPoints': targetPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (achievedNow) {
        tx.set(goalRef, {
          'achievedAt': FieldValue.serverTimestamp(),
          'achievedScore': newDaily,
          'achievedActivity': activity,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    // ✅ Transaction bitti: Eğer bugün hedef ilk kez tamamlandıysa rozetleri değerlendir
    if (achievedNow) {
      try {
        await BadgeService(_db).evaluateDailyGoalBadges(uid: uid);
      } catch (_) {
        // rozet hatası puan akışını bozmasın
      }
    }
  }

  ScoreResult calculateQuizScore({
    required ScoreMode mode,
    required int correct,
    required int total,
    required int bestComboInRun,
  }) {
    final safeCorrect = correct < 0 ? 0 : correct;
    final safeTotal = total < 0 ? 0 : total;

    int pointsPerCorrect = 10;
    if (mode == ScoreMode.review) pointsPerCorrect = 5;

    final base = safeCorrect * pointsPerCorrect;

    int combo = 0;
    if (bestComboInRun > 0) {
      if (mode == ScoreMode.review) {
        combo = bestComboInRun;
      } else if (mode == ScoreMode.wordQuiz || mode == ScoreMode.lessonQuiz || mode == ScoreMode.moduleExam) {
        combo = (bestComboInRun - 1) * 2;
        if (combo < 0) combo = 0;
      }
    }

    int bonus = 0;
    if (safeTotal > 0) {
      final ratio = safeCorrect / safeTotal;
      if (safeCorrect == safeTotal) {
        bonus = 50;
      } else if (ratio >= 0.70) {
        bonus = 20;
      }
    }

    final totalEarned = base + combo + bonus;

    return ScoreResult(
      correct: safeCorrect,
      total: safeTotal,
      basePoints: base,
      comboPoints: combo,
      completionBonus: bonus,
      bestComboInRun: bestComboInRun < 0 ? 0 : bestComboInRun,
      totalEarned: totalEarned < 0 ? 0 : totalEarned,
    );
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _todayKey(DateTime now) => _todayStr(now);

  String _todayStr(DateTime now) {
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseYmd(String s) {
    if (s.trim().isEmpty) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    try {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }
}
