// path: lib/features/quiz/module_exam_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _ExamQuestionType { mcq, fillBlank, translateMcq, sentenceBuild }

class ModuleExamPage extends StatefulWidget {
  final String moduleId;
  final String moduleTitle;

  const ModuleExamPage({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  State<ModuleExamPage> createState() => _ModuleExamPageState();
}

class _ModuleExamPageState extends State<ModuleExamPage> {
  static const int _maxQuestionCount = 15;
  static const int _pointsPerCorrect = 10;

  bool _isLoading = true;
  bool _isFinished = false;

  final List<_ModuleExamQuestion> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _earned = 0;

  bool _hasAnsweredCurrent = false;
  int? _selectedOptionIndex;

  // ✅ Cümle kurma için
  List<String> _buildSelected = [];

  String? _feedbackTitle;
  String? _feedbackDetail;
  bool _feedbackIsCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _todayStr(DateTime now) {
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _blankOutFirstOccurrence({
    required String sentence,
    required String word,
  }) {
    final re = RegExp(RegExp.escape(word), caseSensitive: false);
    final match = re.firstMatch(sentence);
    if (match == null) return sentence;
    return sentence.replaceRange(match.start, match.end, '____');
  }

  // basit normalize: küçük harf + noktalama sil + fazla boşlukları azalt
  String _normalize(String s) {
    final lower = s.toLowerCase().trim();
    final noPunc = lower.replaceAll(RegExp(r"[^\w\s']"), ' ');
    return noPunc.replaceAll(RegExp(r"\s+"), ' ').trim();
  }

  List<String> _tokenizeWords(String sentence) {
    final cleaned = sentence
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();
    if (cleaned.isEmpty) return [];
    return cleaned.split(' ');
  }


  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _isFinished = false;
      _currentIndex = 0;
      _correctCount = 0;
      _earned = 0;
      _questions.clear();

      _hasAnsweredCurrent = false;
      _selectedOptionIndex = null;
      _buildSelected = [];

      _feedbackTitle = null;
      _feedbackDetail = null;
      _feedbackIsCorrect = false;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('words')
          .where('moduleId', isEqualTo: widget.moduleId)
          .get();

      final docs = snap.docs.toList();

      final words = docs
          .map((d) => _ModuleExamWord.fromDoc(d))
          .where((w) => w.english.isNotEmpty && w.turkish.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      words.shuffle();

      final allTurkish = words.map((w) => w.turkish).toList();
      final allEnglish = words.map((w) => w.english).toList();

      final translatePool = words
          .where((w) =>
      w.exampleEN.trim().isNotEmpty && w.exampleTR.trim().isNotEmpty)
          .toList();

      final allExampleTR =
      translatePool.map((w) => w.exampleTR.trim()).toList();

      final List<_ModuleExamQuestion> candidates = [];

      // 1) ŞIKLI (EN -> TR)
      for (final w in words) {
        final options = <String>[w.turkish];
        final others =
        allTurkish.where((t) => t != w.turkish).toList()..shuffle();
        for (var i = 0; i < 3 && i < others.length; i++) {
          options.add(others[i]);
        }
        final unique = options.toSet().toList()..shuffle();
        final correctIndex = unique.indexOf(w.turkish);

        candidates.add(
          _ModuleExamQuestion.choice(
            type: _ExamQuestionType.mcq,
            prompt: w.english,
            subtitle: 'Doğru Türkçe anlamı seç:',
            options: unique,
            correctIndex: correctIndex,
            hintTR: null,
            explanationCorrect:
            '"${w.english}" kelimesinin anlamı: ${w.turkish}',
            explanationWrong: 'Doğru cevap: ${w.turkish}\nKelime: ${w.english}',
          ),
        );
      }

      // 2) BOŞLUK (exampleEN içinden) + ✅ TR İPUCU GÖSTER
      for (final w in words) {
        final ex = w.exampleEN.trim();
        if (ex.isEmpty) continue;

        final containsWord =
        RegExp(RegExp.escape(w.english), caseSensitive: false).hasMatch(ex);
        if (!containsWord) continue;

        final blanked = _blankOutFirstOccurrence(sentence: ex, word: w.english);

        final options = <String>[w.english];
        final others =
        allEnglish.where((t) => t != w.english).toList()..shuffle();
        for (var i = 0; i < 3 && i < others.length; i++) {
          options.add(others[i]);
        }
        final unique = options.toSet().toList()..shuffle();
        final correctIndex = unique.indexOf(w.english);

        // ipucu: varsa exampleTR, yoksa kelimenin anlamı
        final hintTR = w.exampleTR.trim().isNotEmpty
            ? w.exampleTR.trim()
            : 'Kelimenin anlamı: ${w.turkish}';

        candidates.add(
          _ModuleExamQuestion.choice(
            type: _ExamQuestionType.fillBlank,
            prompt: blanked,
            subtitle: 'Boşluğa hangi kelime gelmeli?',
            options: unique,
            correctIndex: correctIndex,
            hintTR: hintTR,
            explanationCorrect: 'Doğru! Kelime: ${w.english}',
            explanationWrong: 'Doğru kelime: ${w.english}',
          ),
        );
      }

      // 3) ÇEVİRİ (exampleEN -> exampleTR) ŞIKLI
      for (final w in translatePool) {
        final exEn = w.exampleEN.trim();
        final exTr = w.exampleTR.trim();

        final options = <String>[exTr];
        final others =
        allExampleTR.where((t) => t != exTr).toList()..shuffle();
        for (var i = 0; i < 3 && i < others.length; i++) {
          options.add(others[i]);
        }

        final unique = options.toSet().toList()..shuffle();
        final correctIndex = unique.indexOf(exTr);

        candidates.add(
          _ModuleExamQuestion.choice(
            type: _ExamQuestionType.translateMcq,
            prompt: exEn,
            subtitle: 'Bu cümlenin doğru Türkçe çevirisini seç:',
            options: unique,
            correctIndex: correctIndex,
            hintTR: null,
            explanationCorrect: 'Harika! ✅',
            explanationWrong: 'Doğru çeviri:\n$exTr',
          ),
        );
      }

      // 4) ✅ CÜMLE KUR (kelimeler karışık) — exampleEN + exampleTR gerekli
      for (final w in translatePool) {
        final exEn = w.exampleEN.trim();
        final exTr = w.exampleTR.trim();

        final tokens = _tokenizeWords(exEn);
        if (tokens.length < 4) continue; // çok kısa olmasın

        final shuffled = List<String>.from(tokens)..shuffle();

        candidates.add(
          _ModuleExamQuestion.build(
            type: _ExamQuestionType.sentenceBuild,
            prompt: 'Kelimeleri doğru sıraya koy:',
            subtitle: 'Cümle kur:',
            hintTR: exTr, // ✅ Türkçe ipucu göster
            buildPool: shuffled,
            targetSentence: exEn,
            explanationCorrect: 'Mükemmel! ✅',
            explanationWrong: 'Doğru cümle:\n$exEn',
          ),
        );
      }

      candidates.shuffle();
      final finalQuestions = candidates.take(_maxQuestionCount).toList();

      setState(() {
        _questions.addAll(finalQuestions);
        _isLoading = false;

        _hasAnsweredCurrent = false;
        _selectedOptionIndex = null;
        _buildSelected = [];

        _feedbackTitle = null;
        _feedbackDetail = null;
        _feedbackIsCorrect = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _questions.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modül sınavı yüklenirken hata oluştu: $e')),
      );
    }
  }

  void _answerChoice(int index) {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final current = _questions[_currentIndex];
    final isCorrect = index == current.correctIndex;

    setState(() {
      _hasAnsweredCurrent = true;
      _selectedOptionIndex = index;

      if (isCorrect) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Doğru! ✅';
        _feedbackDetail = current.explanationCorrect ?? 'Doğru!';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış cevap ❌';
        _feedbackDetail = current.explanationWrong ?? 'Yanlış.';
      }
    });
  }

  // ✅ Cümle kurma: kelime seç
  void _pickBuildWord(String w) {
    if (_hasAnsweredCurrent) return;
    setState(() {
      _buildSelected.add(w);
    });
  }

  void _removeLastBuildWord() {
    if (_hasAnsweredCurrent) return;
    if (_buildSelected.isEmpty) return;
    setState(() {
      _buildSelected.removeLast();
    });
  }

  void _clearBuild() {
    if (_hasAnsweredCurrent) return;
    setState(() {
      _buildSelected.clear();
    });
  }

  void _checkBuildAnswer() {
    if (_isFinished || _questions.isEmpty || _hasAnsweredCurrent) return;

    final current = _questions[_currentIndex];
    final target = current.targetSentence ?? '';
    final userSentence = _buildSelected.join(' ');

    final ok = _normalize(userSentence) == _normalize(target);

    setState(() {
      _hasAnsweredCurrent = true;

      if (ok) {
        _correctCount++;
        _feedbackIsCorrect = true;
        _feedbackTitle = 'Doğru! ✅';
        _feedbackDetail = current.explanationCorrect ?? 'Harika!';
      } else {
        _feedbackIsCorrect = false;
        _feedbackTitle = 'Yanlış ❌';
        _feedbackDetail = current.explanationWrong ?? 'Doğru cümle: $target';
      }
    });
  }

  Future<void> _onNextQuestion() async {
    if (_isFinished || _questions.isEmpty) return;

    if (_currentIndex == _questions.length - 1) {
      await _finishExam();
    } else {
      setState(() {
        _currentIndex++;
        _hasAnsweredCurrent = false;
        _selectedOptionIndex = null;
        _buildSelected = [];

        _feedbackTitle = null;
        _feedbackDetail = null;
        _feedbackIsCorrect = false;
      });
    }
  }

  Future<void> _finishExam() async {
    final total = _questions.length;
    final earned = _correctCount * _pointsPerCorrect;

    setState(() {
      _isFinished = true;
      _earned = earned;
      _feedbackTitle = null;
      _feedbackDetail = null;
      _feedbackIsCorrect = false;
    });

    if (earned > 0) {
      await _updateScores(earned);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$total sorudan $_correctCount doğru. '
              '${earned > 0 ? '$earned puan kazandın! 🎉' : 'Bu sınavdan puan kazanamadın.'}',
        ),
      ),
    );
  }

