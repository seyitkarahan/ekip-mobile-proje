class QuestionModel {
  final String id;
  final String questionText;
  final List<String> choices;
  final int correctIndex;
  final String level;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.choices,
    required this.correctIndex,
    required this.level,
  });

  factory QuestionModel.fromMap(String id, Map<String, dynamic> data) {
    final rawChoices = (data['choices'] as List?) ?? [];
    return QuestionModel(
      id: id,
      questionText: (data['questionText'] ?? '') as String,
      choices: rawChoices.map((e) => e.toString()).toList(),
      correctIndex: (data['correctIndex'] ?? 0) as int,
      level: (data['level'] ?? 'A1') as String,
    );
  }
}