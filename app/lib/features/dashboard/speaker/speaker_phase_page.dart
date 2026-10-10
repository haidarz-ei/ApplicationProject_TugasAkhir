import 'package:flutter/material.dart';
import 'package:app/features/dashboard/base_phase_page.dart';
import 'package:app/features/dashboard/speaker/phase/pronunciation/speaker_pronunciation.dart';
import 'package:app/features/dashboard/speaker/phase/pronunciation/pronunciation_lv1.dart';
import 'package:app/features/dashboard/speaker/phase/pronunciation/pronunciation_lv2.dart';
import 'package:app/features/dashboard/speaker/phase/pronunciation/pronunciation_lv3.dart';

/// Halaman Speaker Phase
class SpeakerPhasePage extends StatelessWidget {
  const SpeakerPhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePhasePage(
      title: 'Speaker Phases',
      sectionIcon: Icons.record_voice_over,
      sectionColor: const Color(0xFFFF9600),
      highlightBorderColor: const Color(0xFFFFB020),
      mainTopicTitle: 'Pronunciation 1',
      mainTopicIcon: Icons.record_voice_over,
      sectionKey: 'speaker',
      phaseKey: 'pronunciation',
      mainTopicPageBuilder: (_) => const SpeakerPronunciationPage(level: 0),
      levelBuilders: {
        1: (_) => const PronunciationLv1Page(),
        2: (_) => const PronunciationLv2Page(),
        3: (_) => const PronunciationLv3Page(),
      },
      trophyTitle: 'Speaker Master Trophy',
      trophyBgColor: const Color(0xFFFFF3E0),
      trophyIconColor: const Color(0xFFFF9600),
    );
  }
}
