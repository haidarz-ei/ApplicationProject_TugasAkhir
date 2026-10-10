import 'package:flutter/material.dart';
import 'package:app/features/dashboard/base_phase_page.dart';
import 'package:app/features/dashboard/builder/phase/word_combine/builder_word_combine.dart';
import 'package:app/features/dashboard/builder/phase/word_combine/word_combine_lv1.dart';
import 'package:app/features/dashboard/builder/phase/word_combine/word_combine_lv2.dart';
import 'package:app/features/dashboard/builder/phase/word_combine/word_combine_lv3.dart';

/// Halaman Builder Phase
class BuilderPhasePage extends StatelessWidget {
  const BuilderPhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePhasePage(
      title: 'Builder Phases',
      sectionIcon: Icons.extension,
      sectionColor: const Color(0xFFCE82FF),
      highlightBorderColor: const Color(0xFFDA9EFF),
      mainTopicTitle: 'Word Combine 1',
      mainTopicIcon: Icons.extension,
      sectionKey: 'builder',
      phaseKey: 'word_combine',
      mainTopicPageBuilder: (_) => const BuilderWordCombinePage(level: 0),
      levelBuilders: {
        1: (_) => const WordCombineLv1Page(),
        2: (_) => const WordCombineLv2Page(),
        3: (_) => const WordCombineLv3Page(),
      },
      trophyTitle: 'Builder Master Trophy',
      trophyBgColor: const Color(0xFFF3E5F5),
      trophyIconColor: const Color(0xFFCE82FF),
    );
  }
}
