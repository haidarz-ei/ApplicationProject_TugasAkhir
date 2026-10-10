import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:app/services/ai_evaluation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:app/services/sound_service.dart';
import 'package:app/features/dashboard/phase_coming_soon_page.dart';

class NativeMindScenario {
  final String question;
  final String imagePath;
  const NativeMindScenario({required this.question, required this.imagePath});
}

/// Halaman NativeMind Strategy — Level 0–3
class NativeMindStrategyPage extends ConsumerStatefulWidget {
  final int level;
  const NativeMindStrategyPage({super.key, this.level = 0});

  @override
  ConsumerState<NativeMindStrategyPage> createState() => _NativeMindStrategyPageState();
}

class _NativeMindStrategyPageState extends ConsumerState<NativeMindStrategyPage> {
  final TextEditingController _textController = TextEditingController();
  final AIEvaluationService _aiService = AIEvaluationService();
  late final List<NativeMindScenario> _scenarios;

  static const _lv0 = [
    NativeMindScenario(question: 'How would you help the child cross safely?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal1.png'),
    NativeMindScenario(question: 'A little cat is stuck in a tree. What should you do to help it?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal2.png'),
    NativeMindScenario(question: 'The room is too dark to study. What would you do?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal3.png'),
    NativeMindScenario(question: 'Your friend accidentally spilled water on the table. What will you do?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal4.png'),
    NativeMindScenario(question: 'You see dark rain clouds before walking home. What will you prepare?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal5.png'),
    NativeMindScenario(question: 'The bus is full and an older person gets on. What will you do?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal6.png'),
    NativeMindScenario(question: 'The plants look dry under the hot sun. How will you help them?', imagePath: 'assets/images/NativeMindPhase/strategy/nativeMind_lv0_soal7.png'),
  ];
  // Level 1–3 dikosongkan terlebih dahulu sesuai instruksi
  static const _lv1 = <NativeMindScenario>[];
  static const _lv2 = <NativeMindScenario>[];
  static const _lv3 = <NativeMindScenario>[];

  int _currentIndex = 0;
  bool _isChecked = false;
  bool _isAnswerValid = false;
  bool _isEvaluating = false;
  double? _aiScore;
  String? _aiReply;
  String? _aiFeedback;
  String? _aiAlternative;

  static const _primaryColor = Color(0xFF00CD9C);

  NativeMindScenario get _current => _scenarios[_currentIndex];

  @override
  void initState() {
    super.initState();
    _scenarios = switch (widget.level) {
      1 => List.from(_lv1),
      2 => List.from(_lv2),
      3 => List.from(_lv3),
      _ => List.from(_lv0),
    };
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkAnswer() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isEvaluating) return;

    setState(() => _isEvaluating = true);

    final result = await _aiService.evaluate(
      section: 'native_mind',
      userAnswer: text,
      context: {
        'scenario': _current.question,
        'task': 'Evaluate spontaneous natural reflex and situational logic in English',
      },
    );

    if (!mounted) return;

    setState(() {
      _isEvaluating = false;
      _isChecked = true;
      _isAnswerValid = true;
      if (result.success) {
        _aiScore = result.score;
        _aiReply = result.aiReply.isNotEmpty ? result.aiReply : 'Nice try! 👏';
        _aiFeedback = result.feedback;
        _aiAlternative = result.betterAlternative;
      } else {
        _aiScore = 80;
        _aiReply = 'Nice try! 👏';
        _aiFeedback = 'I love that you came up with a practical solution! Keep trusting your spontaneous thinking!';
        _aiAlternative = null;
      }
    });

    ((_aiScore ?? 0) >= 60) ? SoundService.playCorrect() : SoundService.playWrong();
  }

  void _nextScenario() {
    if (_currentIndex < _scenarios.length - 1) {
      setState(() {
        _currentIndex++;
        _textController.clear();
        _isChecked = false;
        _isAnswerValid = false;
        _aiScore = null; _aiReply = null; _aiFeedback = null; _aiAlternative = null;
      });
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      ProgressRepository().updateProgress(userId, 'native_mind', 'strategy', widget.level + 1);
    }
    ref.read(sectionsProvider.notifier).updateSectionLevel(5, widget.level + 1);
    if (widget.level >= 3) ref.read(sectionsProvider.notifier).completeSection(5);
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 Native Mind Mastered!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You solved the situational challenge with natural English reasoning!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
            ),
            if (_aiScore != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('AI Reflex Score: ${_aiScore!.toInt()} / 100',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Center(
              child: Text('FINISH & RETURN TO DASHBOARD',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level >= 1) {
      return PhaseComingSoonPage(
        title: 'Native Mind Phases',
        topicTitle: 'Strategy',
        level: widget.level,
        sectionColor: _primaryColor,
        sectionIcon: Icons.psychology,
      );
    }

    final progress = ((_isChecked && _isAnswerValid) ? _currentIndex + 1 : _currentIndex) / _scenarios.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildTopBar(progress),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_current.question, maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F2942), height: 1.25)),
                        const SizedBox(height: 10),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: _isChecked ? 140 : 220,
                              child: Image.asset(_current.imagePath, fit: BoxFit.contain,
                                  errorBuilder: (ctx, error, stackTrace) => const SizedBox.shrink()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInputField(),
                        if (_isChecked) ...[
                          const SizedBox(height: 10),
                          Expanded(child: SingleChildScrollView(child: _buildFeedbackCard())),
                        ] else
                          const Spacer(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24, color: Color(0xFF4A5568)),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('Native Mind', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A202C))),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0, end: progress),
                builder: (context, val, child) => LinearProgressIndicator(
                  value: val, minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation(_primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Spontaneous Solution (in English):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF718096))),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isChecked
                  ? (_isAnswerValid ? _primaryColor : const Color(0xFFFF6B6B))
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _textController,
            enabled: !_isChecked && !_isEvaluating,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _checkAnswer(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Type your spontaneous reaction or solution...',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFFA0AEC0)),
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/teacher_avatar.png', fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stackTrace) => Container(
                        color: const Color(0xFFFFEDD5),
                        alignment: Alignment.center,
                        child: const Text('👩‍🏫', style: TextStyle(fontSize: 26)),
                      )),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(_aiReply ?? 'Nice try! 👏',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_aiFeedback ?? 'I understand what you mean!',
              style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF1E293B))),
          if (_aiAlternative != null && _aiAlternative!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('💡', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('A more natural way to say it:',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_aiAlternative!,
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: Color(0xFF1E40AF), height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDF2F7))),
      ),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: _isEvaluating ? null : (_isChecked ? _nextScenario : _checkAnswer),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isEvaluating
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(_isChecked ? 'CONTINUE' : 'EVALUATE WITH AI',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

typedef NativeMindTahap1Page = NativeMindStrategyPage;
typedef NativeMindSpontaneousResponsePage = NativeMindStrategyPage;
