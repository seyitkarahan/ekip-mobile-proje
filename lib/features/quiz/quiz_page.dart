import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/question_model.dart';
import '../../services/score_service.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _qIndex = 0;
  int _correct = 0;
  bool _locked = false;

  Future<List<QuestionModel>> _fetchQuestions() async {
    final snap = await FirebaseFirestore.instance
        .collection('questions')
        .where('level', isEqualTo: 'A1')
        .limit(10)
        .get();

    return snap.docs
        .map((d) => QuestionModel.fromMap(d.id, d.data()))
        .toList();
  }

  int _calculateScore(int correct, int total) {
    final base = correct * 10;
    final bonus = total > 0 ? 20 : 0;
    return base + bonus;
  }

  Future<void> _finishQuiz(int total) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final result = await ScoreService(FirebaseFirestore.instance).applyQuizResult(
      uid: uid,
      mode: ScoreMode.lessonQuiz, // bu sayfa "normal quiz" ise
      correct: _correct,
      total: total,
      bestComboInRun: 0, // bu quizde combo yoksa 0
    );

    if (!mounted) return;

    // İstersen breakdown'u result.breakdown ile taşı
    context.go(
      '/result?correct=$_correct&total=$total&earned=${result.totalEarned}',
      extra: result.breakdown, // sadece Map taşımak istiyorsan
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: FutureBuilder<List<QuestionModel>>(
        future: _fetchQuestions(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final questions = snap.data!;
          if (questions.isEmpty) {
            return const Center(
              child: Text('questions koleksiyonuna A1 soru ekleyin.'),
            );
          }

          if (_qIndex >= questions.length) _qIndex = questions.length - 1;
          final q = questions[_qIndex];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soru ${_qIndex + 1} / ${questions.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  q.questionText,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ...List.generate(q.choices.length, (i) {
                  final choice = q.choices[i];
                  final isCorrect = i == q.correctIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _locked
                            ? null
                            : () async {
                          setState(() => _locked = true);

                          if (isCorrect) _correct++;

                          await Future.delayed(
                            const Duration(milliseconds: 450),
                          );

                          if (!mounted) return;

                          if (_qIndex == questions.length - 1) {
                            await _finishQuiz(questions.length);
                          } else {
                            setState(() {
                              _qIndex++;
                              _locked = false;
                            });
                          }
                        },
                        child: Text(choice),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}