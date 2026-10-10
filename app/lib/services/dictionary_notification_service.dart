import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:app/data/database/app_database.dart';
import 'package:app/data/models/dictionary_entry.dart';
import 'package:app/data/repositories/dictionary_repository.dart';

/// Konfigurasi dan pengaturan notifikasi asupan kosakata kamus.
class WordReminderSettings {
  final bool isActive;
  final int dailyGoal; // 6, 12, 18, 24 Words
  final String frequency; // 'Every 30 Minutes', 'Every 1 Hour', 'Every 2 Hours', 'Every 3 Hours'
  final TimeOfDay startTime; // Jam mulai reminder, misal 07:00 AM
  final String selectedPos; // 'all', 'noun', 'verb', 'adj', 'adv', 'phrase'

  const WordReminderSettings({
    this.isActive = true,
    this.dailyGoal = 12,
    this.frequency = 'Every 1 Hour',
    this.startTime = const TimeOfDay(hour: 7, minute: 0),
    this.selectedPos = 'all',
  });

  WordReminderSettings copyWith({
    bool? isActive,
    int? dailyGoal,
    String? frequency,
    TimeOfDay? startTime,
    String? selectedPos,
  }) {
    return WordReminderSettings(
      isActive: isActive ?? this.isActive,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      frequency: frequency ?? this.frequency,
      startTime: startTime ?? this.startTime,
      selectedPos: selectedPos ?? this.selectedPos,
    );
  }
}

/// Service untuk mengatur notifikasi native (topbar/lockscreen/background)
/// dan dialog pop-up in-app untuk kosakata harian.
class DictionaryNotificationService {
  static final DictionaryNotificationService _instance =
      DictionaryNotificationService._internal();
  factory DictionaryNotificationService() => _instance;
  DictionaryNotificationService._internal();

  static const _kIsActive = 'word_reminder_is_active';
  static const _kDailyGoal = 'word_reminder_daily_goal';
  static const _kFrequency = 'word_reminder_frequency';
  static const _kStartHour = 'word_reminder_start_hour';
  static const _kStartMinute = 'word_reminder_start_minute';
  static const _kSelectedPos = 'word_reminder_selected_pos';

  static const String _kChannelId = 'word_feeder_channel';
  static const String _kChannelName = 'Daily Word Feeder';
  static const String _kChannelDesc =
      'Notifikasi pengingat kosakata harian dari kamus OnePath Lingua';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DictionaryRepository _repo = DictionaryRepository();
  final AppDatabase _db = AppDatabase();

  Timer? _scheduleTimer;
  bool _isInitialized = false;
  List<DictionaryEntry>? _pendingEntries;

  WordReminderSettings _settings = const WordReminderSettings();
  WordReminderSettings get settings => _settings;

  /// Global NavigatorKey untuk menampilkan popup notifikasi di mana pun user berada
  GlobalKey<NavigatorState>? navigatorKey;

  /// Durasi interval frekuensi notifikasi
  Duration get frequencyInterval {
    switch (_settings.frequency) {
      case 'Every 30 Minutes':
        return const Duration(minutes: 30);
      case 'Every 2 Hours':
        return const Duration(hours: 2);
      case 'Every 3 Hours':
        return const Duration(hours: 3);
      case 'Every 1 Hour':
      case 'Every Hour':
      default:
        return const Duration(hours: 1);
    }
  }

  /// Total sesi pengingat dalam 24 jam
  int get sessionsPerDay {
    final minutes = frequencyInterval.inMinutes;
    if (minutes <= 0) return 8;
    return (24 * 60 / minutes).round();
  }

  /// Jumlah kosakata yang dikirim per sesi notifikasi
  /// Contoh: Daily goal 24, Every 3 Hours (8 sesi per 24 jam) -> 24 / 8 = 3 kata per sesi!
  int get wordsPerSession {
    final sessions = sessionsPerDay;
    if (sessions <= 0) return 1;
    final count = (_settings.dailyGoal / sessions).round();
    return count < 1 ? 1 : count;
  }

