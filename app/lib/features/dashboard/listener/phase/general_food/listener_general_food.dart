import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:app/services/sound_service.dart';
import 'package:app/features/dashboard/phase_coming_soon_page.dart';

/// Model untuk soal listener tahap 1
class ListenerQuestion1 {
  final String englishWord;
  final String correctAnswer;
  final List<ListenerOption1> options;

  const ListenerQuestion1({
    required this.englishWord,
    required this.correctAnswer,
    required this.options,
  });
}

class ListenerOption1 {
  final String id;
  final String label;

  const ListenerOption1({required this.id, required this.label});
}

/// Halaman Listener General Food — Level 0–3
class ListenerGeneralFoodPage extends ConsumerStatefulWidget {
  final int level;
  const ListenerGeneralFoodPage({super.key, this.level = 0});

  @override
  ConsumerState<ListenerGeneralFoodPage> createState() => _ListenerGeneralFoodPageState();
}

class _ListenerGeneralFoodPageState extends ConsumerState<ListenerGeneralFoodPage> {
  late final List<ListenerQuestion1> _questions;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  int _currentIndex = 0;
  String? _selectedId;
  bool _isChecked = false;
  bool _isCorrect = false;
  int _score = 0;

  static const _lv0 = [
    ListenerQuestion1(englishWord: 'sugar', correctAnswer: 'sugar', options: [
      ListenerOption1(id: 'tea', label: 'tea'), ListenerOption1(id: 'coffee', label: 'coffee'),
      ListenerOption1(id: 'sugar', label: 'sugar'), ListenerOption1(id: 'milk', label: 'milk'),
    ]),
    ListenerQuestion1(englishWord: 'tea', correctAnswer: 'tea', options: [
      ListenerOption1(id: 'tea', label: 'tea'), ListenerOption1(id: 'coffee', label: 'coffee'),
      ListenerOption1(id: 'sugar', label: 'sugar'), ListenerOption1(id: 'milk', label: 'milk'),
    ]),
    ListenerQuestion1(englishWord: 'coffee', correctAnswer: 'coffee', options: [
      ListenerOption1(id: 'milk', label: 'milk'), ListenerOption1(id: 'coffee', label: 'coffee'),
      ListenerOption1(id: 'tea', label: 'tea'), ListenerOption1(id: 'sugar', label: 'sugar'),
    ]),
    ListenerQuestion1(englishWord: 'milk', correctAnswer: 'milk', options: [
      ListenerOption1(id: 'sugar', label: 'sugar'), ListenerOption1(id: 'tea', label: 'tea'),
      ListenerOption1(id: 'coffee', label: 'coffee'), ListenerOption1(id: 'milk', label: 'milk'),
    ]),
  ];

  static const _lv1 = [
    ListenerQuestion1(englishWord: 'apple', correctAnswer: 'apple', options: [
      ListenerOption1(id: 'apple', label: 'apple'), ListenerOption1(id: 'banana', label: 'banana'),
      ListenerOption1(id: 'orange', label: 'orange'), ListenerOption1(id: 'grape', label: 'grape'),
    ]),
    ListenerQuestion1(englishWord: 'banana', correctAnswer: 'banana', options: [
      ListenerOption1(id: 'mango', label: 'mango'), ListenerOption1(id: 'banana', label: 'banana'),
      ListenerOption1(id: 'apple', label: 'apple'), ListenerOption1(id: 'grape', label: 'grape'),
    ]),
    ListenerQuestion1(englishWord: 'bread', correctAnswer: 'bread', options: [
      ListenerOption1(id: 'rice', label: 'rice'), ListenerOption1(id: 'bread', label: 'bread'),
      ListenerOption1(id: 'pasta', label: 'pasta'), ListenerOption1(id: 'noodle', label: 'noodle'),
    ]),
    ListenerQuestion1(englishWord: 'rice', correctAnswer: 'rice', options: [
      ListenerOption1(id: 'bread', label: 'bread'), ListenerOption1(id: 'pasta', label: 'pasta'),
      ListenerOption1(id: 'rice', label: 'rice'), ListenerOption1(id: 'noodle', label: 'noodle'),
    ]),
  ];

  static const _lv2 = <ListenerQuestion1>[];
  static const _lv3 = <ListenerQuestion1>[];

  @override
  void initState() {
    super.initState();
    _questions = switch (widget.level) {
      1 => List.from(_lv1),
      2 => List.from(_lv2),
      3 => List.from(_lv3),
      _ => List.from(_lv0),
    };
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(_currentQuestion.englishWord);
  }

