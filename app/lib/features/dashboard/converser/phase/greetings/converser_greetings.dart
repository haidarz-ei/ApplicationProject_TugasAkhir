import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/utils/connectivity_helper.dart';
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:app/services/ai_evaluation_service.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMsg {
  final String text;
  final bool isUser;
  final double? turnScore;
  final double? cumulativeScore;
  final String? feedback;
  final String? betterAlternative;

  const ChatMsg(
    this.text, {
    required this.isUser,
    this.turnScore,
    this.cumulativeScore,
    this.feedback,
    this.betterAlternative,
  });
}

/// Halaman Converser Greetings — Percakapan Interaktif Level 0–3 dengan Gemini AI
class ConverserGreetingsPage extends ConsumerStatefulWidget {
  final int level;
  const ConverserGreetingsPage({super.key, this.level = 0});

  @override
  ConsumerState<ConverserGreetingsPage> createState() => _ConverserGreetingsPageState();
}

class _ConverserGreetingsPageState extends ConsumerState<ConverserGreetingsPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIEvaluationService _aiService = AIEvaluationService();
  final ProgressRepository _progressRepo = ProgressRepository();

  late final List<ChatMsg> _messages;

  int _turnCount = 1;
  double _cumulativeScore = 0.0;
  bool _isAiThinking = false;

  // Kalimat pembuka bervariasi sesuai level dan skenario nyata
  static const _initialGreetings = {
    0: "Hi! I'm Alex, your new friend. What is your name?",
    1: 'Good morning! What did you have for breakfast today?',
    2: 'Hello! If you could travel to any country in the world tomorrow, where would you go?',
    3: "Hey! I really need your advice. We're planning a surprise birthday party for Sarah, but we can't decide between a park picnic or a cafe party. What do you think would be more fun?",
  };

  @override
  void initState() {
    super.initState();
    final greeting = _initialGreetings[widget.level] ?? _initialGreetings[0]!;
    _messages = [ChatMsg(greeting, isUser: false)];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showNoInternetAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Tidak Ada Koneksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Fitur AI Converser membutuhkan koneksi internet.\nPastikan Anda terhubung lalu coba lagi.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B4B),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isAiThinking) return;

    // Cek koneksi internet sebelum mengirim ke AI
    final hasInternet = await ConnectivityHelper.hasInternetConnection();
    if (!hasInternet && mounted) {
      _showNoInternetAlert();
      return;
    }

    _controller.clear();
    setState(() { _messages.add(ChatMsg(text, isUser: true)); _isAiThinking = true; });
    _scrollToBottom();

    final history = _messages.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();

    final result = await _aiService.evaluate(
      section: 'converser',
      userAnswer: text,
      context: {
        'level': widget.level,
        'phase': 'greetings',
        'turnCount': _turnCount,
        'cumulativeScore': _cumulativeScore,
        'history': history,
      },
    );

    if (!mounted) return;

    setState(() {
      _isAiThinking = false;
      if (result.success) {
        _turnCount = result.turnCount;
        _cumulativeScore = result.cumulativeScore.clamp(0.0, 100.0);
        // Update bubble user terakhir dengan skor turn ini
        final lastIdx = _messages.length - 1;
        _messages[lastIdx] = ChatMsg(text, isUser: true,
          turnScore: result.turnScore,
          cumulativeScore: _cumulativeScore,
          feedback: result.feedback,
          betterAlternative: result.betterAlternative,
        );
        _messages.add(ChatMsg(
          result.aiReply.isNotEmpty ? result.aiReply : "That's wonderful! What else is on your mind today?",
          isUser: false,
        ));
      } else {
        // Fallback jika network offline / timeout
        _turnCount++;
        _cumulativeScore = (_cumulativeScore + 14.29).clamp(0.0, 100.0);
        _messages.add(const ChatMsg("Nice to hear that! Keep going, what else would you like to say?", isUser: false));
      }
    });

    _scrollToBottom();

    // Jika telah memenuhi syarat lulus (minimal 7 turn & akumulasi 100 poin)
    if (result.isComplete || (_turnCount >= 7 && _cumulativeScore >= 99.5)) {
      _onLevelCompleted();
    }
  }

  Future<void> _onLevelCompleted() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await _progressRepo.updateProgress(userId, 'converser', 'greetings', widget.level + 1);
    }
    ref.read(sectionsProvider.notifier).updateSectionLevel(4, widget.level + 1);
    if (widget.level >= 3) ref.read(sectionsProvider.notifier).completeSection(4);
    if (mounted) _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Column(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text('Level ${widget.level} Completed!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Awesome job! You reached 100 points in $_turnCount turns.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B4B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('100 / 100 PTS',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF4B4B))),
            ),
            const SizedBox(height: 12),
            Text(
              widget.level < 3
                  ? 'Level ${widget.level + 1} is now unlocked!'
                  : 'Congratulations! You mastered all Converser Greetings levels!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B4B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isAiThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isAiThinking) return _buildThinkingBubble();
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progressVal = (_cumulativeScore / 100.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFFE3E3),
                child: Icon(Icons.forum_rounded, color: Color(0xFFFF4B4B), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Greetings • Lv. ${widget.level}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4B4B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_cumulativeScore.round()}/100 pts',
                              style: const TextStyle(color: Color(0xFFFF4B4B), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Turn $_turnCount (min. 7 turns) • Converser AI',
                        style: const TextStyle(color: Color(0xFF868E96), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: 0, end: progressVal),
              builder: (context, val, child) => LinearProgressIndicator(
                value: val, minHeight: 8,
                backgroundColor: const Color(0xFFE9ECEF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4B4B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4B4B))),
            SizedBox(width: 8),
            Text('Partner is typing...',
                style: TextStyle(fontSize: 12, color: Color(0xFF868E96), fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMsg msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser ? const Color(0xFFFF4B4B) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                border: msg.isUser ? null : Border.all(color: const Color(0xFFE9ECEF)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(msg.text,
                  style: TextStyle(fontSize: 15, height: 1.35,
                      color: msg.isUser ? Colors.white : const Color(0xFF212529))),
            ),
            if (msg.turnScore != null) _buildScoreBadge(msg),
          ],
        ),
      ),
    );
  }

  /// Badge skor per turn — muncul di bawah bubble user
  Widget _buildScoreBadge(ChatMsg msg) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 14),
              const SizedBox(width: 4),
              Text('+${msg.turnScore!.toStringAsFixed(1)} pts (${msg.cumulativeScore?.round() ?? 0}/100)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
          if (msg.betterAlternative != null && msg.betterAlternative!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('💡 "${msg.betterAlternative}"',
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B4EFF), fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _controller,
                enabled: !_isAiThinking,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _isAiThinking ? 'Waiting for reply...' : 'Type your answer...',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFADB5BD)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isAiThinking
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4B4B)))
                : const Icon(Icons.send_rounded, color: Color(0xFFFF4B4B)),
            onPressed: _isAiThinking ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

typedef ConverserTahap1Page = ConverserGreetingsPage;
