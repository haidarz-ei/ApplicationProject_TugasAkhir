import 'package:flutter/material.dart';
import 'package:app/features/dashboard/base_phase_page.dart';
import 'package:app/features/dashboard/native_mind/phase/strategy/native_mind_strategy.dart';
import 'package:app/features/dashboard/native_mind/phase/strategy/strategy_lv1.dart';
import 'package:app/features/dashboard/native_mind/phase/strategy/strategy_lv2.dart';
import 'package:app/features/dashboard/native_mind/phase/strategy/strategy_lv3.dart';

/// Halaman Native Mind Phase
class NativeMindPhasePage extends StatelessWidget {
  const NativeMindPhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePhasePage(
      title: 'Native Mind Phases',
      sectionIcon: Icons.psychology,
      sectionColor: const Color(0xFF00CD9C),
      highlightBorderColor: const Color(0xFF26E0B3),
      mainTopicTitle: 'Strategy',
      mainTopicIcon: Icons.psychology,
      sectionKey: 'native_mind',
      phaseKey: 'strategy',
      mainTopicPageBuilder: (_) => const NativeMindStrategyPage(level: 0),
      levelBuilders: {
        1: (_) => const StrategyLv1Page(),
        2: (_) => const StrategyLv2Page(),
        3: (_) => const StrategyLv3Page(),
      },
      trophyTitle: 'Native Mind Master Trophy',
      trophyBgColor: const Color(0xFFE0F2F1),
      trophyIconColor: const Color(0xFF00CD9C),
    );
  }
}
