import 'package:flutter/material.dart';
import 'package:app/features/dashboard/phase_coming_soon_page.dart';

/// Halaman Listener General Food Level 2 (Coming Soon)
class GeneralFoodLv2Page extends StatelessWidget {
  const GeneralFoodLv2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhaseComingSoonPage(
      title: 'Listener Phases',
      topicTitle: 'General Food',
      level: 2,
      sectionColor: Color(0xFF58CC02),
      sectionIcon: Icons.headphones_rounded,
    );
  }
}
