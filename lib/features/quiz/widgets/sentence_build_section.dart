import 'package:flutter/material.dart';
import '../../../models/word_quiz_models.dart';

class SentenceBuildSection extends StatelessWidget {
  final List<BuildToken> buildPool;
  final List<int> selectedTokenIds;
  final bool hasAnswered;

  final VoidCallback onRemoveLastToken;
  final VoidCallback onClearBuild;
  final VoidCallback onCheckAnswer;
  final void Function(BuildToken) onPickToken;

  const SentenceBuildSection({
    super.key,
    required this.buildPool,
    required this.selectedTokenIds,
    required this.hasAnswered,
    required this.onRemoveLastToken,
    required this.onClearBuild,
    required this.onCheckAnswer,
    required this.onPickToken,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTokens = selectedTokenIds
        .map((id) => buildPool.firstWhere((t) => t.id == id))
        .toList();

    final remainingTokens =
    buildPool.where((t) => !selectedTokenIds.contains(t.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seçtiğin kelimeler:',
            style: Theme.of(context).textTheme.titleSmall),
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
            children: selectedTokens.isEmpty
                ? [const Text('Henüz kelime seçmedin.')]
                : selectedTokens.map((t) => Chip(label: Text(t.text))).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: hasAnswered ? null : onRemoveLastToken,
              icon: const Icon(Icons.backspace_outlined),
              label: const Text('Sil'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: hasAnswered ? null : onClearBuild,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Temizle'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: (hasAnswered || selectedTokenIds.isEmpty)
                  ? null
                  : onCheckAnswer,
              icon: const Icon(Icons.check),
              label: const Text('Kontrol et'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Kalan kelimeler:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: remainingTokens
              .map(
                (t) => ActionChip(
              label: Text(t.text),
              onPressed: hasAnswered ? null : () => onPickToken(t),
            ),
          )
              .toList(),
        ),
      ],
    );
  }
}
