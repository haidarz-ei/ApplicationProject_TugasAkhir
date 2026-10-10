import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:app/services/sound_service.dart';

class WordCombineQuestion {
  final String imagePath;
  final List<String> correctWords;
  final List<String> scrambledWords;
  const WordCombineQuestion({required this.imagePath, required this.correctWords, required this.scrambledWords});
}

/// Halaman Builder Word Combine — Level 0–3
class BuilderWordCombinePage extends ConsumerStatefulWidget {
  final int level;
  const BuilderWordCombinePage({super.key, this.level = 0});

  @override
  ConsumerState<BuilderWordCombinePage> createState() => _BuilderWordCombinePageState();
}

class _BuilderWordCombinePageState extends ConsumerState<BuilderWordCombinePage> {
  late final List<WordCombineQuestion> _questions;

  static const _lv0 = [
    WordCombineQuestion(imagePath: 'assets/images/boy_drinking.png', correctWords: ['The', 'boy', 'drinks', 'water'], scrambledWords: ['water', 'boy', 'drinks', 'The']),
    WordCombineQuestion(imagePath: 'assets/images/cat.png', correctWords: ['The', 'cat', 'drinks', 'milk'], scrambledWords: ['milk', 'cat', 'drinks', 'The']),
    WordCombineQuestion(imagePath: 'assets/images/coffee.png', correctWords: ['A', 'hot', 'cup', 'of', 'coffee'], scrambledWords: ['coffee', 'cup', 'A', 'of', 'hot']),
    WordCombineQuestion(imagePath: 'assets/images/tea.png', correctWords: ['I', 'like', 'sweet', 'tea'], scrambledWords: ['tea', 'like', 'I', 'sweet']),
  ];
  static const _lv1 = [
    WordCombineQuestion(imagePath: 'assets/images/cat.png', correctWords: ['The', 'cat', 'is', 'cute'], scrambledWords: ['cute', 'cat', 'is', 'The']),
    WordCombineQuestion(imagePath: 'assets/images/coffee.png', correctWords: ['I', 'drink', 'black', 'coffee'], scrambledWords: ['black', 'I', 'coffee', 'drink']),
    WordCombineQuestion(imagePath: 'assets/images/tea.png', correctWords: ['She', 'likes', 'sweet', 'tea'], scrambledWords: ['tea', 'She', 'likes', 'sweet']),
    WordCombineQuestion(imagePath: 'assets/images/boy_drinking.png', correctWords: ['He', 'drinks', 'cold', 'water'], scrambledWords: ['cold', 'He', 'water', 'drinks']),
  ];
  static const _lv2 = [
    WordCombineQuestion(imagePath: 'assets/images/cat.png', correctWords: ['The', 'big', 'cat', 'drinks', 'warm', 'milk'], scrambledWords: ['drinks', 'cat', 'The', 'big', 'milk', 'warm']),
    WordCombineQuestion(imagePath: 'assets/images/coffee.png', correctWords: ['He', 'always', 'drinks', 'hot', 'coffee'], scrambledWords: ['hot', 'always', 'He', 'coffee', 'drinks']),
    WordCombineQuestion(imagePath: 'assets/images/tea.png', correctWords: ['My', 'mother', 'makes', 'sweet', 'green', 'tea'], scrambledWords: ['green', 'mother', 'My', 'sweet', 'makes', 'tea']),
    WordCombineQuestion(imagePath: 'assets/images/boy_drinking.png', correctWords: ['The', 'boy', 'drinks', 'a', 'glass', 'of', 'water'], scrambledWords: ['of', 'boy', 'The', 'a', 'water', 'glass', 'drinks']),
  ];
  static const _lv3 = [
    WordCombineQuestion(imagePath: 'assets/images/cat.png', correctWords: ['The', 'cat', 'is', 'sleeping', 'on', 'the', 'sofa'], scrambledWords: ['on', 'cat', 'is', 'The', 'sofa', 'sleeping', 'the']),
    WordCombineQuestion(imagePath: 'assets/images/coffee.png', correctWords: ['She', 'drinks', 'coffee', 'every', 'morning', 'at', 'work'], scrambledWords: ['morning', 'She', 'every', 'coffee', 'drinks', 'work', 'at']),
    WordCombineQuestion(imagePath: 'assets/images/tea.png', correctWords: ['I', 'prefer', 'to', 'drink', 'green', 'tea', 'daily'], scrambledWords: ['tea', 'prefer', 'I', 'to', 'green', 'daily', 'drink']),
    WordCombineQuestion(imagePath: 'assets/images/boy_drinking.png', correctWords: ['We', 'should', 'drink', 'eight', 'glasses', 'of', 'water'], scrambledWords: ['of', 'eight', 'should', 'We', 'water', 'glasses', 'drink']),
  ];

