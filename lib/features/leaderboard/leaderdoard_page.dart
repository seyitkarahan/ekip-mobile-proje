import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _topUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('totalScore', descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _topUsersStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz kullanıcı yok.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final username = (data['username'] ?? 'user') as String;
              final score = (data['totalScore'] ?? 0) as int;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(username),
                  trailing: Text(
                    '$score',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}