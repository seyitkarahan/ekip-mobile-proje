import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LessonLearnPage extends StatefulWidget {
  final String moduleId;
  final String lessonId;
  final String title;

  const LessonLearnPage({
    super.key,
    required this.moduleId,
    required this.lessonId,
    required this.title,
  });

  @override
  State<LessonLearnPage> createState() => _LessonLearnPageState();
}

class _LessonLearnPageState extends State<LessonLearnPage> {
  bool _isLoading = true;
  List<_LessonItem> _items = [];
  int _currentIndex = 0;
  bool _showTranslation = false;

  @override
  void initState() {
    super.initState();
    _loadLessonContent();
  }

  Future<void> _loadLessonContent() async {
    setState(() {
      _isLoading = true;
      _items = [];
      _currentIndex = 0;
      _showTranslation = false;
    });

    final snap = await FirebaseFirestore.instance
        .collection('words')
        .where('moduleId', isEqualTo: widget.moduleId)
        .where('lessonId', isEqualTo: widget.lessonId)
        .get();

    final items = snap.docs.map((d) => _LessonItem.fromDoc(d)).toList()
      ..removeWhere((e) => e.word.isEmpty);

    // Kelimeleri karışık değil, olduğu gibi de bırakabilirsin
    items.sort((a, b) => a.word.compareTo(b.word));

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _nextItem() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _showTranslation = false;
      });
    }
  }

  void _prevItem() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showTranslation = false;
      });
    }
  }

  bool get _isLastItem => _currentIndex == _items.length - 1;

  void _goToQuiz() {
    // Kullanıcı tüm kelimeleri gezmiş durumda -> Quiz'e gönder
    final title = Uri.encodeComponent(widget.title);
    context.push(
      '/lesson-quiz/${widget.moduleId}/${widget.lessonId}?title=$title',
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.title.isEmpty ? 'Ders' : widget.title;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
        ),
        body: const Center(
          child: Text('Bu ders için içerik bulunamadı.'),
        ),
      );
    }

    final current = _items[_currentIndex];
    final total = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İlerleme barı
            Text(
              'Kart ${_currentIndex + 1} / $total',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / total,
            ),
            const SizedBox(height: 24),

            // Ana kart
            Expanded(
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          current.word,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Anlamını görmek için karta dokun',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTranslation = !_showTranslation;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _showTranslation
                                  ? Colors.blue.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                if (_showTranslation) ...[
                                  Text(
                                    current.meaningTR,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  if (current.exampleEN.isNotEmpty)
                                    Text(
                                      current.exampleEN,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  if (current.exampleTR.isNotEmpty)
                                    Text(
                                      '\n${current.exampleTR}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey[700]),
                                      textAlign: TextAlign.center,
                                    ),
                                ] else ...[
                                  const Icon(Icons.visibility, size: 32),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Türkçe anlam & örnek cümleyi görmek için dokun',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Navigasyon butonları
            Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _prevItem,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Geri'),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                if (!_isLastItem)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextItem,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Sonraki'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _goToQuiz,
                      icon: const Icon(Icons.quiz),
                      label: const Text('Dersi bitir ve Quiz’e başla'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------- MODEL -----------------

class _LessonItem {
  final String id;
  final String word;
  final String meaningTR;
  final String exampleEN;
  final String exampleTR;

  _LessonItem({
    required this.id,
    required this.word,
    required this.meaningTR,
    required this.exampleEN,
    required this.exampleTR,
  });

  factory _LessonItem.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    final word = (data['word'] ??
        data['text'] ??
        data['english'] ??
        data['en'] ??
        '')
        .toString();

    final meaningTR =
    (data['meaningTR'] ?? data['turkish'] ?? data['tr'] ?? '').toString();

    final exampleEN =
    (data['exampleEN'] ?? data['example'] ?? '').toString();

    final exampleTR =
    (data['exampleTR'] ?? data['example_tr'] ?? '').toString();

    return _LessonItem(
      id: doc.id,
      word: word,
      meaningTR: meaningTR,
      exampleEN: exampleEN,
      exampleTR: exampleTR,
    );
  }
}