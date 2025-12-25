import 'dart:math';

import '../../../models/word_quiz_models.dart';
import 'quiz_utils.dart';

class QuizEngine {
  static List<QuizQuestion> buildQuiz({
    required List<QuizWord> focusWords,
    required List<QuizWord> globalWords,
    required int maxQuestionCount,
    required bool trackMistakesForSentenceQuestions,
  }) {
    if (focusWords.isEmpty) return [];

    final rnd = Random();

    final safeGlobal = globalWords.isNotEmpty ? globalWords : focusWords;

    final allTurkish = {
      ...focusWords.map((w) => w.turkish).where((x) => x.trim().isNotEmpty),
      ...safeGlobal.map((w) => w.turkish).where((x) => x.trim().isNotEmpty),
    }.toList();

    final allEnglish = {
      ...focusWords.map((w) => w.english).where((x) => x.trim().isNotEmpty),
      ...safeGlobal.map((w) => w.english).where((x) => x.trim().isNotEmpty),
    }.toList();

    final sentencePool = focusWords
        .where((w) => w.exampleEN.trim().isNotEmpty && w.exampleTR.trim().isNotEmpty)
        .toList();

    final allExampleTR = {
      ...sentencePool.map((w) => w.exampleTR.trim()).where((x) => x.isNotEmpty),
      ...safeGlobal.map((w) => w.exampleTR.trim()).where((x) => x.isNotEmpty),
    }.toList();

    final List<QuizQuestion> candidates = [];

    // 1) MCQ (EN -> TR)
    for (final w in focusWords) {
      final opts = _buildOptions(
        correct: w.turkish,
        pool: allTurkish,
        targetSize: 4,
        rnd: rnd,
      );
      final correctIndex = opts.indexOf(w.turkish);
      if (correctIndex < 0) continue;

      candidates.add(
        QuizQuestion.choice(
          type: QuizQuestionType.mcq,
          prompt: w.english,
          subtitle: 'Doğru Türkçe anlamı seç:',
          options: opts,
          correctIndex: correctIndex,
          hintTR: null,
          wordId: w.id,
          wordEN: w.english,
          wordTR: w.turkish,
          explanationCorrect: '"${w.english}" kelimesinin anlamı: ${w.turkish}',
          explanationWrong: 'Doğru cevap: ${w.turkish}\nKelime: ${w.english}',
        ),
      );
    }

    // 2) FillBlank (exampleEN) + TR ipucu
    for (final w in focusWords) {
      final ex = w.exampleEN.trim();
      if (ex.isEmpty) continue;

      final containsWord =
      RegExp(RegExp.escape(w.english), caseSensitive: false).hasMatch(ex);
      if (!containsWord) continue;

      final blanked = blankOutFirstOccurrence(sentence: ex, wordOrPhrase: w.english);

      final opts = _buildOptions(
        correct: w.english,
        pool: allEnglish,
        targetSize: 4,
        rnd: rnd,
      );
      final correctIndex = opts.indexOf(w.english);
      if (correctIndex < 0) continue;

      final hintTR = w.exampleTR.trim().isNotEmpty
          ? w.exampleTR.trim()
          : 'Kelimenin anlamı: ${w.turkish}';

      candidates.add(
        QuizQuestion.choice(
          type: QuizQuestionType.fillBlank,
          prompt: blanked,
          subtitle: 'Boşluğa hangi kelime gelmeli?',
          options: opts,
          correctIndex: correctIndex,
          hintTR: hintTR,
          wordId: w.id,
          wordEN: w.english,
          wordTR: w.turkish,
          explanationCorrect: 'Doğru! Kelime: ${w.english}',
          explanationWrong: 'Doğru kelime: ${w.english}',
        ),
      );
    }

    // 3) Translate MCQ (exampleEN -> exampleTR)
    for (final w in sentencePool) {
      final exEn = w.exampleEN.trim();
      final exTr = w.exampleTR.trim();
      if (exEn.isEmpty || exTr.isEmpty) continue;

      final opts = _buildOptions(
        correct: exTr,
        pool: allExampleTR,
        targetSize: 4,
        rnd: rnd,
      );
      final correctIndex = opts.indexOf(exTr);
      if (correctIndex < 0) continue;

      candidates.add(
        QuizQuestion.choice(
          type: QuizQuestionType.translateMcq,
          prompt: exEn,
          subtitle: 'Bu cümlenin doğru Türkçe çevirisini seç:',
          options: opts,
          correctIndex: correctIndex,
          hintTR: null,
          wordId: trackMistakesForSentenceQuestions ? w.id : null,
          wordEN: trackMistakesForSentenceQuestions ? w.english : null,
          wordTR: trackMistakesForSentenceQuestions ? w.turkish : null,
          explanationCorrect: 'Harika! ✅',
          explanationWrong: 'Doğru çeviri:\n$exTr',
        ),
      );
    }

    // 4) Sentence Build
    for (final w in sentencePool) {
      final exEn = w.exampleEN.trim();
      final exTr = w.exampleTR.trim();
      if (exEn.isEmpty || exTr.isEmpty) continue;

      final tokens = tokenizeWords(exEn);
      if (tokens.length < 4) continue;

      final pool = <BuildToken>[
        for (var i = 0; i < tokens.length; i++) BuildToken(id: i, text: tokens[i]),
      ]..shuffle(rnd);

      candidates.add(
        QuizQuestion.build(
          type: QuizQuestionType.sentenceBuild,
          subtitle: 'Cümle kur:',
          prompt: 'Kelimeleri doğru sıraya koy:',
          hintTR: exTr,
          buildPool: pool,
          targetSentence: exEn,
          wordId: trackMistakesForSentenceQuestions ? w.id : null,
          wordEN: trackMistakesForSentenceQuestions ? w.english : null,
          wordTR: trackMistakesForSentenceQuestions ? w.turkish : null,
          explanationCorrect: 'Mükemmel! ✅',
          explanationWrong: 'Doğru cümle:\n$exEn',
        ),
      );
    }

    candidates.shuffle(rnd);
    return candidates.take(maxQuestionCount).toList();
  }

  static List<String> _buildOptions({
    required String correct,
    required List<String> pool,
    required int targetSize,
    required Random rnd,
  }) {
    final filtered = pool.where((x) => x.trim().isNotEmpty && x != correct).toList()
      ..shuffle(rnd);

    final opts = <String>[correct];
    for (final x in filtered) {
      if (opts.length >= targetSize) break;
      opts.add(x);
    }

    final unique = opts.toSet().toList()..shuffle(rnd);
    return unique;
  }
}