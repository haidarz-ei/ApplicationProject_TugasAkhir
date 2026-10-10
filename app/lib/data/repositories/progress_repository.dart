import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/models/progress_model.dart';
import 'package:app/data/database/app_database.dart';

/// Repository untuk mengelola tabel progress di Supabase dengan SQLite local cache.
class ProgressRepository {
  final SupabaseClient _client;
  final AppDatabase _localDb = AppDatabase();
  static const String _tableName = 'progress';

  ProgressRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Ambil seluruh progres user di semua section & phase.
  Future<List<ProgressModel>> getProgress(String userId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId);

      final list = (response as List)
          .map((json) => ProgressModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      for (final p in list) {
        await _localDb.saveProgressCache(
          userId: p.userId,
          section: p.section,
          phase: p.phase,
          level: p.level,
        );
      }
      return list;
    } catch (_) {
      final cached = await _localDb.getAllCachedProgress(userId);
      return cached.map((json) => ProgressModel.fromJson(json)).toList();
    }
  }

  /// Update atau simpan progres (upsert berdasarkan unique constraint user_id, section, phase).
  Future<void> updateProgress(
    String userId,
    String section,
    String phase,
    int level,
  ) async {
    await _localDb.saveProgressCache(
      userId: userId,
      section: section,
      phase: phase,
      level: level,
    );

    try {
      await _client.from(_tableName).upsert(
        {
          'user_id': userId,
          'section': section,
          'phase': phase,
          'level': level,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,section,phase',
      );
    } catch (_) {
      // Offline: Progress tersimpan aman di snapshot SQLite lokal
    }
  }

  /// Dapatkan level terakhir yang dicapai user pada section & phase tertentu.
  Future<int> getLastLevel(String userId, String section, String phase) async {
    final cached = await _localDb.getCachedLevel(
      userId: userId,
      section: section,
      phase: phase,
    );

    try {
      final response = await _client
          .from(_tableName)
          .select('level')
          .eq('user_id', userId)
          .eq('section', section)
          .eq('phase', phase)
          .maybeSingle();

      if (response == null) return cached ?? 0;
      final lvl = (response['level'] as num?)?.toInt() ?? 0;
      await _localDb.saveProgressCache(
        userId: userId,
        section: section,
        phase: phase,
        level: lvl,
      );
      return lvl;
    } catch (_) {
      return cached ?? 0;
    }
  }

  /// Reset seluruh progres user (hapus dari Supabase dan SQLite cache lokal)
  Future<void> resetAllProgress(String userId) async {
    await _localDb.clearProgressCache(userId);
    try {
      await _client.from(_tableName).delete().eq('user_id', userId);
    } catch (e) {
      // Offline fallback: SQLite cache sudah bersih
    }
  }
}
