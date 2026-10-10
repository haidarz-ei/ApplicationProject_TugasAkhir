import 'package:flutter/material.dart';
import 'package:app/features/dashboard/phase_coming_soon_page.dart';

/// Halaman Listener General Food Level 3 (Coming Soon)
class GeneralFoodLv3Page extends StatelessWidget {
  const GeneralFoodLv3Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhaseComingSoonPage(
      title: 'Listener Phases',
      topicTitle: 'General Food',
      level: 3,
      sectionColor: Color(0xFF58CC02),
      sectionIcon: Icons.headphones_rounded,
    );
  }
}