  Future<void> _updateScores(int earned) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final today = _todayKey();
    final now = DateTime.now();
    final todayStr = _todayStr(now);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        tx.set(userRef, {
          'totalScore': earned,
          'weeklyScore': earned,
          'currentStreak': 1,
          'longestStreak': 1,
          'lastActiveDate': todayStr,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final dailyRef = userRef.collection('dailyScores').doc(today);
        tx.set(dailyRef, {'score': earned, 'date': today},
            SetOptions(merge: true));
        return;
      }

      final data = userSnap.data() ?? {};

      final totalScore = (data['totalScore'] ?? 0) as int;
      final weeklyScore = (data['weeklyScore'] ?? 0) as int;
      int currentStreak = (data['currentStreak'] ?? 0) as int;
      int longestStreak = (data['longestStreak'] ?? 0) as int;
      final lastActiveStr = (data['lastActiveDate'] ?? '') as String;

      final todayDate = DateTime(now.year, now.month, now.day);

      if (lastActiveStr.isEmpty) {
        currentStreak = 1;
        if (longestStreak < 1) longestStreak = 1;
      } else {
        try {
          final parts = lastActiveStr.split('-');
          if (parts.length == 3) {
            final lastDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            final diff = todayDate.difference(lastDate).inDays;

            if (diff == 1) currentStreak++;
            if (diff > 1) currentStreak = 1;

            if (currentStreak > longestStreak) longestStreak = currentStreak;
          }
        } catch (_) {
          currentStreak = 1;
          if (currentStreak > longestStreak) longestStreak = currentStreak;
        }
      }

      tx.set(userRef, {
        'totalScore': totalScore + earned,
        'weeklyScore': weeklyScore + earned,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActiveDate': todayStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final dailyRef = userRef.collection('dailyScores').doc(today);
      final dailySnap = await tx.get(dailyRef);
      if (dailySnap.exists) {
        final oldScore = (dailySnap.data()?['score'] ?? 0) as int;
        tx.set(dailyRef, {'score': oldScore + earned}, SetOptions(merge: true));
      } else {
        tx.set(dailyRef, {'score': earned, 'date': today},
            SetOptions(merge: true));
      }
    });
  }

