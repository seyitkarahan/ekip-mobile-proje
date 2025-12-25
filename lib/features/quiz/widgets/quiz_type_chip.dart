import 'package:flutter/material.dart';
import '../../../models/word_quiz_models.dart';

class QuizTypeChip extends StatelessWidget {
  final QuizQuestionType type;

  const QuizTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    String text = 'ŞIKLI';
    IconData icon = Icons.checklist;

    if (type == QuizQuestionType.fillBlank) {
      text = 'BOŞLUK';
      icon = Icons.edit;
    } else if (type == QuizQuestionType.translateMcq) {
      text = 'ÇEVİRİ';
      icon = Icons.translate;
    } else if (type == QuizQuestionType.sentenceBuild) {
      text = 'CÜMLE KUR';
      icon = Icons.view_list;
    }

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
    );
  }
}
