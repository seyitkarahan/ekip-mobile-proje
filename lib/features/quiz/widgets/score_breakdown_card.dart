import 'package:flutter/material.dart';

class ScoreBreakdownCard extends StatelessWidget {
  final int basePoints;
  final int comboPoints;
  final int bonusPoints;
  final int totalPoints;

  final String title;

  const ScoreBreakdownCard({
    super.key,
    required this.basePoints,
    required this.comboPoints,
    required this.bonusPoints,
    required this.totalPoints,
    this.title = 'Puan Detayı',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _row('Base', basePoints),
            _row('Combo', comboPoints),
            _row('Bonus', bonusPoints),
            const Divider(),
            _row('Toplam', totalPoints, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value, {bool isBold = false}) {
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
