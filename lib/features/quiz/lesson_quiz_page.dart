import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/progress_service.dart';
import '../../services/score_service.dart';

// ✅ Normalize için (noktalama/boşluk/case toleransı)
import 'core/quiz_utils.dart';

class LessonQuizPage extends StatefulWidget {
  final String moduleId;
  final String lessonId;
  final String title;

  const LessonQuizPage({
    super.key,
    required this.moduleId,
    required this.lessonId,
    required this.title,
  });

  @override
  State<LessonQuizPage> createState() => _LessonQuizPageState();
}

class _LessonQuizPageState extends State<LessonQuizPage> {
  bool _isLoading = true;
  bool _isFinished = false;

  final List<_LessonQuestion> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;

  // ✅ ScoreService uyumlu skor detayları
  int _earned = 0;
  int _basePoints = 0;
  int _comboPoints = 0;
  int _completionBonus = 0;

  // ✅ Combo
  int _currentCombo = 0;
  int _bestCombo = 0;

  // Cümle kurma sorusu için seçim durumu
  List<int> _selectedTokenIndices = [];

  // Boşluk doldurma sorusu için controller
  final TextEditingController _gapController = TextEditingController();

  // Bir soruya sadece 1 kez cevap verme kilidi
  bool _hasAnsweredCurrent = false;