  /// Inisialisasi plugin notifikasi native dan zona waktu
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Inisialisasi database timezone
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Error obtaining device timezone: $e');
    }

    // 2. Inisialisasi flutter_local_notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    // 3. Buat Notification Channel untuk Android (Prioritas Max agar muncul di lockscreen & top bar)
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: _kChannelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    // 4. Muat pengaturan dan jadwalkan notifikasi
    await loadSettings();
  }

  /// Meminta izin notifikasi dan alarm presisi (Android 13+ & iOS)
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
        return granted ?? true;
      }

      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  /// Memuat pengaturan feeder dari SQLite app_preferences
  Future<void> loadSettings() async {
    try {
      final isActive = await _db.getPreference(_kIsActive);
      final dailyGoal = await _db.getPreference(_kDailyGoal);
      final frequency = await _db.getPreference(_kFrequency);
      final startHour = await _db.getPreference(_kStartHour);
      final startMinute = await _db.getPreference(_kStartMinute);
      final selectedPos = await _db.getPreference(_kSelectedPos);

      if (isActive != null || dailyGoal != null) {
        _settings = WordReminderSettings(
          isActive: isActive != null ? isActive == 'true' : _settings.isActive,
          dailyGoal: dailyGoal != null
              ? int.tryParse(dailyGoal) ?? _settings.dailyGoal
              : _settings.dailyGoal,
          frequency: frequency ?? _settings.frequency,
          startTime: TimeOfDay(
            hour: startHour != null
                ? int.tryParse(startHour) ?? _settings.startTime.hour
                : _settings.startTime.hour,
            minute: startMinute != null
                ? int.tryParse(startMinute) ?? _settings.startTime.minute
                : _settings.startTime.minute,
          ),
          selectedPos: selectedPos ?? _settings.selectedPos,
        );
      }

      _rescheduleInAppTimer();
      await scheduleNativeNotifications();
    } catch (e) {
      debugPrint('Error loading reminder settings: $e');
    }
  }

  /// Update pengaturan notifikasi dan simpan permanen ke SQLite
  Future<void> updateSettings(WordReminderSettings newSettings) async {
    _settings = newSettings;
    _rescheduleInAppTimer();
    await scheduleNativeNotifications();

    try {
      await _db.setPreference(_kIsActive, newSettings.isActive.toString());
      await _db.setPreference(_kDailyGoal, newSettings.dailyGoal.toString());
      await _db.setPreference(_kFrequency, newSettings.frequency);
      await _db.setPreference(
          _kStartHour, newSettings.startTime.hour.toString());
      await _db.setPreference(
          _kStartMinute, newSettings.startTime.minute.toString());
      await _db.setPreference(_kSelectedPos, newSettings.selectedPos);
    } catch (e) {
      debugPrint('Error saving reminder settings: $e');
    }
  }

  /// Menjadwalkan alarm notifikasi native di sistem OS (berjalan saat aplikasi ditutup/lockscreen)
  Future<void> scheduleNativeNotifications() async {
    if (kIsWeb) return;

    try {
      // Bersihkan alarm notifikasi terjadwal sebelumnya
      await _localNotifications.cancelAll();

      if (!_settings.isActive) return;

      final batchPerSession = wordsPerSession;
      final totalSlots = 14;
      final totalWordsNeeded = batchPerSession * totalSlots;

      // Ambil batch kosakata dari Supabase atau fallback
      List<DictionaryEntry> wordPool = await _repo.getRandomWords(
        pos: _settings.selectedPos,
        count: totalWordsNeeded > 50 ? 50 : totalWordsNeeded,
      );

      if (wordPool.isEmpty) {
        final filteredFallback = _fallbackWords
            .where((e) => _settings.selectedPos == 'all' || e.pos == _settings.selectedPos)
            .toList();
        wordPool = filteredFallback.isNotEmpty ? filteredFallback : _fallbackWords;
      }

      final interval = frequencyInterval;
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        _settings.startTime.hour,
        _settings.startTime.minute,
      );

      // Jika waktu mulai hari ini sudah terlewat, cari slot waktu berikutnya
      while (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(interval);
      }

      // Jadwalkan 14 slot sesi notifikasi ke depan ke dalam Alarm Manager OS
      for (int slot = 0; slot < totalSlots; slot++) {
        final slotTime = scheduledTime.add(interval * slot);

        final List<DictionaryEntry> sessionWords = [];
        for (int w = 0; w < batchPerSession; w++) {
          final idx = (slot * batchPerSession + w) % wordPool.length;
          sessionWords.add(wordPool[idx]);
        }

        final notificationDetails = _buildNotificationDetails(sessionWords);
        final title = _buildNotificationTitle(sessionWords);
        final body = _buildNotificationShortBody(sessionWords);

        await _localNotifications.zonedSchedule(
          id: 100 + slot,
          title: title,
          body: body,
          scheduledDate: slotTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: jsonEncode(sessionWords.map((e) => e.toJson()).toList()),
        );
      }

      debugPrint(
          'Scheduled $totalSlots native sessions ($batchPerSession words/session) starting at $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling native notifications: $e');
    }
  }

  /// Menampilkan notifikasi native secara instan di top bar / lock screen untuk pengujian
  Future<void> showInstantNativeNotification(
      [List<DictionaryEntry>? customEntries]) async {
    if (kIsWeb) return;

    try {
      List<DictionaryEntry> entries = customEntries ?? [];
      if (entries.isEmpty) {
        final needed = wordsPerSession;
        final fetched = await _repo.getRandomWords(
          pos: _settings.selectedPos,
          count: needed,
        );

        if (fetched.isNotEmpty) {
          entries = fetched;
        } else {
          final filteredFallback = _fallbackWords
              .where((e) => _settings.selectedPos == 'all' || e.pos == _settings.selectedPos)
              .toList();
          entries = (filteredFallback.isNotEmpty ? filteredFallback : _fallbackWords)
              .take(needed)
              .toList();
        }
      }

      final details = _buildNotificationDetails(entries);
      final title = _buildNotificationTitle(entries);
      final body = _buildNotificationShortBody(entries);

      await _localNotifications.show(
        id: 999,
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  String _buildNotificationTitle(List<DictionaryEntry> entries) {
    final hasOnlyVerbs = entries.every((e) => e.isVerb);
    if (hasOnlyVerbs) {
      if (entries.length == 1) {
        return 'OnePath Lingua • Verb (${entries.first.verbForms})';
      }
      return 'OnePath Lingua • ${entries.length} Verbs (${entries.length * 3} Kata: V1, V2, V3)';
    }

    if (entries.length == 1) {
      final entry = entries.first;
      return 'OnePath Lingua • ${entry.word} (${entry.pos.toUpperCase()})';
    }
    return 'OnePath Lingua • ${entries.length} Daily Vocabularies';
  }

  String _buildNotificationShortBody(List<DictionaryEntry> entries) {
    if (entries.every((e) => e.isVerb)) {
      return entries.map((e) => e.verbForms).join('  |  ');
    }
    if (entries.length == 1) {
      final entry = entries.first;
      return entry.definitionId.isNotEmpty
          ? entry.definitionId
          : entry.definitionEn;
    }
    return entries.map((e) => '${e.word} (${e.pos})').join(' • ');
  }

  NotificationDetails _buildNotificationDetails(List<DictionaryEntry> entries) {
    String bigText;
    final isVerbGroup = entries.every((e) => e.isVerb);

    if (isVerbGroup) {
      bigText = entries.asMap().entries.map((item) {
        final i = item.key + 1;
        final e = item.value;
        final meaning = e.definitionId.isNotEmpty ? e.definitionId : e.definitionEn;
        return '$i. ${e.verbForms} (VERB)\n   Artinya: $meaning';
      }).join('\n\n');
    } else if (entries.length == 1) {
      final entry = entries.first;
      final formText = entry.isVerb ? 'Forms: ${entry.verbForms}\n' : '';
      bigText = entry.definitionId.isNotEmpty && entry.definitionEn.isNotEmpty
          ? '$formText${entry.definitionEn}\nArtinya: ${entry.definitionId}'
          : '$formText${entry.definitionEn.isNotEmpty ? entry.definitionEn : entry.definitionId}';
    } else {
      bigText = entries.asMap().entries.map((item) {
        final i = item.key + 1;
        final e = item.value;
        final formText = e.isVerb ? '(${e.verbForms}) ' : '';
        final meaning = e.definitionId.isNotEmpty ? e.definitionId : e.definitionEn;
        return '$i. ${e.word} (${e.pos.toUpperCase()}) $formText\n   $meaning';
      }).join('\n\n');
    }

    final title = _buildNotificationTitle(entries);

    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public, // Tampil di Lock Screen
      ticker: 'Daily Word Feeder',
      styleInformation: BigTextStyleInformation(
        bigText,
        contentTitle: title,
        summaryText: isVerbGroup
            ? '${entries.length} Verbs (${entries.length * 3} Kata)'
            : '${entries.length} Kosakata Siap Dipelajari',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      List<DictionaryEntry> entries = [];
      if (decoded is List) {
        entries = decoded
            .map((item) => DictionaryEntry.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (decoded is Map<String, dynamic>) {
        entries = [DictionaryEntry.fromJson(decoded)];
      }

      if (entries.isEmpty) return;

      final context = navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        showWordsNotificationDialog(context, entries);
      } else {
        _pendingEntries = entries;
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Cek jika ada notifikasi yang di-tap saat aplikasi baru dibuka
  void checkPendingNotification() {
    if (_pendingEntries != null && _pendingEntries!.isNotEmpty) {
      final context = navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        final entries = _pendingEntries!;
        _pendingEntries = null;
        Future.microtask(() {
          if (context.mounted) {
            showWordsNotificationDialog(context, entries);
          }
        });
      }
    }
  }

  /// Format waktu menjadi string yang rapi, contoh "07:00 AM"
  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Hitung delay waktu hingga jam Start Time berikutnya (untuk in-app Timer)
  Duration calculateDelayUntilStartTime() {
    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      _settings.startTime.hour,
      _settings.startTime.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled.difference(now);
  }

  void _rescheduleInAppTimer() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;

    if (!_settings.isActive) return;

    final initialDelay = calculateDelayUntilStartTime();
    _scheduleTimer = Timer(initialDelay, () {
      triggerWordFeed();
      final interval = frequencyInterval;
      _scheduleTimer = Timer.periodic(interval, (_) => triggerWordFeed());
    });
  }

  /// Mengambil daftar kata acak langsung dari Supabase
  Future<List<DictionaryEntry>> fetchRandomWords({int? count}) async {
    final needed = count ?? wordsPerSession;
    try {
      final words = await _repo.getRandomWords(
        pos: _settings.selectedPos,
        count: needed,
      );
      if (words.isNotEmpty) return words;
    } catch (e) {
      debugPrint('Error fetching random words for reminder: $e');
    }
    final filteredFallback = _fallbackWords
        .where((e) => _settings.selectedPos == 'all' || e.pos == _settings.selectedPos)
        .toList();
    return (filteredFallback.isNotEmpty ? filteredFallback : _fallbackWords)
        .take(needed)
        .toList();
  }

  /// Memicu pengambilan kata dan menampilkan notifikasi pop-up jika aplikasi sedang terbuka
  Future<List<DictionaryEntry>> triggerWordFeed({BuildContext? context}) async {
    final entries = await fetchRandomWords();
    if (entries.isEmpty) return [];

    final targetContext = context ?? navigatorKey?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      showWordsNotificationDialog(targetContext, entries);
    }

    // Pemicu notifikasi native status bar
    showInstantNativeNotification(entries);

    return entries;
  }

  /// Menampilkan dialog notifikasi kata di dalam aplikasi (bisa 1 atau banyak kata)
  void showWordsNotificationDialog(
      BuildContext context, List<DictionaryEntry> entries) {
    if (entries.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: Color(0xFF6B4EFF), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entries.every((e) => e.isVerb)
                        ? 'Verb Feeder (${entries.length} Verbs • ${entries.length * 3} Kata)'
                        : (entries.length == 1
                            ? 'Daily Word Feeder'
                            : 'Daily Word Feeder (${entries.length} Words)'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Target: ${_settings.dailyGoal} kata • Frekuensi: ${_settings.frequency}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: entries.map((entry) => _buildWordCard(entry)).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(DictionaryEntry entry) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9F5FF), Color(0xFFF3E8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.word,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF581C87),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4EFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.pos.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (entry.isVerb) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '3 Bentuk: ${entry.verbForms}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4EFF)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            entry.definitionEn.isNotEmpty
                ? entry.definitionEn
                : entry.definitionId,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF374151), height: 1.35),
          ),
          if (entry.definitionId.isNotEmpty &&
              entry.definitionEn.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Artinya: ${entry.definitionId}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  static const List<DictionaryEntry> _fallbackWords = [
    DictionaryEntry(
      id: 101,
      word: 'speak',
      pos: 'verb',
      v1: 'speak',
      v2: 'spoke',
      v3: 'spoken',
      definitionEn: 'Say words in order to convey information.',
      definitionId: 'Berbicara atau bertutur kata.',
    ),
    DictionaryEntry(
      id: 102,
      word: 'write',
      pos: 'verb',
      v1: 'write',
      v2: 'wrote',
      v3: 'written',
      definitionEn: 'Mark letters or words on a surface.',
      definitionId: 'Menulis catatan atau ide.',
    ),
    DictionaryEntry(
      id: 103,
      word: 'take',
      pos: 'verb',
      v1: 'take',
      v2: 'took',
      v3: 'taken',
      definitionEn: 'Lay hold of something with hands or reach for.',
      definitionId: 'Mengambil atau memegang.',
    ),
    DictionaryEntry(
      id: 1,
      word: 'Resilience',
      pos: 'noun',
      definitionEn: 'The capacity to recover quickly from difficulties.',
      definitionId: 'Kemampuan untuk pulih dengan cepat dari kesulitan.',
    ),
    DictionaryEntry(
      id: 2,
      word: 'Eloquent',
      pos: 'adj',
      definitionEn: 'Fluent or persuasive in speaking or writing.',
      definitionId: 'Fasih, pandai berbicara, atau meyakinkan dalam bertutur.',
    ),
  ];
}
