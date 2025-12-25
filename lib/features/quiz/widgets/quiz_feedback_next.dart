import 'package:flutter/material.dart';

class QuizFeedbackNext extends StatelessWidget {
  final String? feedbackTitle;
  final String? feedbackDetail;
  final bool feedbackIsCorrect;

  final bool hasAnswered;
  final bool isLast;

  final VoidCallback onNext;

  final String needAnswerMessage;
  final String nextText;
  final String finishText;

  const QuizFeedbackNext({
    super.key,
    required this.feedbackTitle,
    required this.feedbackDetail,
    required this.feedbackIsCorrect,
    required this.hasAnswered,
    required this.isLast,
    required this.onNext,
    required this.needAnswerMessage,
    this.nextText = 'Sonraki soru',
    this.finishText = 'Bitir',
  });

  @override
  Widget build(BuildContext context) {
    final hasFeedback = feedbackTitle != null && feedbackDetail != null;

    if (hasFeedback) {
      return Column(
        children: [
          Card(
            color: feedbackIsCorrect
                ? Colors.green.withAlpha((0.10 * 255).round())
                : Colors.red.withAlpha((0.10 * 255).round()),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    feedbackIsCorrect ? Icons.check_circle : Icons.info,
                    color: feedbackIsCorrect ? Colors.green : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedbackTitle!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(feedbackDetail!),
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
              onPressed: hasAnswered ? onNext : null,
              child: Text(isLast ? finishText : nextText),
            ),
          ),
        ],
      );
    }

    // feedback yoksa: kullanıcıyı uyar
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(needAnswerMessage)),
          );
        },
        child: Text(isLast ? finishText : nextText),
      ),
    );
  }
}
