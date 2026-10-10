import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/repositories/progress_repository.dart';

class PhaseTopicItem {
  final int id;
  final String title;
  final IconData icon;
  final int level;
  final bool isLocked;

  const PhaseTopicItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.level,
    this.isLocked = false,
  });
}

/// Reusable Base Template untuk seluruh halaman Phase Section.
class BasePhasePage extends StatefulWidget {
  final String title;
  final IconData sectionIcon;
  final Color sectionColor;
  final Color? highlightBorderColor;
  final String mainTopicTitle;
  final IconData mainTopicIcon;
  final WidgetBuilder mainTopicPageBuilder;
  final String trophyTitle;
  final Color? trophyBgColor;
  final Color? trophyIconColor;
  final Map<int, WidgetBuilder>? levelBuilders;
  final String? sectionKey;
  final String? phaseKey;
  final int? currentUnlockedLevel;

  const BasePhasePage({
    super.key,
    required this.title,
    required this.sectionIcon,
    required this.sectionColor,
    this.highlightBorderColor,
    required this.mainTopicTitle,
    required this.mainTopicIcon,
    required this.mainTopicPageBuilder,
    required this.trophyTitle,
    this.trophyBgColor,
    this.trophyIconColor,
    this.levelBuilders,
    this.sectionKey,
    this.phaseKey,
    this.currentUnlockedLevel,
  });

  @override
  State<BasePhasePage> createState() => _BasePhasePageState();
}

class _BasePhasePageState extends State<BasePhasePage> {
  final ProgressRepository _progressRepo = ProgressRepository();
  int _unlockedLevel = 0;

  @override
  void initState() {
    super.initState();
    _unlockedLevel = widget.currentUnlockedLevel ?? 0;
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (widget.sectionKey != null && widget.phaseKey != null) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final lastLevel = await _progressRepo.getLastLevel(
          userId,
          widget.sectionKey!,
          widget.phaseKey!,
        );
        if (mounted) setState(() => _unlockedLevel = lastLevel);
      }
    }
  }

  List<PhaseTopicItem> _getPhases() {
    return [
      PhaseTopicItem(id: 1, title: widget.mainTopicTitle, icon: widget.mainTopicIcon, level: 0, isLocked: false),
      for (int lvl = 1; lvl <= 3; lvl++)
        PhaseTopicItem(
          id: lvl + 1,
          title: 'Lv. $lvl',
          icon: _unlockedLevel >= lvl ? widget.mainTopicIcon : Icons.lock_rounded,
          level: lvl,
          isLocked: _unlockedLevel < lvl,
        ),
    ];
  }

  void _startPhase(BuildContext context, PhaseTopicItem phase) {
    if (phase.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${phase.title} masih terkunci. Selesaikan level sebelumnya terlebih dahulu!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (phase.id == 1) {
      Navigator.push(context, MaterialPageRoute(builder: widget.mainTopicPageBuilder))
          .then((_) => _loadProgress());
    } else if (widget.levelBuilders != null && widget.levelBuilders!.containsKey(phase.level)) {
      Navigator.push(context, MaterialPageRoute(builder: widget.levelBuilders![phase.level]!))
          .then((_) => _loadProgress());
    }
  }

  @override
  Widget build(BuildContext context) {
    final phases = _getPhases();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E5E5)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF3C3C3C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.sectionIcon, color: widget.sectionColor, size: 24),
            const SizedBox(width: 8),
            Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C))),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            for (final phase in phases) ...[
              _buildPhaseNode(context, phase),
              _buildConnector(),
            ],
            _buildTrophy(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophy() {
    final isUnlocked = _unlockedLevel >= 4;
    final trophyBg = isUnlocked
        ? (widget.trophyBgColor ?? widget.sectionColor.withValues(alpha: 0.15))
        : Colors.grey.shade200;
    final trophyIcon = isUnlocked
        ? (widget.trophyIconColor ?? widget.sectionColor)
        : Colors.grey.shade400;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: trophyBg,
            shape: BoxShape.circle,
            boxShadow: [
              if (isUnlocked)
                BoxShadow(color: trophyIcon.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Icon(isUnlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded, size: 64, color: trophyIcon),
        ),
        const SizedBox(height: 10),
        Text(
          widget.trophyTitle,
          style: TextStyle(fontWeight: FontWeight.bold, color: isUnlocked ? trophyIcon : Colors.grey.shade600),
        ),
        if (!isUnlocked)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text('Selesaikan Lv. 3 untuk meraih Master Trophy', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 4,
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(2)),
    );
  }

  Widget _buildPhaseNode(BuildContext context, PhaseTopicItem phase) {
    final isLocked = phase.isLocked;
    final nodeColor = isLocked ? const Color(0xFFE5E5E5) : widget.sectionColor;
    final iconColor = isLocked ? const Color(0xFFAFAFAF) : Colors.white;
    final borderColor = isLocked
        ? const Color(0xFFE5E5E5)
        : (widget.highlightBorderColor ?? widget.sectionColor.withValues(alpha: 0.5));

    return GestureDetector(
      onTap: () => _startPhase(context, phase),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: borderColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: isLocked ? Colors.black.withValues(alpha: 0.05) : widget.sectionColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                    child: Icon(phase.icon, color: iconColor, size: 38),
                  ),
                ),
              ),
              if (phase.level > 0)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLocked ? const Color(0xFFAFAFAF) : const Color(0xFFFFC800),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isLocked ? Icons.lock : Icons.star, size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text('${phase.level}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(phase.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C))),
        ],
      ),
    );
  }
}
