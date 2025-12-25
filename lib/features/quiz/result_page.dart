import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.correct,
    required this.total,
    required this.earned,
  });

  final int correct;
  final int total;
  final int earned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sonuç')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Doğru: $correct / $total',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Kazanılan Puan: $earned',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Ana Sayfaya Dön'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}