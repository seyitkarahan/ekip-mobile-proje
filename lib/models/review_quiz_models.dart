import 'package:cloud_firestore/cloud_firestore.dart';

class Mistake {
  final String id;
  final String wordId;
  final String english;
  final String turkish;

  Mistake({
    required this.id,
    required this.wordId,
    required this.english,
    required this.turkish,
  });

  factory Mistake.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Mistake(
      id: doc.id,
      wordId: (data['wordId'] ?? '').toString(),
      english: (data['english'] ?? '').toString(),
      turkish: (data['turkish'] ?? '').toString(),
    );
  }
}