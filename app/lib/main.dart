import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/core/constants/supabase_config.dart';
import 'package:app/features/splash/splash_page.dart';
import 'package:app/services/dictionary_notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase sebelum runApp jika konfigurasi valid
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase offline / initialization skipped: $e');
  }

  // Inisialisasi notifikasi native & pengaturan reminder dari penyimpanan lokal HP
  final notifService = DictionaryNotificationService();
  notifService.navigatorKey = appNavigatorKey;
  await notifService.initialize();

  // ProviderScope membungkus seluruh aplikasi agar Riverpod bisa bekerja
  runApp(const ProviderScope(child: SmartVocabularyApp()));
}

class SmartVocabularyApp extends StatelessWidget {
  const SmartVocabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'OnePath Lingua',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF), // Warna ungu utama
          surface: const Color(0xFFF9F9F9), // Latar sedikit krem/abu terang
        ),
        useMaterial3: true,
        fontFamily: 'Nunito', // Menggunakan font bawaan untuk sementara yang mendekati desain
      ),
      home: const SplashPage(),
    );
  }
}
