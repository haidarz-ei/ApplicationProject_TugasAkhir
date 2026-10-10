import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/core/constants/supabase_config.dart';
import 'package:app/features/auth/auth_page.dart';
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:app/data/models/dictionary_entry.dart';
import 'package:flutter/services.dart';
import 'package:app/services/dictionary_notification_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
    } catch (_) {}
  });

  group('Auth & Smoke Tests', () {
    testWidgets('AuthPage smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi branding OnePath Lingua, tombol Sign In, dan Continue with Google
      expect(find.text('OnePath Lingua'), findsOneWidget);
      expect(find.text('Sign In'), findsNWidgets(2)); // Tab toggle dan submit button
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('Data Models & Architecture Audit', () {
    test('DictionaryEntry fromJson parsing test', () {
      final json = {
        'id': 101,
        'word': 'resilient',
        'pos': 'adj',
        'definition_en': 'Able to withstand or recover quickly from difficult conditions.',
        'definition_id': 'Mampu pulih dengan cepat dari kondisi sulit.',
        'v1': '',
        'v2': '',
        'v3': '',
      };

      final entry = DictionaryEntry.fromJson(json);
      expect(entry.id, 101);
      expect(entry.word, 'resilient');
      expect(entry.pos, 'adj');
      expect(entry.isVerb, false);
      expect(entry.definitionEn, contains('withstand'));
    });

    test('WordReminderSettings default and copyWith test', () {
      const settings = WordReminderSettings();
      expect(settings.isActive, true);
      expect(settings.dailyGoal, 12);
      expect(settings.frequency, 'Every 1 Hour');
      expect(settings.startTime.hour, 7);

      final updated = settings.copyWith(
        dailyGoal: 24,
        frequency: 'Every 3 Hours',
        selectedPos: 'verb',
      );
      expect(updated.dailyGoal, 24);
      expect(updated.frequency, 'Every 3 Hours');
      expect(updated.selectedPos, 'verb');
    });

    test('SectionsNotifier initial 6 learning phases test', () {
      final container = ProviderContainer();
      final sections = container.read(sectionsProvider);

      expect(sections.length, 6);
      expect(sections[0].title, 'Newborn');
      expect(sections[1].title, 'Listener');
      expect(sections[2].title, 'Speaker');
      expect(sections[3].title, 'Builder');
      expect(sections[4].title, 'Converser');
      expect(sections[5].title, 'Native Mind');
    });
  });
}
