import 'package:flutter/material.dart';
import 'package:app/features/dashboard/base_phase_page.dart';
import 'package:app/features/dashboard/converser/phase/greetings/converser_greetings.dart';
import 'package:app/features/dashboard/converser/phase/greetings/greeting_lv1.dart';
import 'package:app/features/dashboard/converser/phase/greetings/greeting_lv2.dart';
import 'package:app/features/dashboard/converser/phase/greetings/greeting_lv3.dart';

/// Halaman Converser Phase
class ConverserPhasePage extends StatelessWidget {
  const ConverserPhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePhasePage(
      title: 'Converser Phases',
      sectionIcon: Icons.forum,
      sectionColor: const Color(0xFFFF4B4B),
      highlightBorderColor: const Color(0xFFFF7878),
      mainTopicTitle: 'Greetings',
      mainTopicIcon: Icons.handshake,
      sectionKey: 'converser',
      phaseKey: 'greetings',
      mainTopicPageBuilder: (_) => const ConverserGreetingsPage(level: 0),
      levelBuilders: {
        1: (_) => const GreetingLv1Page(),
        2: (_) => const GreetingLv2Page(),
        3: (_) => const GreetingLv3Page(),
      },
      trophyTitle: 'Converser Master Trophy',
      trophyBgColor: const Color(0xFFFFEBEE),
      trophyIconColor: const Color(0xFFFF4B4B),
    );
  }
}
