import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/word_quiz_models.dart';
import '../../../services/mistake_service.dart';
import '../../../services/score_service.dart';

import '../core/quiz_engine.dart';
import '../core/quiz_utils.dart';
import '../widgets/quiz_feedback_next.dart';

class WordQuizPage extends StatefulWidget {
  const WordQuizPage({super.key});

  @override
  State<WordQuizPage> createState() => _WordQuizPageState();
}

class _WordQuizPageState extends State<WordQuizPage> {
  static const int _maxQuestionCount = 20;

  bool _isLoading = true;
  bool _isFinished = false;

  final List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;

  // ✅ Skor / combo
  int _earned = 0;
  int _currentCombo = 0;
  int _bestCombo = 0;
  int _comboPoints = 0;

  // ✅ Breakdown
  int _basePoints = 0;
  int _completionBonus = 0;

  bool _hasAnsweredCurrent = false;
  int? _selectedOptionIndex;

  // ✅ Cümle kurma
  final List<int> _selectedTokenIds = [];

  String? _feedbackTitle;
  String? _feedbackDetail;
  bool _feedbackIsCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Widget _typeChip(QuizQuestionType t) {
    String text = 'ŞIKLI';
    IconData icon = Icons.checklist;

    if (t == QuizQuestionType.fillBlank) {
      text = 'BOŞLUK';
      icon = Icons.edit;
    } else if (t == QuizQuestionType.translateMcq) {
      text = 'ÇEVİRİ';
      icon = Icons.translate;
    } else if (t == QuizQuestionType.sentenceBuild) {
      text = 'CÜMLE KUR';
      icon = Icons.view_list;
    }

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
    );
  }

  void _updateCombo(bool isCorrect) {
    if (isCorrect) {
      _currentCombo++;
      if (_currentCombo > _bestCombo) _bestCombo = _currentCombo;
    } else {
      _currentCombo = 0;
    }
  }

  // -------------------- LOAD --------------------

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _isFinished = false;
      _currentIndex = 0;
      _correctCount = 0;

      _earned = 0;
      _currentCombo = 0;
      _bestCombo = 0;
      _comboPoints = 0;

      _basePoints = 0;
      _completionBonus = 0;

      _questions.clear();
      _hasAnsweredCurrent = false;
      _selectedOptionIndex = null;
      _selectedTokenIds.clear();

      _feedbackTitle = null;
      _feedbackDetail = null;
      _feedbackIsCorrect = false;
    });

    try {
      final snap =
      await FirebaseFirestore.instance.collection('words').limit(250).get();

      final words = snap.docs
          .map((d) => QuizWord.fromDoc(d))
          .where((w) => w.english.isNotEmpty && w.turkish.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      words.shuffle();

      final built = QuizEngine.buildQuiz(
        focusWords: words,
        globalWords: words,
        maxQuestionCount: _maxQuestionCount,
        // Word quiz’de cümle soruları mistakes’e yazılmasın:
        trackMistakesForSentenceQuestions: false,
      );

      setState(() {
        _questions.addAll(built);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _questions.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quiz yüklenirken hata oluştu: $e')),
      );
    }
  }

  // -------------------- ANSWER LOGIC --------------------

  Future<void> _trackMistakeIfNeeded({
    required QuizQuestion q,
    required bool isCorrect,
  }) async {
    if (q.wordId == null || q.wordEN == null || q.wordTR == null) return;

    if (isCorrect) {
      await MistakeService.resolveWordMistake(wordId: q.wordId!);
    } else {
      await MistakeService.saveWordMistake(
        wordId: q.wordId!,
        english: q.wordEN!,
        turkish: q.wordTR!,
      );
    }
  }

  void _answerChoice(int index) async {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final q = _questions[_currentIndex];
    final isCorrect = index == q.correctIndex;

    setState(() {
      _hasAnsweredCurrent = true;
      _selectedOptionIndex = index;

      if (isCorrect) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Doğru! ✅';
        _feedbackDetail = q.explanationCorrect ?? 'Doğru!';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış cevap ❌';
        _feedbackDetail = q.explanationWrong ?? 'Yanlış.';
      }

      _updateCombo(isCorrect);
    });

    await _trackMistakeIfNeeded(q: q, isCorrect: isCorrect);
  }

  // -------- sentence build --------

  void _pickToken(BuildToken t) {
    if (_hasAnsweredCurrent) return;
    setState(() => _selectedTokenIds.add(t.id));
  }

  void _removeLastToken() {
    if (_hasAnsweredCurrent) return;
    if (_selectedTokenIds.isEmpty) return;
    setState(() => _selectedTokenIds.removeLast());
  }

  void _clearBuild() {
    if (_hasAnsweredCurrent) return;
    setState(() => _selectedTokenIds.clear());
  }

  void _checkBuildAnswer() {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final q = _questions[_currentIndex];
    final target = q.targetSentence ?? '';
    final pool = q.buildPool ?? const <BuildToken>[];

    final selectedTexts = _selectedTokenIds
        .map((id) => pool.firstWhere((x) => x.id == id).text)
        .toList();

    final userSentence = selectedTexts.join(' ');
    final ok = normalizeAnswer(userSentence) == normalizeAnswer(target);

    setState(() {
      _hasAnsweredCurrent = true;

      if (ok) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Doğru! ✅';
        _feedbackDetail = q.explanationCorrect ?? 'Harika!';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış ❌';
        _feedbackDetail = q.explanationWrong ?? 'Doğru cümle: $target';
      }

      _updateCombo(ok);
    });
  }

  // -------------------- NAV --------------------

  Future<void> _onNextQuestion() async {
    if (_isFinished || _questions.isEmpty) return;

    if (_currentIndex == _questions.length - 1) {
      await _finishQuiz();
    } else {
      setState(() {
        _currentIndex++;
        _hasAnsweredCurrent = false;
        _selectedOptionIndex = null;
        _selectedTokenIds.clear();

        _feedbackTitle = null;
        _feedbackDetail = null;
        _feedbackIsCorrect = false;
      });
    }
  }

  Future<void> _finishQuiz() async {
    final total = _questions.length;

    setState(() {
      _isFinished = true;
      _feedbackTitle = null;
      _feedbackDetail = null;
      _feedbackIsCorrect = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final result =
      await ScoreService(FirebaseFirestore.instance).applyQuizResult(
        uid: user.uid,
        mode: ScoreMode.wordQuiz,
        correct: _correctCount,
        total: total,
        bestComboInRun: _bestCombo,
      );

      setState(() {
        _earned = result.totalEarned;
        _comboPoints = result.comboPoints;
        _bestCombo = result.bestComboInRun;

        _basePoints = result.basePoints;
        _completionBonus = result.completionBonus;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$total sorudan $_correctCount doğru. '
                '${_earned > 0 ? '$_earned puan kazandın! 🎉' : 'Bu quizden puan kazanamadın.'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Puan kaydedilemedi: $e')),
      );
    }
  }

  void _retryQuiz() => _loadQuestions();

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    const titleText = 'Rastgele Kelime Quiz';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(titleText)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(titleText)),
        body: const Center(child: Text('Quiz sorusu bulunamadı.')),
      );
    }

    if (_isFinished) {
      final total = _questions.length;
      return Scaffold(
        appBar: AppBar(title: const Text(titleText)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quiz tamamlandı!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('$total sorudan $_correctCount doğru.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                'Kazandığın puan: $_earned',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Combo: en iyi $_bestCombo, combo puanı: $_comboPoints'),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Puan Detayı',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _scoreRow('Base', _basePoints),
                      _scoreRow('Combo', _comboPoints),
                      _scoreRow('Bonus', _completionBonus),
                      const Divider(),
                      _scoreRow('Toplam', _earned, isBold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Ana sayfaya dön'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _retryQuiz,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar çöz'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final totalQuestions = _questions.length;
    final isBuild = q.type == QuizQuestionType.sentenceBuild;

    final buildPool = q.buildPool ?? const <BuildToken>[];
    final selectedTokens = _selectedTokenIds
        .map((id) => buildPool.firstWhere((t) => t.id == id))
        .toList();

    final remainingTokens =
    buildPool.where((t) => !_selectedTokenIds.contains(t.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text(titleText)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Soru ${_currentIndex + 1} / $totalQuestions',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                _typeChip(q.type),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: (_currentIndex + 1) / totalQuestions),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.subtitle,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text(q.prompt,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if ((q.type == QuizQuestionType.fillBlank ||
                        q.type == QuizQuestionType.sentenceBuild) &&
                        (q.hintTR ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('TR ipucu: ${q.hintTR}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isBuild) ...[
              Text('Seçtiğin kelimeler:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedTokens.isEmpty
                      ? [const Text('Henüz kelime seçmedin.')]
                      : selectedTokens
                      .map((t) => Chip(label: Text(t.text)))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _hasAnsweredCurrent ? null : _removeLastToken,
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Sil'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _hasAnsweredCurrent ? null : _clearBuild,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Temizle'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed:
                    (_hasAnsweredCurrent || _selectedTokenIds.isEmpty)
                        ? null
                        : _checkBuildAnswer,
                    icon: const Icon(Icons.check),
                    label: const Text('Kontrol et'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Kalan kelimeler:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: remainingTokens
                    .map((t) => ActionChip(
                  label: Text(t.text),
                  onPressed: () => _pickToken(t),
                ))
                    .toList(),
              ),
            ] else ...[
              ...List.generate(q.options.length, (i) {
                final option = q.options[i];

                Color? tileColor;
                IconData? leadingIcon;

                if (_hasAnsweredCurrent) {
                  if (i == q.correctIndex) {
                    tileColor = Colors.green.withAlpha((0.15 * 255).round());
                    leadingIcon = Icons.check_circle;
                  } else if (_selectedOptionIndex == i) {
                    tileColor = Colors.red.withAlpha((0.12 * 255).round());
                    leadingIcon = Icons.cancel;
                  }
                }

                return Card(
                  color: tileColor,
                  child: ListTile(
                    leading: leadingIcon == null ? null : Icon(leadingIcon),
                    title: Text(option),
                    onTap: () => _answerChoice(i),
                  ),
                );
              }),
            ],
            const Spacer(),

            // ✅ Ortak feedback + next butonu (Widget)
            QuizFeedbackNext(
              feedbackTitle: _feedbackTitle,
              feedbackDetail: _feedbackDetail,
              feedbackIsCorrect: _feedbackIsCorrect,
              hasAnswered: _hasAnsweredCurrent,
              isLast: _currentIndex == totalQuestions - 1,
              onNext: _onNextQuestion,
              needAnswerMessage: isBuild
                  ? 'Önce cümleyi kurup "Kontrol et"e bas.'
                  : 'Önce bir cevap ver.',
              finishText: 'Quiz bitir',
              nextText: 'Sonraki soru',
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, int value, {bool isBold = false}) {
    final style = isBold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle(fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value.toString(), style: style),
        ],
      ),
    );
  }
}
