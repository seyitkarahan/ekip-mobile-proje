import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyGoalCard extends StatefulWidget {
  const DailyGoalCard({super.key});

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard> {
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureGoalDoc({
    required DocumentReference<Map<String, dynamic>> goalRef,
  }) async {
    final snap = await goalRef.get();
    if (!snap.exists) {
      await goalRef.set({
        'date': _todayKey(),
        'targetPoints': 50, // default
        'createdAt': FieldValue.serverTimestamp(),
        'achievedAt': null,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _openGoalPicker({
    required DocumentReference<Map<String, dynamic>> goalRef,
    required int currentTarget,
  }) async {
    int temp = currentTarget;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Günlük hedefini seç'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$temp puan',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: temp.toDouble(),
                    min: 10,
                    max: 300,
                    divisions: 29, // 10’ar artış
                    label: '$temp',
                    onChanged: (v) => setLocal(() => temp = (v / 10).round() * 10),
                  ),
                  const SizedBox(height: 6),
                  const Text('İpucu: 50-100 arası çoğu kullanıcı için iyi.'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                await goalRef.set({
                  'targetPoints': temp,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final db = FirebaseFirestore.instance;
    final today = _todayKey();

    final goalRef = db.collection('users').doc(user.uid).collection('dailyGoals').doc(today);
    final scoreRef = db.collection('users').doc(user.uid).collection('dailyScores').doc(today);

    // Goal doc yoksa otomatik oluştur (1 kere)
    _ensureGoalDoc(goalRef: goalRef);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: goalRef.snapshots(),
      builder: (context, goalSnap) {
        final goalData = goalSnap.data?.data() ?? {};
        final target = (goalData['targetPoints'] ?? 50) as int;
        final achievedAt = goalData['achievedAt'];

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: scoreRef.snapshots(),
          builder: (context, scoreSnap) {
            final scoreData = scoreSnap.data?.data() ?? {};
            final score = (scoreData['score'] ?? 0) as int;

            final progress = target <= 0 ? 0.0 : (score / target).clamp(0.0, 1.0);
            final remaining = (target - score);
            final isDone = score >= target;

            // Tamamlandıysa achievedAt yoksa yaz (build içinde spam olmasın diye kontrollü)
            if (isDone && achievedAt == null) {
              Future.microtask(() async {
                await goalRef.set({
                  'achievedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              });
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Günün Hedefi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isDone)
                          Chip(
                            label: const Text('Tamamlandı ✅'),
                            backgroundColor: Colors.green.withOpacity(0.15),
                          )
                        else
                          TextButton(
                            onPressed: () => _openGoalPicker(goalRef: goalRef, currentTarget: target),
                            child: const Text('Hedefi değiştir'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$score / $target puan'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text(
                      isDone ? 'Bugünkü hedefi bitirdin, helal! 🎉' : 'Kalan: ${remaining > 0 ? remaining : 0} puan',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}