  ListenerQuestion1 get _currentQuestion => _questions[_currentIndex];
  double get _progress => (_isChecked && _isCorrect) ? (_currentIndex + 1) / _questions.length : _currentIndex / _questions.length;

  void _onSelect(String id) {
    if (_isChecked) return;
    setState(() => _selectedId = id);
  }

  void _checkAnswer() {
    if (_selectedId == null) return;
    final selected = _currentQuestion.options.firstWhere((o) => o.id == _selectedId);
    setState(() {
      _isChecked = true;
      _isCorrect = selected.label == _currentQuestion.correctAnswer;
      if (_isCorrect) _score++;
    });
    if (_isCorrect) {
      SoundService.playCorrect();
    } else {
      SoundService.playWrong();
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedId = null;
        _isChecked = false;
        _isCorrect = false;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      ProgressRepository().updateProgress(userId, 'listener', 'general_food', widget.level + 1);
    }
    ref.read(sectionsProvider.notifier).updateSectionLevel(1, widget.level + 1);
    if (widget.level >= 3) {
      ref.read(sectionsProvider.notifier).completeSection(1);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Complete!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_score / ${_questions.length}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF58CC02))),
            const SizedBox(height: 8),
            const Text('You have completed Stage 1!', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58CC02),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level >= 2) {
      return PhaseComingSoonPage(
        title: 'Listener Phases',
        topicTitle: 'General Food',
        level: widget.level,
        sectionColor: const Color(0xFF58CC02),
        sectionIcon: Icons.headphones_rounded,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                        const SizedBox(height: 8),
                        const Text(
                          'Listen and Choose the correct image',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF3C3C3C), letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _speak,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _isSpeaking ? 54 : 48,
                            height: _isSpeaking ? 54 : 48,
                            decoration: BoxDecoration(
                              color: _isSpeaking ? const Color(0xFF0099D6) : const Color(0xFF1CB0F6),
                              shape: BoxShape.circle,
                              boxShadow: _isSpeaking
                                  ? [BoxShadow(color: const Color(0xFF1CB0F6).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                                  : [],
                            ),
                            child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const spacing = 12.0;
                              final cardWidth = (constraints.maxWidth - spacing) / 2;
                              final cardHeight = (constraints.maxHeight - spacing) / 2;
                              final ratio = (cardWidth > 0 && cardHeight > 0) ? (cardWidth / cardHeight) : 1.0;

                              return GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
                                childAspectRatio: ratio,
                                physics: const NeverScrollableScrollPhysics(),
                                children: _currentQuestion.options.map(_buildCard).toList(),
                              );
                            },
                          ),
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFFAFAFAF), size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0, end: _progress),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE5E5E5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ListenerOption1 option) {
    final isSelected = _selectedId == option.id;
    Color borderColor = const Color(0xFFE5E5E5);
    Color bgColor = Colors.white;

    if (isSelected) {
      borderColor = const Color(0xFF1CB0F6);
      bgColor = const Color(0xFF1CB0F6).withValues(alpha: 0.08);
    }

    if (_isChecked) {
      final isCorrectCard = option.label == _currentQuestion.correctAnswer;
      if (isCorrectCard) {
        borderColor = const Color(0xFF58CC02);
        bgColor = const Color(0xFF58CC02).withValues(alpha: 0.12);
      } else if (isSelected && !_isCorrect) {
        borderColor = const Color(0xFFFF4B4B);
        bgColor = const Color(0xFFFF4B4B).withValues(alpha: 0.12);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onSelect(option.id),
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: isSelected || _isChecked ? 3 : 2),
            boxShadow: isSelected
                ? [BoxShadow(color: borderColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(
                'assets/images/listenerGeneralFood/${option.id}.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/images/${option.id}.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.fastfood_rounded, size: 54, color: Color(0xFF1CB0F6)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    if (_isChecked) {
      final statusColor = _isCorrect ? const Color(0xFF58CC02) : const Color(0xFFFF4B4B);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: _isCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFE0),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: statusColor, size: 30),
                const SizedBox(width: 10),
                Text(
                  _isCorrect ? 'Nicely done! 🎉' : 'Correct answer:',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: statusColor),
                ),
              ],
            ),
            if (!_isCorrect) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(_currentQuestion.correctAnswer, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _currentIndex >= _questions.length - 1 ? 'FINISH' : 'CONTINUE',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isEnabled = _selectedId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isEnabled ? const [BoxShadow(color: Color(0xFF46A302), offset: Offset(0, 4))] : null,
          ),
          child: ElevatedButton(
            onPressed: isEnabled ? _checkAnswer : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5E5E5),
              disabledForegroundColor: const Color(0xFFAFAFAF),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('CHECK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
          ),
        ),
      ),
    );
  }
}
