import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/models/journal_entry.dart';
import 'package:app/data/database/app_database.dart';

/// Repository untuk CRUD tabel journals di Supabase dengan SQLite offline cache.
class JournalRepository {
  final SupabaseClient _client;
  final AppDatabase _localDb = AppDatabase();

  static const String _tableName = 'journals';

  JournalRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _effectiveUserId {
    return _client.auth.currentUser?.id ?? 'local_user';
  }

  /// Ambil semua journal milik user aktif, urut terbaru dulu.
  /// Membaca dari Supabase jika online dan menyimpan cache ke SQLite.
  /// Jika offline / Supabase gagal, membaca langsung dari SQLite local_journals.
  Future<List<JournalEntry>> getAll() async {
    final userId = _effectiveUserId;
    try {
      var query = _client.from(_tableName).select();
      if (_client.auth.currentUser?.id != null) {
        query = query.eq('user_id', _client.auth.currentUser!.id);
      }
      final response = await query.order('created_at', ascending: false);

      final list = (response as List)
          .map((json) => JournalEntry.fromJson(Map<dynamic, dynamic>.from(json as Map)))
          .toList();

      for (final j in list) {
        await _localDb.saveLocalJournal(
          userId: userId,
          title: j.title,
          story: j.story,
          imageUrl: j.imageUrl,
          remoteId: j.id,
          isSynced: true,
        );
      }
      return list;
    } catch (_) {
      // Fallback: baca dari SQLite lokal
      final localList = await _localDb.getLocalJournals(userId);
      return localList.map((m) => JournalEntry.fromJson(m)).toList();
    }
  }

  /// Ambil satu journal berdasarkan ID.
  Future<JournalEntry?> getById(int id) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        return JournalEntry.fromJson(Map<dynamic, dynamic>.from(response));
      }
    } catch (_) {}

    // Fallback SQLite lokal
    final localList = await _localDb.getLocalJournals(_effectiveUserId);
    final match = localList.where((m) => m['id'] == id || m['remote_id'] == id);
    if (match.isNotEmpty) {
      return JournalEntry.fromJson(match.first);
    }
    return null;
  }

  /// Buat journal baru.
  /// Sesuai Sequence_Diagram_AddJournal:
  /// - Online: INSERT ke Supabase -> saveLocalJournal(remoteId, isSynced: true)
  /// - Offline/Error: saveLocalJournal(isSynced: false) -> return JournalEntry(isSynced: false)
  Future<JournalEntry> create({
    required String title,
    required String story,
    String imageUrl = '',
  }) async {
    final userId = _effectiveUserId;
    final isOnlineAuth = _client.auth.currentUser != null;

    if (isOnlineAuth) {
      try {
        final payload = <String, dynamic>{
          'user_id': _client.auth.currentUser!.id,
          'title': title,
          'story': story,
          'image_url': imageUrl,
        };

        final response = await _client
            .from(_tableName)
            .insert(payload)
            .select()
            .single();

        final created = JournalEntry.fromJson(Map<dynamic, dynamic>.from(response));
        final localId = await _localDb.saveLocalJournal(
          userId: userId,
          title: created.title,
          story: created.story,
          imageUrl: created.imageUrl,
          remoteId: created.id,
          isSynced: true,
        );

        return JournalEntry(
          id: localId,
          remoteId: created.id,
          title: created.title,
          story: created.story,
          imageUrl: created.imageUrl,
          createdAt: created.createdAt,
          isSynced: true,
        );
      } catch (_) {
        // Fallback offline queue
      }
    }

    // Alur offline: simpan ke SQLite dengan is_synced = 0
    final localId = await _localDb.saveLocalJournal(
      userId: userId,
      title: title,
      story: story,
      imageUrl: imageUrl,
      isSynced: false,
    );

    return JournalEntry(
      id: localId,
      title: title,
      story: story,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isSynced: false,
    );
  }

  /// Sinkronkan entri jurnal lokal yang belum tersimpan di cloud (is_synced = 0)
  Future<int> syncUnsyncedJournals() async {
    final curUser = _client.auth.currentUser;
    if (curUser == null) return 0;

    int syncedCount = 0;
    try {
      final unsynced = await _localDb.getUnsyncedJournals(_effectiveUserId);
      for (final item in unsynced) {
        final localId = item['id'] as int;
        final title = item['title']?.toString() ?? '';
        final story = item['story']?.toString() ?? '';
        final imageUrl = item['image_url']?.toString() ?? '';

        final response = await _client.from(_tableName).insert({
          'user_id': curUser.id,
          'title': title,
          'story': story,
          'image_url': imageUrl,
        }).select().single();

        final remoteId = response['id'] as int;
        await _localDb.markJournalSynced(localId: localId, remoteId: remoteId);
        syncedCount++;
      }
    } catch (_) {}
    return syncedCount;
  }

  /// Update journal yang sudah ada.
  Future<JournalEntry> update({
    required int id,
    required String title,
    required String story,
    String imageUrl = '',
  }) async {
    try {
      final response = await _client
          .from(_tableName)
          .update({
            'title': title,
            'story': story,
            'image_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      return JournalEntry.fromJson(Map<dynamic, dynamic>.from(response));
    } catch (_) {
      // Perbarui juga data di SQLite lokal
      await _localDb.saveLocalJournal(
        userId: _effectiveUserId,
        title: title,
        story: story,
        imageUrl: imageUrl,
        remoteId: id,
        isSynced: false,
      );
      return JournalEntry(
        id: id,
        remoteId: id,
        title: title,
        story: story,
        imageUrl: imageUrl,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
    }
  }

  /// Hapus journal berdasarkan ID (baik lokal maupun remote).
  Future<void> delete(int id) async {
    try {
      await _client.from(_tableName).delete().eq('id', id);
    } catch (_) {}
    await _localDb.deleteLocalJournal(id);
  }
}
