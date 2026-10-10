import 'package:flutter/material.dart';
import 'package:app/features/dashboard/base_phase_page.dart';
import 'package:app/features/dashboard/listener/phase/general_food/listener_general_food.dart';
import 'package:app/features/dashboard/listener/phase/general_food/general_food_lv1.dart';
import 'package:app/features/dashboard/listener/phase/general_food/general_food_lv2.dart';
import 'package:app/features/dashboard/listener/phase/general_food/general_food_lv3.dart';

/// Halaman Listener Phase
class ListenerPhasePage extends StatelessWidget {
  const ListenerPhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePhasePage(
      title: 'Listener Phases',
      sectionIcon: Icons.headphones_rounded,
      sectionColor: const Color(0xFF58CC02),
      highlightBorderColor: const Color(0xFF84D800),
      mainTopicTitle: 'General Food',
      mainTopicIcon: Icons.restaurant,
      sectionKey: 'listener',
      phaseKey: 'general_food',
      mainTopicPageBuilder: (_) => const ListenerGeneralFoodPage(level: 0),
      levelBuilders: {
        1: (_) => const GeneralFoodLv1Page(),
        2: (_) => const GeneralFoodLv2Page(),
        3: (_) => const GeneralFoodLv3Page(),
      },
      trophyTitle: 'Listener Master Trophy',
      trophyBgColor: const Color(0xFFE0F7FA),
      trophyIconColor: const Color(0xFF00BCD4),
    );
  }
}
