import 'package:flutter/material.dart';

class QuizFeedbackCard extends StatelessWidget {
  final String title;
  final String detail;
  final bool isCorrect;

  const QuizFeedbackCard({
    super.key,
    required this.title,
    required this.detail,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isCorrect
          ? Colors.green.withAlpha((0.10 * 255).round())
          : Colors.red.withAlpha((0.10 * 255).round()),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.info,
              color: isCorrect ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
