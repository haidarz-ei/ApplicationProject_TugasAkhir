import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:app/features/dashboard/newborn/newborn_page.dart';
import 'package:app/features/dashboard/listener/listener_phase_page.dart';
import 'package:app/features/dashboard/speaker/speaker_phase_page.dart';
import 'package:app/features/dashboard/builder/builder_phase_page.dart';
import 'package:app/features/dashboard/converser/converser_phase_page.dart';
import 'package:app/features/dashboard/native_mind/native_mind_phase_page.dart';

// --- MODEL & STATE ---
enum SectionStatus { locked, active, completed }


class SectionModel {
  final int id;
  final String title;
  final String subtitle;
  final SectionStatus status;
  final double progress;
  final IconData icon;
  final Color color;
  final WidgetBuilder pageBuilder;

  const SectionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.progress,
    required this.icon,
    required this.color,
    required this.pageBuilder,
  });

  SectionModel copyWith({SectionStatus? status, double? progress}) {
    return SectionModel(
      id: id,
      title: title,
      subtitle: subtitle,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      icon: icon,
      color: color,
      pageBuilder: pageBuilder,
    );
  }
}

class SectionsNotifier extends Notifier<List<SectionModel>> {
  final _progressRepo = ProgressRepository();

  @override
  List<SectionModel> build() {
    _loadPersistedProgress();
    return [
      SectionModel(
        id: 1,
        title: 'Newborn',
        subtitle: 'Passive exposure',
        status: SectionStatus.active,
        progress: 0.0,
        icon: Icons.child_care,
        color: const Color(0xFF1CB0F6),
        pageBuilder: (_) => const NewbornPage(),
      ),
      SectionModel(
        id: 2,
        title: 'Listener',
        subtitle: 'Introduction',
        status: SectionStatus.active,
        progress: 0.0,
        icon: Icons.headphones_rounded,
        color: const Color(0xFF58CC02),
        pageBuilder: (_) => const ListenerPhasePage(),
      ),
      SectionModel(
        id: 3,
        title: 'Speaker',
        subtitle: 'Word production',
        status: SectionStatus.active,
        progress: 0.0,
        icon: Icons.record_voice_over,
        color: const Color(0xFFFF9600),
        pageBuilder: (_) => const SpeakerPhasePage(),
      ),
      SectionModel(
        id: 4,
        title: 'Builder',
        subtitle: 'Word combining',
        status: SectionStatus.active,
        progress: 0.0,
        icon: Icons.extension,
        color: const Color(0xFFCE82FF),
        pageBuilder: (_) => const BuilderPhasePage(),
      ),
      SectionModel(
        id: 5,
        title: 'Converser',
        subtitle: 'Conversation',
        status: SectionStatus.active,
        progress: 0.0,
        icon: Icons.forum,
        color: const Color(0xFFFF4B4B),
        pageBuilder: (_) => const ConverserPhasePage(),
      ),
      SectionModel(
        id: 6,
        title: 'Native Mind',
        subtitle: 'Spontaneous expression',
        status: SectionStatus.active,
        progress: 0.0,
        icon: Icons.psychology,
        color: const Color(0xFF00CD9C),
        pageBuilder: (_) => const NativeMindPhasePage(),
      ),
    ];
  }

  Future<void> _loadPersistedProgress() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final records = await _progressRepo.getProgress(user.id);
      if (records.isEmpty) return;

      final progressMap = <String, int>{};
      for (final r in records) {
        final secKey = r.section.toLowerCase().replaceAll(' ', '_');
        final currentMax = progressMap[secKey] ?? 0;
        if (r.level > currentMax) progressMap[secKey] = r.level;
      }

      state = [
        for (final section in state)
          () {
            if (section.id == 1) return section.copyWith(status: SectionStatus.active, progress: 0.0);
            final secKey = section.title.toLowerCase().replaceAll(' ', '_');
            final level = progressMap[secKey] ?? 0;
            const maxLevel = 4;

            if (level >= maxLevel) {
              return section.copyWith(status: SectionStatus.completed, progress: 1.0);
            } else if (level > 0) {
              return section.copyWith(status: SectionStatus.active, progress: level / maxLevel);
            }
            return section;
          }(),
      ];
    } catch (_) {}
  }

  void updateSectionLevel(int index, int level) {
    if (index < 0 || index >= state.length || state[index].id == 1) return;

    const maxLevel = 4;
    final progress = (level / maxLevel).clamp(0.0, 1.0);
    final isCompleted = level >= maxLevel;

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(status: isCompleted ? SectionStatus.completed : SectionStatus.active, progress: progress)
        else if (isCompleted && i == index + 1 && state[i].status == SectionStatus.locked)
          state[i].copyWith(status: SectionStatus.active)
        else
          state[i]
    ];
  }

  void completeSection(int index) {
    if (index < 0 || index >= state.length || state[index].id == 1) return;
    updateSectionLevel(index, 4);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final secKey = state[index].title.toLowerCase().replaceAll(' ', '_');
      _progressRepo.updateProgress(user.id, secKey, 'main', 4).catchError((_) {});
    }
  }

  void resetAllSections() {
    state = [for (final section in state) section.copyWith(status: SectionStatus.active, progress: 0.0)];
  }
}

