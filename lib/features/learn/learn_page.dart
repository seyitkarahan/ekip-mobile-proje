import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/word_model.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  int _index = 0;
  bool _showMeaning = false;

  Future<List<WordModel>> _fetchWords() async {
    final snap = await FirebaseFirestore.instance
        .collection('words')
        .limit(50)
        .get();

    final list = snap.docs
        .map((d) => WordModel.fromMap(d.id, d.data()))
        .toList();

    list.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: FutureBuilder<List<WordModel>>(
        future: _fetchWords(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Hata: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final words = snap.data!;
          if (words.isEmpty) return const Center(child: Text('Henüz kelime yok.'));

          if (_index >= words.length) _index = words.length - 1;
          final current = words[_index];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('${_index + 1} / ${words.length}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showMeaning = !_showMeaning),
                    child: Card(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(current.word,
                                  style: Theme.of(context).textTheme.headlineMedium),
                              const SizedBox(height: 12),
                              Text(
                                _showMeaning
                                    ? current.meaningTR
                                    : 'Anlamı görmek için dokun',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(current.exampleEN,
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index == 0
                            ? null
                            : () => setState(() {
                          _index--;
                          _showMeaning = false;
                        }),
                        child: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _index == words.length - 1
                            ? null
                            : () => setState(() {
                          _index++;
                          _showMeaning = false;
                        }),
                        child: const Text('İleri'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}