import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SentenceTranslatePage extends StatefulWidget {
  const SentenceTranslatePage({
    super.key,
    required this.moduleId,
    required this.lessonId,
    required this.title,
  });

  final String moduleId;
  final String lessonId;
  final String title;

  @override
  State<SentenceTranslatePage> createState() => _SentenceTranslatePageState();
}

class _SentenceTranslatePageState extends State<SentenceTranslatePage> {
  bool _loading = true;

  // each item: {word, meaningTR, exampleEN, exampleTR}
  final List<Map<String, dynamic>> _items = [];

  int _index = 0;
  int _correct = 0;
  int _earned = 0;

  List<String> _bank = [];
  final List<String> _selected = [];

  String? _feedback; // "Doğru ✅" / "Yanlış ❌"

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _items.clear();
      _index = 0;
      _correct = 0;
      _earned = 0;
      _bank = [];
      _selected.clear();
      _feedback = null;
    });

    final snap = await FirebaseFirestore.instance
        .collection('words')
        .where('moduleId', isEqualTo: widget.moduleId)
        .where('lessonId', isEqualTo: widget.lessonId)
        .limit(50)
        .get();

    final list = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final data = d.data();
      final word = (data['word'] ?? '').toString().trim();
      final meaningTR = (data['meaningTR'] ?? '').toString().trim();
      final exampleEN = (data['exampleEN'] ?? '').toString().trim();
      final exampleTR = (data['exampleTR'] ?? '').toString().trim();

      // Çeviri egzersizi için exampleTR şart
      if (word.isNotEmpty &&
          meaningTR.isNotEmpty &&
          exampleEN.isNotEmpty &&
          exampleTR.isNotEmpty) {
        list.add({
          'word': word,
          'meaningTR': meaningTR,
          'exampleEN': exampleEN,
          'exampleTR': exampleTR,
        });
      }
    }

    list.shuffle(Random());

    setState(() {
      _items.addAll(list);
      _loading = false;
    });

    if (_items.isNotEmpty) {
      _prepareBank();
    }
  }

  void _prepareBank() {
    _selected.clear();
    _feedback = null;

    final targetTR = _items[_index]['exampleTR'] as String;
    final tokens = _tokenizeTr(targetTR);
    final shuffled = tokens.toList()..shuffle(Random());

    setState(() {
      _bank = shuffled;
    });
  }

  List<String> _tokenizeTr(String s) {
    // Basit tokenize: kelimeleri ve noktalama işaretlerini ayır
    final spaced = s
        .replaceAll(RegExp(r'([.,!?;:])'), r' $1 ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return spaced.isEmpty ? [] : spaced.split(' ');
  }

  String _joinTokens(List<String> tokens) {
    // Noktalama öncesi boşluğu düzelt
    final raw = tokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return raw
        .replaceAll(' .', '.')
        .replaceAll(' ,', ',')
        .replaceAll(' !', '!')
        .replaceAll(' ?', '?')
        .replaceAll(' ;', ';')
        .replaceAll(' :', ':')
        .trim();
  }

  String _normalize(String s) {
    // Karşılaştırma: fazla boşlukları temizle
    return s
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  void _pickFromBank(String token) {
    setState(() {
      _bank.remove(token);
      _selected.add(token);
      _feedback = null;
    });
  }

  void _removeSelected(String token) {
    setState(() {
      _selected.remove(token);
      _bank.add(token);
      _feedback = null;
    });
  }

  void _clearSelected() {
    setState(() {
      _bank.addAll(_selected);
      _selected.clear();
      _bank.shuffle(Random());
      _feedback = null;
    });
  }

  Future<void> _check() async {
    final expected = _items[_index]['exampleTR'] as String;
    final userSentence = _joinTokens(_selected);

    final ok = _normalize(userSentence) == _normalize(expected);

    setState(() {
      _feedback = ok ? 'Doğru ✅' : 'Yanlış ❌';
    });

    if (ok) {
      _correct++;
      _earned += 10;
      await Future.delayed(const Duration(milliseconds: 450));
      _next();
    }
  }

  void _next() {
    if (_index >= _items.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _prepareBank();
  }

  Future<void> _finish() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'totalScore': FieldValue.increment(_earned),
      'weeklyScore': FieldValue.increment(_earned),
    });

    if (!mounted) return;
    context.go('/result?correct=$_correct&total=${_items.length}&earned=$_earned');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} • Çeviri'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Bu ders için çeviri egzersizi bulunamadı.\n'
                'words dokümanlarına exampleTR eklemelisin.',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final item = _items[_index];
    final word = item['word'] as String;
    final meaningTR = item['meaningTR'] as String;
    final exampleEN = item['exampleEN'] as String;
    final expectedTR = item['exampleTR'] as String;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_index / ${_items.length - 1}  •  Doğru: $_correct  •  Puan: $_earned',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kelime', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('$word — $meaningTR',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text('Cümleyi Türkçeye çevir:',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(exampleEN,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'İpucu: Çeviri bu (şimdilik gizli): ${expectedTR.isEmpty ? "-" : "•••"}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text('Cümlen:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected.isEmpty
                ? [Chip(label: Text('Kelimelere tıkla ve cümleyi kur'))]
                : _selected
                .map(
                  (t) => InputChip(
                label: Text(t),
                onPressed: () => _removeSelected(t),
              ),
            )
                .toList(),
          ),

          const SizedBox(height: 12),

          Text('Kelimeler:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bank
                .map(
                  (t) => ActionChip(
                label: Text(t),
                onPressed: () => _pickFromBank(t),
              ),
            )
                .toList(),
          ),

          const SizedBox(height: 10),

          if (_feedback != null)
            Text(
              _feedback!,
              style: Theme.of(context).textTheme.titleLarge,
            ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _selected.isEmpty ? null : _clearSelected,
                  child: const Text('Temizle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selected.isEmpty ? null : _check,
                  child: const Text('Kontrol Et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}