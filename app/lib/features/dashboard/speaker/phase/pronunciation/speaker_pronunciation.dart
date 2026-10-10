import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:app/services/ai_evaluation_service.dart';
import 'package:app/services/sound_service.dart';
import 'package:video_player/video_player.dart';

enum MicState { idle, listening, evaluating, success, retry }

/// Halaman Speaker Pronunciation — Level 0–3 dengan AI Evaluation
class SpeakerPronunciationPage extends ConsumerStatefulWidget {
  final int level;
  const SpeakerPronunciationPage({super.key, this.level = 0});

  @override
  ConsumerState<SpeakerPronunciationPage> createState() => _SpeakerPronunciationPageState();
}

class _SpeakerPronunciationPageState extends ConsumerState<SpeakerPronunciationPage> {
  late final List<String> _words;
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  static const _levelWords = {
    0: ['cat', 'dog', 'run', 'red', 'big', 'eat', 'sun'],
    1: ['fish', 'big dog', 'red cat', 'I run', 'blue sky', 'eat now', 'my book'],
    2: ['I love you', 'big red ball', 'run and jump', 'the blue sky', 'a good boy', 'she can sing', 'eat your food'],
    3: ['I go to school', 'the dog is big', 'we play outside', 'she has a book', 'I can run fast', 'the sun is hot', 'my cat is cute'],
  };

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AIEvaluationService _aiService = AIEvaluationService();

  int _currentIndex = 0;
  MicState _micState = MicState.idle;
  Timer? _timer;
  Timer? _silenceTimer;
  bool _isPlaying = false;
  bool _speechAvailable = false;
  String _spokenText = '';
  String? _feedbackMessage;
  String? _phoneticTip;
  int _retryCount = 0;

  double get _progress => _micState == MicState.success
      ? (_currentIndex + 1) / _words.length
      : _currentIndex / _words.length;

