import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/daily_goal_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _todayScoreStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _todayGoalStream;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    _userDocStream = userRef.snapshots();
    _todayScoreStream = userRef.collection('dailyScores').doc(_todayKey()).snapshots();
    _todayGoalStream = userRef.collection('dailyGoals').doc(_todayKey()).snapshots();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Lütfen tekrar giriş yapın.'),
        ),
      );
    }

    if (_userDocStream == null || _todayScoreStream == null || _todayGoalStream == null) {
      _setupStreams();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wordio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = (userSnap.data?.data() ?? <String, dynamic>{});

            final totalScore = (userData['totalScore'] ?? 0) as int;
            final weeklyScore = (userData['weeklyScore'] ?? 0) as int;
            final currentStreak = (userData['currentStreak'] ?? 0) as int;
            final longestStreak = (userData['longestStreak'] ?? 0) as int;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _todayScoreStream,
              builder: (context, dailySnap) {
                final dailyData = (dailySnap.data?.data() ?? <String, dynamic>{});
                final todayScore = (dailyData['score'] ?? 0) as int;

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _todayGoalStream,
                  builder: (context, goalSnap) {
                    final goalData = (goalSnap.data?.data() ?? <String, dynamic>{});
                    final targetPoints = (goalData['targetPoints'] ?? 50) as int;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selamlama
                          Text(
                            'Merhaba, ${user.displayName ?? user.email ?? 'Öğrenci'} 👋',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bugün biraz İngilizce çalışalım mı? 💬',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),

                          // Skor Kartları
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Toplam Puan',
                                  value: totalScore.toString(),
                                  icon: Icons.star,
                                  color: Colors.amber.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Haftalık Puan',
                                  value: weeklyScore.toString(),
                                  icon: Icons.bolt,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Streak',
                                  value: '$currentStreak gün',
                                  icon: Icons.local_fire_department,
                                  color: Colors.deepOrange,
                                  subtitle: 'En uzun: $longestStreak',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Bugünkü Puan',
                                  value: '$todayScore / $targetPoints',
                                  icon: Icons.flag,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ✅ Yeni: Günlük hedef kartı (dailyGoals + dailyScores okur)
                          const DailyGoalCard(),

                          const SizedBox(height: 16),

                          // Ana Aksiyon Kartları
                          Text(
                            'Ne yapmak istersin?',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          _ActionCard(
                            icon: Icons.menu_book,
                            title: 'Dersler',
                            description: 'Seviyene göre modüller ve dersler',
                            color: Colors.indigo.shade400,
                            onTap: () => context.push('/lessons'),
                          ),
                          const SizedBox(height: 12),

                          _ActionCard(
                            icon: Icons.translate,
                            title: 'Kelime Quiz’i',
                            description: 'Karışık kelimelerle genel kelime bilginı test et',
                            color: Colors.teal.shade400,
                            onTap: () => context.push('/word-quiz'),
                          ),
                          const SizedBox(height: 12),

                          _ActionCard(
                            icon: Icons.refresh,
                            title: 'Tekrar (Review)',
                            description: 'Yanlış yaptığın kelimeleri tekrar ederek pekiştir',
                            color: Colors.deepPurple.shade400,
                            onTap: () => context.push('/review'),
                          ),
                          const SizedBox(height: 12),

                          _ActionCard(
                            icon: Icons.leaderboard,
                            title: 'Leaderboard',
                            description: 'Diğer oyuncularla sıralamanı gör',
                            color: Colors.orange.shade400,
                            onTap: () => context.push('/leaderboard'),
                          ),
                          const SizedBox(height: 12),

                          _ActionCard(
                            icon: Icons.person,
                            title: 'Profil',
                            description: 'Günlük hedefini ve profil bilgilerini düzenle',
                            color: Colors.grey.shade700,
                            onTap: () => context.push('/profile'),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}