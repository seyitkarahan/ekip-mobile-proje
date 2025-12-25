import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/profile_service.dart';
import '../../services/progress_service.dart';
import '../../services/badge_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameCtrl = TextEditingController();
  bool _saving = false;

  bool _didMigrate = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUsername(String uid) async {
    final name = _usernameCtrl.text;

    setState(() => _saving = true);
    try {
      await ProfileService(FirebaseFirestore.instance).updateUsername(
        uid: uid,
        username: name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı güncellendi ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapmalısın.')));
    }

    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    final progressSvc = ProgressService(db);
    final badgeSvc = BadgeService(db);

    final userRef = db.collection('users').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          final data = userSnap.data?.data() ?? {};
          final username = (data['username'] ?? '').toString();
          final totalScore = (data['totalScore'] ?? 0) as int;
          final weeklyScore = (data['weeklyScore'] ?? 0) as int;
          final currentStreak = (data['currentStreak'] ?? 0) as int;
          final longestStreak = (data['longestStreak'] ?? 0) as int;

          if (_usernameCtrl.text.isEmpty && username.isNotEmpty) {
            _usernameCtrl.text = username;
          }

          // ✅ 1 kere migration çalıştır (array -> subcollection)
          if (!_didMigrate) {
            _didMigrate = true;
            Future.microtask(() async {
              await progressSvc.migrateArrayCompletedLessonsToSubcollection(uid: uid);
            });
          }

          return FutureBuilder<Map<String, int>>(
            future: progressSvc.fetchModuleLessonTotals(),
            builder: (context, totalsSnap) {
              final moduleTotals = totalsSnap.data ?? {};

              return StreamBuilder<Map<String, int>>(
                stream: progressSvc.completedByModuleStream(uid),
                builder: (context, completedByModuleSnap) {
                  final completedByModule = completedByModuleSnap.data ?? {};

                  final completedLessons =
                  completedByModule.values.fold<int>(0, (a, b) => a + b);

                  int completedModules = 0;
                  for (final entry in moduleTotals.entries) {
                    final done = completedByModule[entry.key] ?? 0;
                    if (entry.value > 0 && done >= entry.value) completedModules++;
                  }

                  badgeSvc.evaluateAndGrant(
                    uid: uid,
                    totalScore: totalScore,
                    currentStreak: currentStreak,
                    completedLessons: completedLessons,
                    completedModules: completedModules,
                  );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _usernameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Kullanıcı Adı',
                                  hintText: 'örn: taha_55',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saving ? null : () => _saveUsername(uid),
                                  icon: _saving
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Icon(Icons.save),
                                  label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/badges'),
                                  icon: const Icon(Icons.emoji_events),
                                  label: const Text('Rozetlerimi Gör'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _StatsRow(
                        items: [
                          _StatItem('Toplam Puan', totalScore.toString(), Icons.stars),
                          _StatItem('Haftalık', weeklyScore.toString(), Icons.calendar_month),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _StatsRow(
                        items: [
                          _StatItem('Streak', currentStreak.toString(), Icons.local_fire_department),
                          _StatItem('En Uzun', longestStreak.toString(), Icons.bolt),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('İlerleme', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              Text('Tamamlanan ders: $completedLessons'),
                              Text('Tamamlanan modül: $completedModules'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Modül İlerlemesi', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              if (moduleTotals.isEmpty)
                                const Text('Modüller bulunamadı.')
                              else
                                ...moduleTotals.entries.map((e) {
                                  final done = completedByModule[e.key] ?? 0;
                                  final total = e.value;
                                  final value = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Modül: ${e.key}  ($done/$total)'),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(value: value),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!mounted) return;
                            context.go('/login');
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Çıkış Yap'),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (e) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Icon(e.icon),
                  const SizedBox(height: 8),
                  Text(
                    e.value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(e.label),
                ],
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  _StatItem(this.label, this.value, this.icon);
}