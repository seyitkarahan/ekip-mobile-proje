import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/progress_service.dart';

class ModuleLessonsPage extends StatelessWidget {
  final String moduleId;
  final String moduleTitle;
  final String moduleDescription;

  const ModuleLessonsPage({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
    required this.moduleDescription,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Kullanıcı oturumu bulunamadı.')),
      );
    }

    final db = FirebaseFirestore.instance;
    final progressSvc = ProgressService(db);

    // ✅ Bu modüle ait dersler (KİLİT mantığı için order şart!)
    final lessonsStream = db
        .collection('lessons')
        .where('moduleId', isEqualTo: moduleId)
        .orderBy('order')
        .snapshots();

    // ✅ Subcollection (bu modülde tamamlanan lessonId’ler)
    final completedStream = progressSvc.completedLessonIdsForModuleStream(
      uid: user.uid,
      moduleId: moduleId,
    );

    // ✅ Array fallback için user doc (eski veri)
    final userDocStream = db.collection('users').doc(user.uid).snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(moduleTitle)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: lessonsStream,
        builder: (context, lessonSnap) {
          if (lessonSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (lessonSnap.hasError) {
            return Center(
              child: Text('Dersler yüklenirken hata oluştu: ${lessonSnap.error}'),
            );
          }

          final lessonDocs = lessonSnap.data?.docs ?? [];
          if (lessonDocs.isEmpty) {
            return const Center(child: Text('Bu modüle ait ders yok.'));
          }

          final moduleLessonIds = lessonDocs.map((d) => d.id).toSet();

          return StreamBuilder<Set<String>>(
            stream: completedStream,
            builder: (context, completedSubSnap) {
              if (completedSubSnap.hasError) {
                return Center(
                  child: Text('Progress okunamadı: ${completedSubSnap.error}'),
                );
              }

              // (Loading anında yanlış kilit göstermemek için bekliyoruz)
              if (completedSubSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final completedFromSub = completedSubSnap.data ?? <String>{};

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userDocStream,
                builder: (context, userSnap) {
                  if (userSnap.hasError) {
                    return Center(
                      child: Text('Kullanıcı verisi okunamadı: ${userSnap.error}'),
                    );
                  }

                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userData = userSnap.data?.data() ?? {};

                  // ✅ SAFE: completedLessons yoksa / list değilse patlamasın
                  final raw = userData['completedLessons'];
                  final List<dynamic> rawCompleted =
                  raw is List ? raw : const <dynamic>[];

                  final completedFromArray =
                  rawCompleted.map((e) => e.toString()).toSet();

                  // ✅ birleşik: subcollection + array
                  final completedUnion = <String>{}
                    ..addAll(completedFromSub)
                    ..addAll(completedFromArray);

                  // ✅ sadece bu modülün dersleri
                  final completedLessonIds = completedUnion
                      .where((id) => moduleLessonIds.contains(id))
                      .toSet();

                  final totalLessons = lessonDocs.length;
                  final completedCount = completedLessonIds.length;
                  final allCompleted =
                      totalLessons > 0 && completedCount == totalLessons;

                  final progress = totalLessons > 0
                      ? (completedCount / totalLessons).clamp(0.0, 1.0)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(moduleTitle,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        if (moduleDescription.isNotEmpty)
                          Text(moduleDescription,
                              style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modül ilerlemesi: $completedCount / $totalLessons ders',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: progress),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Expanded(
                          child: ListView.separated(
                            itemCount: lessonDocs.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final lessonDoc = lessonDocs[index];
                              final lessonId = lessonDoc.id;
                              final data = lessonDoc.data();

                              final title = (data['title'] ?? 'Ders').toString();
                              final description =
                              (data['description'] ?? '').toString();
                              final order = data['order'];

                              final isCompleted =
                              completedLessonIds.contains(lessonId);

                              // ✅ Kilit mantığı: sadece bir sonraki dersi aç (sıralama artık order’a göre)
                              bool isLocked = false;
                              if (index > 0) {
                                final prevLessonId = lessonDocs[index - 1].id;
                                if (!completedLessonIds.contains(prevLessonId)) {
                                  isLocked = true;
                                }
                              }

                              final tileBg = Theme.of(context)
                                  .colorScheme
                                  .surface; // dark mode uyum

                              return InkWell(
                                onTap: isLocked
                                    ? null
                                    : () {
                                  context.push(
                                    '/lesson-learn/$moduleId/$lessonId',
                                    extra: {'title': title},
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tileBg,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: isCompleted
                                          ? Colors.green.withOpacity(0.25)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isCompleted
                                          ? Colors.green.withOpacity(0.18)
                                          : Colors.deepPurple.withOpacity(0.18),
                                      child: Text(
                                        order?.toString() ??
                                            (index + 1).toString(),
                                        style: TextStyle(
                                          color: isCompleted
                                              ? Colors.green.shade800
                                              : Colors.deepPurple.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted
                                            ? Colors.green.shade800
                                            : null,
                                      ),
                                    ),
                                    subtitle: description.isNotEmpty
                                        ? Text(
                                      description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                        : null,
                                    trailing: Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : (isLocked
                                          ? Icons.lock
                                          : Icons.play_arrow),
                                      color: isCompleted
                                          ? Colors.green
                                          : (isLocked
                                          ? Colors.grey
                                          : Colors.deepPurple),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: allCompleted
                                ? () {
                              final encodedTitle =
                              Uri.encodeComponent(moduleTitle);
                              context.push(
                                  '/module-exam/$moduleId?title=$encodedTitle');
                            }
                                : null,
                            icon: const Icon(Icons.school),
                            label: Text(allCompleted
                                ? 'Modül sınavını başlat'
                                : 'Önce tüm dersleri tamamla'),
                          ),
                        ),
                      ],
                    ),
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