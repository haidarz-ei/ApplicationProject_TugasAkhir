import 'package:flutter/material.dart';
import 'package:app/features/dashboard/phase_coming_soon_page.dart';

/// Halaman Native Mind Strategy Level 2 (Coming Soon)
class StrategyLv2Page extends StatelessWidget {
  const StrategyLv2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhaseComingSoonPage(
      title: 'Native Mind Phases',
      topicTitle: 'Strategy',
      level: 2,
      sectionColor: Color(0xFF00CD9C),
      sectionIcon: Icons.psychology,
    );
  }
}
