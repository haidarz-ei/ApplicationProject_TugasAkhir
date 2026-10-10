import 'package:flutter/material.dart';

/// Halaman peringatan Coming Soon untuk Level Phase yang materinya belum tersedia
class PhaseComingSoonPage extends StatelessWidget {
  final String title;
  final String topicTitle;
  final int level;
  final Color sectionColor;
  final IconData? sectionIcon;

  const PhaseComingSoonPage({
    super.key,
    required this.title,
    required this.topicTitle,
    required this.level,
    required this.sectionColor,
    this.sectionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF3C3C3C),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                if (sectionIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(sectionIcon, color: sectionColor, size: 24),
                ],
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C3C3C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // Icon Container
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sectionColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: sectionColor.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    size: 52,
                    color: sectionColor,
                  ),
                ),
              ),
              SizedBox(height: 24),
              // Level Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFFFFC800).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFFFC800), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$topicTitle • Level $level',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // Notice Title
              Text(
                'Fitur & Materi Baru Segera Hadir!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D3748),
                ),
              ),
              SizedBox(height: 12),
              // Notice Description
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Fitur dan materi baru untuk level ini sedang dalam tahap pengembangan dan akan segera hadir. Nantikan pembaruan berikutnya!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF718096),
                  ),
                ),
              ),
              const Spacer(),
              // Tombol Kembali
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sectionColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'KEMBALI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
