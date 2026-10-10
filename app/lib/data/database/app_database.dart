import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database lokal SQLite untuk caching dan offline storage di OnePath Lingua.
/// Disederhanakan untuk hanya menampung 3 data esensial:
/// 1. progress_cache (Snapshot progres kurikulum)
/// 2. local_journals (Catatan buku dan jurnal pengguna)
/// 3. app_preferences (Pengaturan ringan Key-Value: suara, pengingat, dll.)
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static const String _dbName = 'onepath_lingua.db';
  static const int _dbVersion = 2;

  Database? _db;

  // In-memory mock storage khusus platform Web
  final Map<String, List<Map<String, dynamic>>> _webStorage = {
    'progress_cache': [],
    'local_journals': [],
    'app_preferences': [],
  };

  /// Inisialisasi atau dapatkan instance database aktif
  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Snapshot Progres Belajar (Curriculum Snapshot)
    await db.execute('''
      CREATE TABLE progress_cache (
        user_id TEXT NOT NULL,
        section TEXT NOT NULL,
        phase TEXT NOT NULL,
        level INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, section, phase)
      )
    ''');

    // 2. Jurnal Pengguna (Local User Journals)
    await db.execute('''
      CREATE TABLE local_journals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        story TEXT NOT NULL,
        image_url TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 3. Preferensi Ringan Aplikasi (Key-Value Store)
    await db.execute('''
      CREATE TABLE app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Hapus tabel lama yang tidak dipakai
      await db.execute('DROP TABLE IF EXISTS offline_sync_queue');
      await db.execute('DROP TABLE IF EXISTS reminder_word_cache');
      await db.execute('DROP TABLE IF EXISTS cached_journals');

      // Buat ulang tabel local_journals & app_preferences jika belum ada
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_journals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id INTEGER,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          story TEXT NOT NULL,
          image_url TEXT,
          created_at TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_preferences (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  // ===========================================================================
  // 1. PROGRES BELAJAR (SNAPSHOT PROGRESS CACHE)
  // ===========================================================================

  /// Simpan atau perbarui snapshot progres di SQLite
  Future<void> saveProgressCache({
    required String userId,
    required String section,
    required String phase,
    required int level,
  }) async {
    final now = DateTime.now().toIso8601String();
    final row = {
      'user_id': userId,
      'section': section,
      'phase': phase,
      'level': level,
      'updated_at': now,
    };

    if (kIsWeb) {
      final list = _webStorage['progress_cache']!;
      list.removeWhere((e) =>
          e['user_id'] == userId &&
          e['section'] == section &&
          e['phase'] == phase);
      list.add(row);
      return;
    }

    final db = await database;
    await db?.insert(
      'progress_cache',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Dapatkan level terakhir dari snapshot lokal
  Future<int?> getCachedLevel({
    required String userId,
    required String section,
    required String phase,
  }) async {
    if (kIsWeb) {
      final list = _webStorage['progress_cache']!;
      final match = list.cast<Map<String, dynamic>?>().firstWhere(
            (e) =>
                e?['user_id'] == userId &&
                e?['section'] == section &&
                e?['phase'] == phase,
            orElse: () => null,
          );
      return match != null ? match['level'] as int : null;
    }

    final db = await database;
    final res = await db?.query(
      'progress_cache',
      columns: ['level'],
      where: 'user_id = ? AND section = ? AND phase = ?',
      whereArgs: [userId, section, phase],
      limit: 1,
    );

    if (res != null && res.isNotEmpty) {
      return res.first['level'] as int;
    }
    return null;
  }

  /// Ambil seluruh progres user dari snapshot lokal
  Future<List<Map<String, dynamic>>> getAllCachedProgress(String userId) async {
    if (kIsWeb) {
      return _webStorage['progress_cache']!
          .where((e) => e['user_id'] == userId)
          .toList();
    }

    final db = await database;
    final res = await db?.query(
      'progress_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return res ?? [];
  }

  /// Hapus seluruh snapshot progres untuk user tertentu
  Future<void> clearProgressCache(String userId) async {
    if (kIsWeb) {
      _webStorage['progress_cache']!.removeWhere((e) => e['user_id'] == userId);
      return;
    }

    final db = await database;
    await db?.delete(
      'progress_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ===========================================================================
  // 2. JURNAL PENGGUNA (LOCAL USER JOURNALS)
  // ===========================================================================

  /// Simpan atau buat jurnal di SQLite
  Future<int> saveLocalJournal({
    required String userId,
    required String title,
    required String story,
    String imageUrl = '',
    int? remoteId,
    bool isSynced = true,
  }) async {
    final row = {
      'remote_id': remoteId,
      'user_id': userId,
      'title': title,
      'story': story,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };

    if (kIsWeb) {
      row['id'] = DateTime.now().millisecondsSinceEpoch;
      _webStorage['local_journals']!.insert(0, row);
      return row['id'] as int;
    }

    final db = await database;
    return await db?.insert('local_journals', row, conflictAlgorithm: ConflictAlgorithm.replace) ?? 0;
  }

  /// Ambil semua jurnal milik user dari SQLite
  Future<List<Map<String, dynamic>>> getLocalJournals(String userId) async {
    if (kIsWeb) {
      return _webStorage['local_journals']!
          .where((e) => e['user_id'] == userId)
          .toList();
    }

    final db = await database;
    final res = await db?.query(
      'local_journals',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return res ?? [];
  }

  /// Hapus jurnal dari SQLite berdasarkan ID
  Future<void> deleteLocalJournal(int id) async {
    if (kIsWeb) {
      _webStorage['local_journals']!.removeWhere((e) => e['id'] == id);
      return;
    }

    final db = await database;
    await db?.delete('local_journals', where: 'id = ?', whereArgs: [id]);
  }

  /// Ambil jurnal yang belum disinkronkan ke cloud (is_synced = 0)
  Future<List<Map<String, dynamic>>> getUnsyncedJournals(String userId) async {
    if (kIsWeb) {
      return _webStorage['local_journals']!
          .where((e) => e['user_id'] == userId && e['is_synced'] == 0)
          .toList();
    }

    final db = await database;
    final res = await db?.query(
      'local_journals',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return res ?? [];
  }

  /// Tandai jurnal lokal sudah disinkronkan ke Supabase dengan remoteId
  Future<void> markJournalSynced({required int localId, required int remoteId}) async {
    if (kIsWeb) {
      final list = _webStorage['local_journals']!;
      for (final item in list) {
        if (item['id'] == localId) {
          item['remote_id'] = remoteId;
          item['is_synced'] = 1;
        }
      }
      return;
    }

    final db = await database;
    await db?.update(
      'local_journals',
      {'remote_id': remoteId, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ===========================================================================
  // 3. PREFERENSI RINGAN APLIKASI (KEY-VALUE APP PREFERENCES)
  // ===========================================================================

  /// Simpan atau perbarui nilai pengaturan (string/JSON)
  Future<void> setPreference(String key, String value) async {
    if (kIsWeb) {
      final list = _webStorage['app_preferences']!;
      list.removeWhere((e) => e['key'] == key);
      list.add({'key': key, 'value': value});
      return;
    }

    final db = await database;
    await db?.insert(
      'app_preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil nilai pengaturan berdasarkan kuncinya
  Future<String?> getPreference(String key) async {
    if (kIsWeb) {
      final list = _webStorage['app_preferences']!;
      final match = list.cast<Map<String, dynamic>?>().firstWhere(
            (e) => e?['key'] == key,
            orElse: () => null,
          );
      return match?['value'] as String?;
    }

    final db = await database;
    final res = await db?.query(
      'app_preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (res != null && res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  /// Hapus satu pengaturan dari SQLite
  Future<void> deletePreference(String key) async {
    if (kIsWeb) {
      _webStorage['app_preferences']!.removeWhere((e) => e['key'] == key);
      return;
    }

    final db = await database;
    await db?.delete('app_preferences', where: 'key = ?', whereArgs: [key]);
  }

  /// Ambil seluruh pengaturan yang tersimpan
  Future<Map<String, String>> getAllPreferences() async {
    if (kIsWeb) {
      final map = <String, String>{};
      for (final e in _webStorage['app_preferences']!) {
        map[e['key'] as String] = e['value'] as String;
      }
      return map;
    }

    final db = await database;
    final res = await db?.query('app_preferences');
    final map = <String, String>{};
    if (res != null) {
      for (final row in res) {
        map[row['key'] as String] = row['value'] as String;
      }
    }
    return map;
  }
}
