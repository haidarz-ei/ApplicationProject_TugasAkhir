import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/database/app_database.dart';
import 'package:app/features/main_navigation.dart';
import 'package:app/features/auth/auth_page.dart';

/// Halaman pembuka (Splash Screen) berdurasi ~1 detik:
/// Memuat SQLite lokal, membaca status sesi login, dan bertransisi mulus ke Beranda / Login.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Inisialisasi & buka database SQLite lokal
    await AppDatabase().database;

    // 2. Durasi minimal splash screen (1 detik) agar branding tampil mulus
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // 3. Periksa status sesi login yang tersimpan di HP
    final session = Supabase.instance.client.auth.currentSession;

    // 4. Arahkan pengguna dengan transisi fade halus
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            session != null ? const MainNavigation() : const AuthPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo Aplikasi
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/logoAplikasi.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Nama Aplikasi
              const Text(
                'OnePath Lingua',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              // Tagline
              const Text(
                'Master English Naturally',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Loading Indicator Halus
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF6B4EFF),
                ),
              ),
              const SizedBox(height: 24),
              // Versi Aplikasi
              const Text(
                'v 1.0.0',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