  void _retryExam() => _loadQuestions();

  Widget _typeChip(_ExamQuestionType t) {
    String text = 'ŞIKLI';
    IconData icon = Icons.checklist;

    if (t == _ExamQuestionType.fillBlank) {
      text = 'BOŞLUK';
      icon = Icons.edit;
    } else if (t == _ExamQuestionType.translateMcq) {
      text = 'ÇEVİRİ';
      icon = Icons.translate;
    } else if (t == _ExamQuestionType.sentenceBuild) {
      text = 'CÜMLE KUR';
      icon = Icons.view_list;
    }

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = '${widget.moduleTitle} – Modül Sınavı';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(titleText)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(titleText)),
        body: const Center(child: Text('Bu modül için sınav sorusu bulunamadı.')),
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
              Text('Modül sınavı tamamlandı!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('$total sorudan $_correctCount tanesini doğru bildin.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text('Toplam kazandığın puan: $_earned',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Modüle geri dön'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Ana sayfaya dön'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _retryExam,
                  child: const Text('Sınavı baştan çöz'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final current = _questions[_currentIndex];
    final totalQuestions = _questions.length;

    final isBuild = current.type == _ExamQuestionType.sentenceBuild;

    // build sorusunda kalan kelimeler
    final buildPool = current.buildPool ?? [];
    final remaining = buildPool.where((w) => !_buildSelected.contains(w)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(titleText)),
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
                _typeChip(current.type),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_currentIndex + 1) / totalQuestions),
            const SizedBox(height: 18),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.subtitle,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text(current.prompt,
                        style: Theme.of(context).textTheme.headlineSmall),

                    // ✅ Boşluk/cümle kur sorularında Türkçe ipucu göster
                    if ((current.type == _ExamQuestionType.fillBlank ||
                        current.type == _ExamQuestionType.sentenceBuild) &&
                        (current.hintTR ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'TR ipucu: ${current.hintTR}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ======= CÜMLE KUR UI =======
            if (isBuild) ...[
              Text(
                'Seçtiğin kelimeler:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
                  children: _buildSelected.isEmpty
                      ? [Text('Henüz kelime seçmedin.')]
                      : _buildSelected
                      .map((w) => Chip(label: Text(w)))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _hasAnsweredCurrent ? null : _removeLastBuildWord,
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
                    onPressed: (_hasAnsweredCurrent || _buildSelected.isEmpty)
                        ? null
                        : _checkBuildAnswer,
                    icon: const Icon(Icons.check),
                    label: const Text('Kontrol et'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Kalan kelimeler:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: remaining
                    .map(
                      (w) => ActionChip(
                    label: Text(w),
                    onPressed: () => _pickBuildWord(w),
                  ),
                )
                    .toList(),
              ),
            ] else ...[
              // ======= ŞIKLI UI (MCQ / FillBlank / Translate) =======
              ...List.generate(current.options.length, (i) {
                final option = current.options[i];

                Color? tileColor;
                IconData? leadingIcon;

                if (_hasAnsweredCurrent) {
                  if (i == current.correctIndex) {
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

            if (_feedbackTitle != null && _feedbackDetail != null) ...[
              Card(
                color: _feedbackIsCorrect
                    ? Colors.green.withAlpha((0.10 * 255).round())
                    : Colors.red.withAlpha((0.10 * 255).round()),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _feedbackIsCorrect ? Icons.check_circle : Icons.info,
                        color: _feedbackIsCorrect ? Colors.green : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_feedbackTitle!,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_feedbackDetail!),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasAnsweredCurrent ? _onNextQuestion : null,
                  child: Text(
                    _currentIndex == totalQuestions - 1 ? 'Sınavı bitir' : 'Sonraki soru',
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isBuild
                            ? 'Önce kelimelerle cümleyi kur ve kontrol et.'
                            : 'Önce bir cevap ver.'),
                      ),
                    );
                  },
                  child: Text(
                    _currentIndex == totalQuestions - 1 ? 'Sınavı bitir' : 'Sonraki soru',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleExamWord {
  final String id;
  final String english;
  final String turkish;
  final String exampleEN;
  final String exampleTR;

  _ModuleExamWord({
    required this.id,
    required this.english,
    required this.turkish,
    required this.exampleEN,
    required this.exampleTR,
  });

  factory _ModuleExamWord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final english = (data['word'] ??
        data['text'] ??
        data['english'] ??
        data['en'] ??
        '')
        .toString();

    final turkish = (data['meaningTR'] ??
        data['translation'] ??
        data['meaning'] ??
        data['turkish'] ??
        data['tr'] ??
        '')
        .toString();

    final exampleEN = (data['exampleEN'] ?? '').toString();
    final exampleTR = (data['exampleTR'] ?? '').toString();

    return _ModuleExamWord(
      id: doc.id,
      english: english,
      turkish: turkish,
      exampleEN: exampleEN,
      exampleTR: exampleTR,
    );
  }
}

class _ModuleExamQuestion {
  final _ExamQuestionType type;
  final String prompt;
  final String subtitle;

  final List<String> options;
  final int correctIndex;

  // ✅ ipucu (TR)
  final String? hintTR;

  // ✅ cümle kurma için
  final List<String>? buildPool;
  final String? targetSentence;

  final String? explanationCorrect;
  final String? explanationWrong;

  _ModuleExamQuestion._({
    required this.type,
    required this.prompt,
    required this.subtitle,
    required this.options,
    required this.correctIndex,
    required this.hintTR,
    required this.buildPool,
    required this.targetSentence,
    required this.explanationCorrect,
    required this.explanationWrong,
  });

  factory _ModuleExamQuestion.choice({
    required _ExamQuestionType type,
    required String prompt,
    required String subtitle,
    required List<String> options,
    required int correctIndex,
    required String? hintTR,
    String? explanationCorrect,
    String? explanationWrong,
  }) {
    return _ModuleExamQuestion._(
      type: type,
      prompt: prompt,
      subtitle: subtitle,
      options: options,
      correctIndex: correctIndex,
      hintTR: hintTR,
      buildPool: null,
      targetSentence: null,
      explanationCorrect: explanationCorrect,
      explanationWrong: explanationWrong,
    );
  }

  factory _ModuleExamQuestion.build({
    required _ExamQuestionType type,
    required String prompt,
    required String subtitle,
    required String? hintTR,
    required List<String> buildPool,
    required String targetSentence,
    String? explanationCorrect,
    String? explanationWrong,
  }) {
    return _ModuleExamQuestion._(
      type: type,
      prompt: prompt,
      subtitle: subtitle,
      options: const [],
      correctIndex: 0,
      hintTR: hintTR,
      buildPool: buildPool,
      targetSentence: targetSentence,
      explanationCorrect: explanationCorrect,
      explanationWrong: explanationWrong,
    );
  }
}