import 'package:cloud_firestore/cloud_firestore.dart';

enum QuizQuestionType { mcq, fillBlank, translateMcq, sentenceBuild }

class QuizWord {
  final String id;
  final String english;
  final String turkish;
  final String exampleEN;
  final String exampleTR;

  QuizWord({
    required this.id,
    required this.english,
    required this.turkish,
    required this.exampleEN,
    required this.exampleTR,
  });

  factory QuizWord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final english = (data['word'] ??
        data['text'] ??
        data['english'] ??
        data['en'] ??
        '')
        .toString()
        .trim();

    final turkish = (data['meaningTR'] ??
        data['translation'] ??
        data['meaning'] ??
        data['turkish'] ??
        data['tr'] ??
        '')
        .toString()
        .trim();

    final exampleEN = (data['exampleEN'] ?? '').toString().trim();
    final exampleTR = (data['exampleTR'] ?? '').toString().trim();

    return QuizWord(
      id: doc.id,
      english: english,
      turkish: turkish,
      exampleEN: exampleEN,
      exampleTR: exampleTR,
    );
  }
}

class BuildToken {
  final int id;
  final String text;

  BuildToken({required this.id, required this.text});
}

class QuizQuestion {
  final QuizQuestionType type;
  final String prompt;
  final String subtitle;

  final List<String> options;
  final int correctIndex;

  final String? hintTR;

  final String? wordId;
  final String? wordEN;
  final String? wordTR;

  final List<BuildToken>? buildPool;
  final String? targetSentence;

  final String? explanationCorrect;
  final String? explanationWrong;

  QuizQuestion._({
    required this.type,
    required this.prompt,
    required this.subtitle,
    required List<String> options,
    required this.correctIndex,
    required this.hintTR,
    required this.wordId,
    required this.wordEN,
    required this.wordTR,
    required this.buildPool,
    required this.targetSentence,
    required this.explanationCorrect,
    required this.explanationWrong,
  }) : options = List.unmodifiable(options);

  factory QuizQuestion.choice({
    required QuizQuestionType type,
    required String prompt,
    required String subtitle,
    required List<String> options,
    required int correctIndex,
    required String? hintTR,
    required String? wordId,
    required String? wordEN,
    required String? wordTR,
    String? explanationCorrect,
    String? explanationWrong,
  }) {
    return QuizQuestion._(
      type: type,
      prompt: prompt,
      subtitle: subtitle,
      options: options,
      correctIndex: correctIndex,
      hintTR: hintTR,
      wordId: wordId,
      wordEN: wordEN,
      wordTR: wordTR,
      buildPool: null,
      targetSentence: null,
      explanationCorrect: explanationCorrect,
      explanationWrong: explanationWrong,
    );
  }

  factory QuizQuestion.build({
    required QuizQuestionType type,
    required String prompt,
    required String subtitle,
    required String? hintTR,
    required List<BuildToken> buildPool,
    required String targetSentence,
    String? wordId,
    String? wordEN,
    String? wordTR,
    String? explanationCorrect,
    String? explanationWrong,
  }) {
    return QuizQuestion._(
      type: type,
      prompt: prompt,
      subtitle: subtitle,
      options: const [],
      correctIndex: 0,
      hintTR: hintTR,
      wordId: wordId,
      wordEN: wordEN,
      wordTR: wordTR,
      buildPool: buildPool,
      targetSentence: targetSentence,
      explanationCorrect: explanationCorrect,
      explanationWrong: explanationWrong,
    );
  }
}