  @override
  void initState() {
    super.initState();
    _words = List<String>.from(_levelWords[widget.level] ?? _levelWords[0]!);
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.65);
    _tts.setVolume(1.0);
    _initSpeech();
    _videoController = VideoPlayerController.asset('assets/vid/teacher.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoInitialized = true);
          _videoController.setLooping(true);
          _videoController.play();
        }
      });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _timer?.cancel();
    _speech.stop();
    _tts.stop();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg}');
          if (mounted && _micState == MicState.listening) _onListeningDone();
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if ((status == 'done' || status == 'notListening') && mounted) {
            if (_micState == MicState.listening) _onListeningDone();
          }
        },
      );
    } catch (e) {
      debugPrint('Error initializing SpeechToText: $e');
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  void _playAudio() {
    setState(() => _isPlaying = true);
    _tts.speak(_words[_currentIndex]);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _onMicTap() async {
    if (_micState == MicState.evaluating) return;

    if (_micState == MicState.listening) {
      await _speech.stop();
      _onListeningDone();
      return;
    }

    _spokenText = '';
    setState(() { _micState = MicState.listening; _feedbackMessage = null; _phoneticTip = null; });

    if (!_speechAvailable) await _initSpeech();

    if (_speechAvailable) {
      try {
        await _speech.listen(
          onResult: (result) {
            final words = result.recognizedWords.replaceAll(RegExp(r'[^\w\s]'), '').trim();
            if (words.isNotEmpty) setState(() => _spokenText = words);
            if (result.finalResult) {
              _silenceTimer?.cancel();
              if (mounted && _micState == MicState.listening) _onListeningDone();
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.confirmation,
            cancelOnError: false,
            partialResults: false, // final only — lebih stabil di Chrome
            localeId: 'en_US',
          ),
        );
        // Safety fallback: kalau engine tidak fire finalResult, tunggu max 5 detik
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && _micState == MicState.listening) _onListeningDone();
        });
      } catch (e) {
        debugPrint('Listen error: $e');
        _fallbackSimulation();
      }
    } else {
      _fallbackSimulation();
    }
  }

  void _fallbackSimulation() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      if (_spokenText.isEmpty) _spokenText = _words[_currentIndex];
      _evaluateAnswer(_spokenText);
    });
  }

  Future<void> _onListeningDone() async {
    if (_micState != MicState.listening) return;
    _silenceTimer?.cancel();
    _timer?.cancel();
    try { if (_speech.isListening) await _speech.stop(); } catch (_) {}

    final captured = _spokenText.trim();
    if (captured.isEmpty) {
      setState(() {
        _micState = MicState.retry;
        _feedbackMessage = "Didn't catch your voice. Please speak clearly into your mic!";
      });
      return;
    }
    _evaluateAnswer(captured);
  }

  Future<void> _evaluateAnswer(String spoken) async {
    setState(() => _micState = MicState.evaluating);

    final targetWord = _words[_currentIndex].toLowerCase().trim();
    final cleanSpoken = spoken.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '').trim();

    if (cleanSpoken.isEmpty) {
      setState(() {
        _micState = MicState.retry;
        _feedbackMessage = "Didn't catch your voice. Please speak clearly into your mic!";
        _phoneticTip = '/$targetWord/';
      });
      return;
    }

    final wordsInSpoken = cleanSpoken.split(RegExp(r'\s+'));
    final targetWords = targetWord.split(RegExp(r'\s+'));

    // Cek kecocokan — kata tunggal: fuzzy, frasa: setiap kata target harus muncul
    final isMatch = targetWords.length == 1
        ? (cleanSpoken == targetWord ||
            cleanSpoken == '${targetWord}s' ||
            cleanSpoken == '${targetWord}es' ||
            wordsInSpoken.contains(targetWord) ||
            wordsInSpoken.contains('${targetWord}s') ||
            wordsInSpoken.any((w) => w.startsWith(targetWord)) ||
            wordsInSpoken.any((w) => targetWord.startsWith(w) && w.length >= targetWord.length - 1) ||
            wordsInSpoken.any((w) => _isFuzzyMatch(w, targetWord)))
        : targetWords.every((tw) =>
            wordsInSpoken.any((sw) =>
                sw == tw || sw.startsWith(tw) || tw.startsWith(sw) || _isFuzzyMatch(sw, tw)));

    if (isMatch) {
      SoundService.playCorrect();
      setState(() {
        _micState = MicState.success;
        _feedbackMessage = 'Great pronunciation! 🎉';
        _phoneticTip = targetWords.map((w) => '/$w/').join(' ');
      });
      return;
    }

    // Tidak cocok — tanya AI
    try {
      final result = await _aiService.evaluate(
        section: 'speaker',
        userAnswer: cleanSpoken,
        context: {'level': widget.level, 'targetWord': targetWord},
      );
      if (!mounted) return;

      // Filter: pastikan bukan respon bocor dari Native Mind
      final isNativeMindLeak = result.feedback.toLowerCase().contains('situational') ||
          result.feedback.toLowerCase().contains('reflex') ||
          result.feedback.toLowerCase().contains('noun');

      if (result.success && result.score >= 75 && !isNativeMindLeak) {
        SoundService.playCorrect();
        setState(() {
          _micState = MicState.success;
          _feedbackMessage = result.aiReply.isNotEmpty ? result.aiReply : 'Great pronunciation! 🎉';
          _phoneticTip = result.betterAlternative;
        });
        return;
      }
    } catch (_) {}

    SoundService.playWrong();
    final displaySpoken = cleanSpoken.isNotEmpty ? cleanSpoken : spoken.trim();
    setState(() {
      _micState = MicState.retry;
      _retryCount++;
      _feedbackMessage = "You said '$displaySpoken'. Try saying '$targetWord' clearly into the mic!";
      _phoneticTip = '/$targetWord/';
    });
  }

  void _nextWord() {
    _silenceTimer?.cancel();
    _timer?.cancel();
    try { _speech.cancel(); } catch (_) {}

    if (_currentIndex < _words.length - 1) {
      if (_videoInitialized) { _videoController.seekTo(Duration.zero); _videoController.play(); }
      setState(() {
        _currentIndex++;
        _micState = MicState.idle;
        _spokenText = '';
        _feedbackMessage = null;
        _phoneticTip = null;
        _retryCount = 0;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      ProgressRepository().updateProgress(userId, 'speaker', 'pronunciation', widget.level + 1);
    }
    ref.read(sectionsProvider.notifier).updateSectionLevel(2, widget.level + 1);
    if (widget.level >= 3) ref.read(sectionsProvider.notifier).completeSection(2);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Awesome!', textAlign: TextAlign.center),
        content: const Text(
          'You completed all pronunciation exercises with AI evaluation!',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4AC47D),
                foregroundColor: Colors.white,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildTopBar(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Follow and Say the word',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF212529))),
                        SizedBox(height: 4),
                        Text('Listen to the word, then speak clearly into your mic.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF868E96))),
                      ],
                    ),
                  ),
                ),
                Expanded(child: Center(child: _buildTeacherVideo())),
                _buildFeedbackBanner(),
                _buildMicButton(),
                const SizedBox(height: 16),
                _buildActionButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFFAFAFAF), size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0, end: _progress),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
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

  Widget _buildTeacherVideo() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 160,
          child: _videoInitialized
              ? AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: VideoPlayer(_videoController))
              : const SizedBox(width: 120, height: 160,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C5CE7)))),
        ),
        Positioned(
          top: 0,
          right: -10,
          child: GestureDetector(
            onTap: _playAudio,
            child: AnimatedScale(
              scale: _isPlaying ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1CB0F6),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF1CB0F6).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner() {
    if (_feedbackMessage == null || (_micState != MicState.retry && _micState != MicState.success)) {
      return const SizedBox.shrink();
    }

    final isSuccess = _micState == MicState.success;
    final accentColor = isSuccess ? const Color(0xFF4AC47D) : const Color(0xFFFF4B4B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFF0FFF4) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSuccess ? const Color(0xFFA3E6B5) : const Color(0xFFFFC9C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(isSuccess ? 'Nice work! ✨' : 'AI Pronunciation Tip',
                  style: TextStyle(fontWeight: FontWeight.w800, color: accentColor)),
              if (_phoneticTip != null && _phoneticTip!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_phoneticTip!, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF868E96))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(_feedbackMessage!, style: const TextStyle(fontSize: 13, color: Color(0xFF495057), height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isSuccess = _micState == MicState.success;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Tombol LANJUT
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isSuccess ? 1.0 : 0.35,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSuccess ? _nextWord : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? const Color(0xFF4AC47D) : const Color(0xFFD0D0D0),
                  disabledBackgroundColor: const Color(0xFFD0D0D0),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF9E9E9E),
                  elevation: isSuccess ? 4 : 0,
                  shadowColor: const Color(0xFF4AC47D).withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('LANJUT',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
              ),
            ),
          ),
          // Tombol SKIP — muncul setelah gagal 2x
          if (_micState == MicState.retry && _retryCount >= 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _nextWord,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9E9E9E),
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('LEWATI KATA INI',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    final (btnColor, textLabel, textColor, icon) = switch (_micState) {
      MicState.idle       => (const Color(0xFF1CB0F6), 'Tap to speak',            const Color(0xFF495057), Icons.mic_rounded),
      MicState.listening  => (const Color(0xFFFF4B4B), 'Listening... speak now!', const Color(0xFFFF4B4B), Icons.mic_rounded),
      MicState.evaluating => (const Color(0xFFFAB005), 'AI evaluating...',        const Color(0xFFD97706), Icons.hourglass_top_rounded),
      MicState.success    => (const Color(0xFF4AC47D), _feedbackMessage ?? 'Great! 🎉', const Color(0xFF4AC47D), Icons.check_rounded),
      MicState.retry      => (const Color(0xFF1CB0F6), 'Tap mic to try again',   const Color(0xFF1CB0F6), Icons.replay_rounded),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _onMicTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: btnColor,
              boxShadow: [BoxShadow(
                color: btnColor.withValues(alpha: 0.35),
                blurRadius: _micState == MicState.listening ? 20 : 14,
                spreadRadius: _micState == MicState.listening ? 4 : 0,
                offset: const Offset(0, 4),
              )],
            ),
            child: _micState == MicState.evaluating
                ? const Center(child: SizedBox(width: 32, height: 32,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
                : Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(textLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }
}

// ─── Levenshtein Edit Distance ────────────────────────────────────────────────

/// Hitung jumlah minimum operasi (insert/delete/replace) untuk ubah [s1] → [s2]
int _editDistance(String s1, String s2) {
  final m = s1.length, n = s2.length;
  var prev = List<int>.generate(n + 1, (j) => j);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      curr[j] = s1[i - 1] == s2[j - 1] ? prev[j - 1] : 1 + min(prev[j], min(curr[j - 1], prev[j - 1]));
    }
    final tmp = prev; prev = curr; curr = tmp;
  }
  return prev[n];
}

/// True jika [spoken] cukup mirip dengan [target] berdasarkan toleransi adaptif:
/// - kata ≤4 huruf  → toleransi 1 edit  (e.g. "scar" ↔ "star")
/// - kata 5–7 huruf → toleransi 2 edit  (e.g. "aple" ↔ "apple")
/// - kata >7 huruf  → toleransi 3 edit  (e.g. "pronnciation" ↔ "pronunciation")
bool _isFuzzyMatch(String spoken, String target) {
  if (spoken.isEmpty || target.isEmpty) return false;
  final maxAllowed = target.length <= 4 ? 1 : target.length <= 7 ? 2 : 3;
  return _editDistance(spoken, target) <= maxAllowed;
}

typedef SpeakerTahap1Page = SpeakerPronunciationPage;