  // Soru sonrası ekranda gözükecek bildirim kartı
  String? _feedbackTitle;
  String? _feedbackDetail;
  bool _feedbackIsCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _gapController.dispose();
    super.dispose();
  }

  void _resetFeedback() {
    _feedbackTitle = null;
    _feedbackDetail = null;
    _feedbackIsCorrect = false;
  }

  void _updateCombo(bool isCorrect) {
    if (isCorrect) {
      _currentCombo++;
      if (_currentCombo > _bestCombo) _bestCombo = _currentCombo;
    } else {
      _currentCombo = 0;
    }
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _isFinished = false;
      _currentIndex = 0;
      _correctCount = 0;

      _earned = 0;
      _basePoints = 0;
      _comboPoints = 0;
      _completionBonus = 0;

      _currentCombo = 0;
      _bestCombo = 0;

      _questions.clear();
      _selectedTokenIndices = [];
      _gapController.clear();
      _hasAnsweredCurrent = false;
      _resetFeedback();
    });

    final firestore = FirebaseFirestore.instance;
    final List<_LessonQuestion> tmpQuestions = [];

    try {
      // 1) Bu derse bağlı kelimelerden ŞIKLI sorular üret
      final wordSnap = await firestore
          .collection('words')
          .where('moduleId', isEqualTo: widget.moduleId)
          .where('lessonId', isEqualTo: widget.lessonId)
          .get();

      final words = wordSnap.docs.map((d) => _LessonWord.fromDoc(d)).toList()
        ..removeWhere((w) => w.english.isEmpty || w.turkish.isEmpty);

      if (words.length >= 2) {
        words.shuffle();
        final allTurkish = words.map((w) => w.turkish).toList();

        for (final w in words) {
          final List<String> options = [];
          options.add(w.turkish);

          // Yanlış şıklar: diğer kelimelerin Türkçeleri
          final others = allTurkish.where((t) => t != w.turkish).toList()
            ..shuffle();

          for (var i = 0; i < 3 && i < others.length; i++) {
            options.add(others[i]);
          }

          final uniqueOptions = options.toSet().toList()..shuffle();
          final correctIndex = uniqueOptions.indexOf(w.turkish);

          if (correctIndex >= 0) {
            tmpQuestions.add(
              _LessonQuestion.choice(
                word: w,
                options: uniqueOptions,
                correctIndex: correctIndex,
              ),
            );
          }
        }
      }

      // 2) Cümle kurma sorularını çek (sentenceQuestions koleksiyonu)
      final sentenceSnap = await firestore
          .collection('sentenceQuestions')
          .where('moduleId', isEqualTo: widget.moduleId)
          .where('lessonId', isEqualTo: widget.lessonId)
          .get();

      for (final doc in sentenceSnap.docs) {
        final data = doc.data();
        final sentenceEN = (data['sentenceEN'] ?? '').toString().trim();
        final sentenceTR = (data['sentenceTR'] ?? '').toString().trim();

        if (sentenceEN.isEmpty) continue;

        // Cümleyi kelimelere böl
        final tokens = sentenceEN.split(RegExp(r'\s+')).toList();
        tokens.shuffle();

        tmpQuestions.add(
          _LessonQuestion.sentence(
            sentenceEN: sentenceEN,
            sentenceTR: sentenceTR,
            tokens: tokens,
          ),
        );
      }

      // 3) Boşluk doldurma sorularını çek (gapQuestions koleksiyonu)
      final gapSnap = await firestore
          .collection('gapQuestions')
          .where('moduleId', isEqualTo: widget.moduleId)
          .where('lessonId', isEqualTo: widget.lessonId)
          .get();

      for (final doc in gapSnap.docs) {
        final data = doc.data();
        final prefix = (data['prefixEN'] ?? '').toString();
        final suffix = (data['suffixEN'] ?? '').toString();
        final answer = (data['answer'] ?? '').toString();
        final hintTR = (data['hintTR'] ?? '').toString();

        if (answer.trim().isEmpty) continue;

        tmpQuestions.add(
          _LessonQuestion.gap(
            prefixEN: prefix,
            suffixEN: suffix,
            answerEN: answer,
            hintTR: hintTR,
          ),
        );
      }

      if (tmpQuestions.isEmpty) {
        setState(() {
          _isLoading = false;
          _questions.clear();
        });
        return;
      }

      tmpQuestions.shuffle();

      setState(() {
        _questions.addAll(tmpQuestions);
        _isLoading = false;
        _selectedTokenIndices = [];
        _gapController.clear();
        _hasAnsweredCurrent = false;
        _resetFeedback();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _questions.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ders quiz yüklenirken hata: $e')),
      );
    }
  }

  /// 👉 Bir sonraki soruya geçiş (veya quiz bitiş)
  Future<void> _goNextQuestion() async {
    if (_currentIndex == _questions.length - 1) {
      await _finishQuiz();
    } else {
      setState(() {
        _currentIndex++;
        _selectedTokenIndices = [];
        _gapController.clear();
        _hasAnsweredCurrent = false;
        _resetFeedback();
      });
    }
  }

  /// ---- ŞIKLI SORU CEVABI ----
  void _onChoiceAnswerTap(int selectedIndex) {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final current = _questions[_currentIndex];
    if (current.type != LessonQuestionType.choice) return;

    final isCorrect = selectedIndex == current.correctIndex;

    setState(() {
      _hasAnsweredCurrent = true;

      if (isCorrect) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Doğru! ✅';
        _feedbackDetail =
        '"${current.word!.english}" kelimesinin anlamı: ${current.word!.turkish}';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış cevap ❌';
        final correctText = current.options![current.correctIndex!];
        _feedbackDetail =
        'Doğru cevap: $correctText\nKelime: ${current.word!.english}';
      }

      _updateCombo(isCorrect);
    });
  }

  /// ---- CÜMLE KURMA SORUSU ----
  void _onSentenceTokenTap(int index) {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;
    if (_selectedTokenIndices.contains(index)) return;

    setState(() {
      _selectedTokenIndices.add(index);
    });
  }

  void _onSentenceUndo() {
    if (_hasAnsweredCurrent) return;
    if (_selectedTokenIndices.isEmpty) return;
    setState(() {
      _selectedTokenIndices.removeLast();
    });
  }

  void _onSentenceClear() {
    if (_hasAnsweredCurrent) return;
    setState(() {
      _selectedTokenIndices = [];
    });
  }

  Future<void> _onSentenceCheck() async {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final current = _questions[_currentIndex];
    if (current.type != LessonQuestionType.sentence) return;

    final tokens = current.sentenceTokens!;
    final target = current.sentenceEN!.trim();

    if (_selectedTokenIndices.isEmpty) {
      setState(() {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Önce cümleyi kurmalısın';
        _feedbackDetail =
        'Kelimelere dokunarak cümleyi oluştur, ardından "Kontrol et" butonuna bas.';
      });
      return;
    }

    final built = _selectedTokenIndices.map((i) => tokens[i]).join(' ').trim();
    final ok = normalizeAnswer(built) == normalizeAnswer(target);

    setState(() {
      _hasAnsweredCurrent = true;

      if (ok) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Harika, cümleyi doğru kurdun! ✅';
        _feedbackDetail = 'Doğru cümle: "$target"';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış cevap ❌';
        _feedbackDetail = 'Doğru cümle: "$target"';
      }

      _updateCombo(ok);
    });
  }

  /// ---- BOŞLUK DOLDURMA ----
  Future<void> _onGapCheck() async {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final current = _questions[_currentIndex];
    if (current.type != LessonQuestionType.gap) return;

    final correctRaw = (current.gapAnswer ?? '').trim();
    final userRaw = _gapController.text.trim();

    if (userRaw.isEmpty) {
      setState(() {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Önce boşluğu doldur';
        _feedbackDetail =
        'Cümledeki boşluğa uygun kelimeyi yazıp tekrar "Kontrol et" butonuna bas.';
      });
      return;
    }

    // ✅ toleranslı kıyas
    final ok = normalizeAnswer(userRaw) == normalizeAnswer(correctRaw);

    setState(() {
      _hasAnsweredCurrent = true;

      if (ok) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Doğru! ✅';
        _feedbackDetail = 'Doğru cevap: "$correctRaw"';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış cevap ❌';
        _feedbackDetail = 'Doğru cevap: "$correctRaw"';
      }

      _updateCombo(ok);
    });
  }

  /// ---- QUIZ BİTİŞİ ----
  Future<void> _finishQuiz() async {
    final total = _questions.length;

    setState(() {
      _isFinished = true;
      _resetFeedback();
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ✅ Ders quiz sonucu: lessonQuiz mode
      final result =
      await ScoreService(FirebaseFirestore.instance).applyQuizResult(
        uid: user.uid,
        mode: ScoreMode.lessonQuiz,
        correct: _correctCount,
        total: total,
        bestComboInRun: _bestCombo,
      );

      setState(() {
        _earned = result.totalEarned;
        _basePoints = result.basePoints;
        _comboPoints = result.comboPoints;
        _completionBonus = result.completionBonus;
        _bestCombo = result.bestComboInRun;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$total sorudan $_correctCount doğru. '
                '${_earned > 0 ? '$_earned puan kazandın! 🎉' : 'Bu dersten puan kazanamadın.'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Puan kaydedilemedi: $e')),
      );
    }

    // ✅ Ders tamamlandı kaydı (HEM array HEM subcollection)
    await _markLessonCompleted();
  }

  /// ✅ Bu dersin tamamlandığını hem array'e hem subcollection'a yazar.
  Future<void> _markLessonCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    // 1) Subcollection
    await ProgressService(db).markLessonCompleted(
      uid: uid,
      moduleId: widget.moduleId,
      lessonId: widget.lessonId,
    );

    // 2) Array (eski ekranlar için uyumluluk)
    await db.collection('users').doc(uid).set({
      'completedLessons': FieldValue.arrayUnion([widget.lessonId]),
    }, SetOptions(merge: true));
  }

  void _retryQuiz() {
    _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = '${widget.title} – Quiz';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(titleText)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(titleText)),
        body: const Center(child: Text('Bu ders için soru bulunamadı.')),
      );
    }

    if (_isFinished) {
      final total = _questions.length;
      return Scaffold(
        appBar: AppBar(title: Text(titleText)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quiz tamamlandı!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('$total sorudan $_correctCount tanesini doğru yaptın.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _retryQuiz,
                  icon: const Icon(Icons.replay),
                  label: const Text('Bu dersi tekrar çöz'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Ana sayfaya dön'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final current = _questions[_currentIndex];
    final total = _questions.length;

    return Scaffold(
      appBar: AppBar(title: Text(titleText)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soru ${_currentIndex + 1} / $total',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_currentIndex + 1) / total),
            const SizedBox(height: 16),
            if (_feedbackTitle != null) _buildFeedbackCard(context),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: current.type == LessonQuestionType.choice
                    ? _buildChoiceQuestion(context, current)
                    : current.type == LessonQuestionType.sentence
                    ? _buildSentenceQuestion(context, current)
                    : _buildGapQuestion(context, current),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _hasAnsweredCurrent ? () => _goNextQuestion() : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                    _currentIndex == total - 1 ? 'Quizi bitir' : 'Sonraki soru'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    final bgColor = _feedbackIsCorrect
        ? Colors.green.withOpacity(0.1)
        : Colors.red.withOpacity(0.08);
    final icon = _feedbackIsCorrect ? Icons.check_circle : Icons.info;
    final iconColor = _feedbackIsCorrect ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _feedbackIsCorrect ? Colors.green : Colors.redAccent,
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_feedbackTitle ?? '',
                    style: Theme.of(context).textTheme.titleMedium),
                if (_feedbackDetail != null &&
                    _feedbackDetail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_feedbackDetail!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceQuestion(BuildContext context, _LessonQuestion current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            current.word!.english,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Text('Bu kelimenin Türkçe karşılığını seç:',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        ...List.generate(current.options!.length, (index) {
          final option = current.options![index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                _hasAnsweredCurrent ? null : () => _onChoiceAnswerTap(index),
                child: Text(option),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSentenceQuestion(BuildContext context, _LessonQuestion current) {
    final tokens = current.sentenceTokens!;
    final builtSentence = _selectedTokenIndices.isEmpty
        ? ''
        : _selectedTokenIndices.map((i) => tokens[i]).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current.sentenceTR != null && current.sentenceTR!.isNotEmpty) ...[
          Text('Aşağıdaki Türkçe cümleyi İngilizce olarak kur:',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            current.sentenceTR!,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ] else ...[
          Text('Bu İngilizce cümleyi doğru sırada kur:',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            '(Cümle: ${current.sentenceEN})',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.withOpacity(0.05),
          ),
          child: Text(
            builtSentence.isEmpty
                ? 'Seçtiğin kelimeler burada gözükecek.'
                : builtSentence,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(tokens.length, (index) {
            final token = tokens[index];
            final isSelected = _selectedTokenIndices.contains(index);
            return ChoiceChip(
              label: Text(token),
              selected: isSelected,
              onSelected:
              _hasAnsweredCurrent ? null : (_) => _onSentenceTokenTap(index),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _hasAnsweredCurrent ? null : _onSentenceCheck,
              icon: const Icon(Icons.check),
              label: const Text('Kontrol et'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _hasAnsweredCurrent ? null : _onSentenceUndo,
              icon: const Icon(Icons.undo),
              label: const Text('Geri al'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _hasAnsweredCurrent ? null : _onSentenceClear,
              child: const Text('Temizle'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGapQuestion(BuildContext context, _LessonQuestion current) {
    final prefix = current.gapPrefixEN ?? '';
    final suffix = current.gapSuffixEN ?? '';
    final hintTR = current.gapHintTR ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hintTR.isNotEmpty) ...[
          Text('Aşağıdaki Türkçe cümleyi tamamla:',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            hintTR,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text('Cümledeki boşluğu uygun kelime ile doldur:',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
        ],
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleMedium,
            children: [
              TextSpan(text: prefix),
              const WidgetSpan(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('______',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              TextSpan(text: suffix),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _gapController,
          enabled: !_hasAnsweredCurrent,
          decoration: const InputDecoration(
            labelText: 'Boşluğu doldur',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _hasAnsweredCurrent ? null : _onGapCheck,
          icon: const Icon(Icons.check),
          label: const Text('Kontrol et'),
        ),
      ],
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

/// ----------------- MODELLER -----------------

enum LessonQuestionType { choice, sentence, gap }

class _LessonWord {
  final String id;
  final String english;
  final String turkish;

  _LessonWord({
    required this.id,
    required this.english,
    required this.turkish,
  });

  factory _LessonWord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final english =
    (data['word'] ?? data['text'] ?? data['english'] ?? data['en'] ?? '')
        .toString();
    final turkish = (data['meaningTR'] ??
        data['translation'] ??
        data['meaning'] ??
        data['turkish'] ??
        data['tr'] ??
        '')
        .toString();

    return _LessonWord(
      id: doc.id,
      english: english,
      turkish: turkish,
    );
  }
}

class _LessonQuestion {
  final LessonQuestionType type;

  final _LessonWord? word;
  final List<String>? options;
  final int? correctIndex;

  final String? sentenceEN;
  final String? sentenceTR;
  final List<String>? sentenceTokens;

  final String? gapPrefixEN;
  final String? gapSuffixEN;
  final String? gapAnswer;
  final String? gapHintTR;

  _LessonQuestion.choice({
    required _LessonWord word,
    required List<String> options,
    required int correctIndex,
  })  : type = LessonQuestionType.choice,
        word = word,
        options = options,
        correctIndex = correctIndex,
        sentenceEN = null,
        sentenceTR = null,
        sentenceTokens = null,
        gapPrefixEN = null,
        gapSuffixEN = null,
        gapAnswer = null,
        gapHintTR = null;

  _LessonQuestion.sentence({
    required String sentenceEN,
    String? sentenceTR,
    required List<String> tokens,
  })  : type = LessonQuestionType.sentence,
        sentenceEN = sentenceEN,
        sentenceTR = sentenceTR,
        sentenceTokens = tokens,
        word = null,
        options = null,
        correctIndex = null,
        gapPrefixEN = null,
        gapSuffixEN = null,
        gapAnswer = null,
        gapHintTR = null;

  _LessonQuestion.gap({
    required String prefixEN,
    required String suffixEN,
    required String answerEN,
    String? hintTR,
  })  : type = LessonQuestionType.gap,
        gapPrefixEN = prefixEN,
        gapSuffixEN = suffixEN,
        gapAnswer = answerEN,
        gapHintTR = hintTR,
        word = null,
        options = null,
        correctIndex = null,
        sentenceEN = null,
        sentenceTR = null,
        sentenceTokens = null;
}