final sectionsProvider = NotifierProvider<SectionsNotifier, List<SectionModel>>(SectionsNotifier.new);

// --- MAIN PAGE ---
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(sectionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bgBeranda.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: const Color(0xFFF4F7FB)),
            ),
          ),
          SafeArea(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: sections.length + 1,
              separatorBuilder: (context, index) {
                if (index == 0) return const SizedBox(height: 12);
                final prevSection = sections[index - 1];
                final isLocked = sections[index].status == SectionStatus.locked;

                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 64,
                    height: 28,
                    alignment: Alignment.center,
                    child: Container(
                      width: 6,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.grey.shade300 : prevSection.color.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              },
              itemBuilder: (context, index) {
                if (index == 0) return const _TopBar();
                return _SectionRow(section: sections[index - 1]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- TOP BAR ---
class _TopBar extends StatelessWidget {
  const _TopBar();

  String _getUserDisplayName() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final rawName = (metadata?['full_name'] ?? metadata?['name'] ?? metadata?['display_name']) as String?;
    if (rawName != null && rawName.trim().isNotEmpty) return rawName.trim().split(' ').first;
    final email = user?.email;
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix[0].toUpperCase() + prefix.substring(1);
    }
    return 'Learner';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/logoAplikasi.png', width: 42, height: 42, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${_getUserDisplayName()}! 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                const Text('Learn every day, grow fluent naturally.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SECTION ROW ---
class _SectionRow extends StatefulWidget {
  final SectionModel section;
  const _SectionRow({required this.section});

  @override
  State<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends State<_SectionRow> {
  bool _isPressed = false;

  void _handleTap(BuildContext context) {
    if (widget.section.status == SectionStatus.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete the previous section first!')),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: widget.section.pageBuilder));
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _handleTap(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Row(
          children: [
            Expanded(child: _SectionCard(section: section)),
            const SizedBox(width: 16),
            _SectionAvatar(section: section),
          ],
        ),
      ),
    );
  }
}

// --- SECTION CARD ---
class _SectionCard extends StatelessWidget {
  final SectionModel section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final isLocked = section.status == SectionStatus.locked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLocked ? Colors.white.withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
        border: Border.all(
          color: isLocked ? Colors.grey.shade300 : section.color.withValues(alpha: 0.35),
          width: isLocked ? 1.0 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: isLocked ? Colors.grey : section.color, shape: BoxShape.circle),
                child: Text('${section.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isLocked ? Colors.grey : const Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            section.subtitle,
            style: TextStyle(fontSize: 11, color: isLocked ? Colors.grey : const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (section.id == 1)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(Icons.all_inclusive_rounded, size: 14, color: section.color),
                  const SizedBox(width: 4),
                  Text('Continuous Exposure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: section.color)),
                ],
              ),
            )
          else if (section.status == SectionStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: section.color),
                  const SizedBox(width: 4),
                  Text('Completed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: section.color)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: section.progress,
                  backgroundColor: section.color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(section.color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- SECTION AVATAR ---
class _SectionAvatar extends StatelessWidget {
  final SectionModel section;
  const _SectionAvatar({required this.section});

  @override
  Widget build(BuildContext context) {
    final isLocked = section.status == SectionStatus.locked;
    final isActive = section.status == SectionStatus.active;
    final isCompleted = section.status == SectionStatus.completed;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLocked ? Colors.grey.shade300 : Colors.white,
        border: Border.all(
          color: isLocked ? Colors.grey.shade400 : section.color,
          width: isActive ? 6 : 4,
        ),
        boxShadow: [
          if (isActive) BoxShadow(color: section.color.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 3),
        ],
      ),
      child: Center(
        child: isLocked
            ? Icon(Icons.lock, color: Colors.grey.shade500, size: 24)
            : isCompleted
                ? Container(
                    decoration: BoxDecoration(color: section.color, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                  )
                : Icon(section.icon, color: section.color, size: 28),
      ),
    );
  }
}
