import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'module_lessons_page.dart';

class LessonsPage extends StatelessWidget {
  const LessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream =
    user == null
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    final Stream<QuerySnapshot<Map<String, dynamic>>> modulesStream =
    FirebaseFirestore.instance
        .collection('modules')
        .orderBy('order')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dersler'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() ?? {};
            final completedLessonsRaw =
            (userData['completedLessons'] ?? []) as List<dynamic>;
            final completedLessons =
            completedLessonsRaw.map((e) => e.toString()).toSet();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: modulesStream,
              builder: (context, moduleSnap) {
                if (moduleSnap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (moduleSnap.hasError) {
                  return Center(
                    child: Text(
                      'Modüller yüklenirken hata oluştu:\n${moduleSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final docs = moduleSnap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Henüz modül eklenmemiş.'),
                  );
                }

                final modules = docs.map((d) {
                  final data = d.data();
                  return _ModuleItem(
                    moduleId: d.id,
                    title: (data['title'] ?? '').toString(),
                    description: (data['description'] ?? '').toString(),
                    order: (data['order'] ?? 0) as int,
                  );
                }).toList()
                  ..sort((a, b) => a.order.compareTo(b.order));

                return ListView.separated(
                  itemCount: modules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final module = modules[index];

                    // Bu modüle ait ders sayısı ve tamamlananlar için ayrı stream
                    final lessonsStream = FirebaseFirestore.instance
                        .collection('lessons')
                        .where('moduleId', isEqualTo: module.moduleId)
                        .snapshots();

                    return StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: lessonsStream,
                      builder: (context, lessonSnap) {
                        final lessonDocs = lessonSnap.data?.docs ?? [];
                        final totalLessons = lessonDocs.length;

                        int completedCount = 0;
                        for (final ld in lessonDocs) {
                          final ldata = ld.data();
                          final lid =
                          (ldata['lessonId'] ?? ld.id).toString();
                          if (completedLessons.contains(lid)) {
                            completedCount++;
                          }
                        }

                        final progress = totalLessons == 0
                            ? 0.0
                            : completedCount / totalLessons;

                        return Material(
                          color: Colors.white,
                          elevation: 1,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ModuleLessonsPage(
                                    moduleId: module.moduleId,
                                    moduleTitle: module.title,
                                    moduleDescription:
                                    module.description,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    module.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if (module.description.isNotEmpty)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(top: 4),
                                      child: Text(
                                        module.description,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (totalLessons > 0) ...[
                                    LinearProgressIndicator(
                                      value: progress,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedCount / $totalLessons ders tamamlandı',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ] else
                                    Text(
                                      'Bu modülde henüz ders yok.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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

class _ModuleItem {
  final String moduleId;
  final String title;
  final String description;
  final int order;

  _ModuleItem({
    required this.moduleId,
    required this.title,
    required this.description,
    required this.order,
  });
}