  int _currentIndex = 0;
  final List<String> _selectedWords = [];
  bool _isChecked = false;
  bool _isCorrect = false;

  WordCombineQuestion get _currentQ => _questions[_currentIndex];
  double get _progress => ((_isChecked && _isCorrect) ? _currentIndex + 1 : _currentIndex) / _questions.length;
  List<String> get _availableWords {
    final list = List<String>.from(_currentQ.scrambledWords);
    for (final w in _selectedWords) { list.remove(w); }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _questions = switch (widget.level) {
      1 => List.from(_lv1),
      2 => List.from(_lv2),
      3 => List.from(_lv3),
      _ => List.from(_lv0),
    };
  }

  void _checkAnswer() {
    if (_selectedWords.isEmpty) return;
    final correct = _selectedWords.join(' ').toLowerCase() == _currentQ.correctWords.join(' ').toLowerCase();
    setState(() { _isChecked = true; _isCorrect = correct; });
    if (correct) { SoundService.playCorrect(); } else { SoundService.playWrong(); }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() { _currentIndex++; _selectedWords.clear(); _isChecked = false; });
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      ProgressRepository().updateProgress(userId, 'builder', 'word_combine', widget.level + 1);
    }
    ref.read(sectionsProvider.notifier).updateSectionLevel(3, widget.level + 1);
    if (widget.level >= 3) ref.read(sectionsProvider.notifier).completeSection(3);
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 Awesome!', textAlign: TextAlign.center),
        content: const Text('All stages completed!', textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Center(child: Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        const Text('Make a sentence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        const Text('Arrange the words in the correct order', style: TextStyle(fontSize: 13, color: Color(0xFF868E96))),
                        const SizedBox(height: 10),
                        Flexible(
                          flex: 3,
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(_currentQ.imagePath, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSentenceSlots(),
                        const SizedBox(height: 10),
                        Flexible(flex: 2, child: Center(child: _buildWordPool())),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('Builder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                tween: Tween(begin: 0, end: _progress),
                builder: (context, val, child) => LinearProgressIndicator(
                  value: val, minHeight: 8,
                  backgroundColor: const Color(0xFFE9ECEF),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF58CC02)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Slot kata yang sudah dipilih + slot kosong sisa
  Widget _buildSentenceSlots() {
    final emptySlots = (_currentQ.correctWords.length - _selectedWords.length).clamp(0, 10);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          ..._selectedWords.asMap().entries.map((e) => GestureDetector(
            onTap: _isChecked ? null : () => setState(() => _selectedWords.removeAt(e.key)),
            child: _buildChip(e.value, selected: true),
          )),
          ...List.generate(emptySlots, (_) => Container(
            width: 48, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCED4DA)),
            ),
          )),
        ],
      ),
    );
  }

  /// Pool kata acak yang belum dipilih
  Widget _buildWordPool() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _availableWords.map((w) => GestureDetector(
        onTap: _isChecked ? null : () => setState(() => _selectedWords.add(w)),
        child: _buildChip(w, selected: false),
      )).toList(),
    );
  }

  /// Chip kata — biru jika sudah dipilih, putih jika di pool
  Widget _buildChip(String word, {required bool selected}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 16, vertical: selected ? 7 : 9),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE7F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(selected ? 10 : 12),
        border: Border.all(color: selected ? const Color(0xFF74C0FC) : const Color(0xFFDEE2E6)),
        boxShadow: selected ? null : const [BoxShadow(color: Color(0xFFE9ECEF), offset: Offset(0, 2))],
      ),
      child: Text(word, style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: selected ? const Color(0xFF1864AB) : Colors.black87,
      )),
    );
  }

  Widget _buildBottomAction() {
    if (_isChecked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          color: _isCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFE0),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: _isCorrect ? const Color(0xFF58CC02) : const Color(0xFFFF4B4B),
                ),
                const SizedBox(width: 8),
                Text(
                  _isCorrect ? 'Nicely done! 🎉' : 'Correct: ${_currentQ.correctWords.join(' ')}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isCorrect ? const Color(0xFF58CC02) : const Color(0xFFFF4B4B)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCorrect ? const Color(0xFF58CC02) : const Color(0xFFFF4B4B),
                  foregroundColor: Colors.white,
                ),
                child: Text(_currentIndex >= _questions.length - 1 ? 'FINISH' : 'CONTINUE',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SizedBox(
        width: double.infinity, height: 46,
        child: ElevatedButton(
          onPressed: _selectedWords.isNotEmpty ? _checkAnswer : null,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF58CC02), foregroundColor: Colors.white),
          child: const Text('CHECK', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

typedef BuilderTahap1Page = BuilderWordCombinePage;
