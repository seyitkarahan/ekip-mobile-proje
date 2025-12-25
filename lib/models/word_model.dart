class WordModel {
  final String id;
  final String word;
  final String meaningTR;
  final String exampleEN;

  // ✅ Yeni: örnek cümlenin Türkçe karşılığı (çeviri egzersizi için)
  final String exampleTR;

  WordModel({
    required this.id,
    required this.word,
    required this.meaningTR,
    required this.exampleEN,
    required this.exampleTR,
  });

  factory WordModel.fromMap(String id, Map<String, dynamic> map) {
    return WordModel(
      id: id,
      word: (map['word'] ?? '').toString(),
      meaningTR: (map['meaningTR'] ?? '').toString(),
      exampleEN: (map['exampleEN'] ?? '').toString(),
      exampleTR: (map['exampleTR'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'meaningTR': meaningTR,
      'exampleEN': exampleEN,
      'exampleTR': exampleTR,
    };
  }
}