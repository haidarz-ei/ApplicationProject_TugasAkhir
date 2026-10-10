import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/models/dictionary_entry.dart';

/// Repository untuk mengakses tabel dictionary di Supabase.
///
/// Semua query menggunakan anon key (read-only via RLS policy).
class DictionaryRepository {
  final SupabaseClient _client;

  /// Nama tabel di Supabase.
  static const String _tableName = 'dictionary';

  DictionaryRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Cari kata berdasarkan keyword (case-insensitive, partial match).
  ///
  /// Mengembalikan list entry yang word-nya mengandung [query].
  /// [limit] membatasi jumlah hasil (default 50).
  Future<List<DictionaryEntry>> searchWords(
    String query, {
    int limit = 50,
  }) async {
    final response = await _client
        .from(_tableName)
        .select()
        .ilike('word', '%$query%')
        .order('word')
        .limit(limit);

    return (response as List)
        .map((json) => DictionaryEntry.fromJson(json))
        .toList();
  }

  /// Ambil detail satu kata berdasarkan ID.
  Future<DictionaryEntry?> getWordById(int id) async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return DictionaryEntry.fromJson(response);
  }

  /// Ambil semua entry dengan POS tertentu (misal: "verb", "noun").
  ///
  /// [limit] membatasi jumlah hasil (default 100).
  /// [offset] untuk pagination.
  Future<List<DictionaryEntry>> getWordsByPos(
    String pos, {
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('pos', pos)
        .order('word')
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => DictionaryEntry.fromJson(json))
        .toList();
  }

  /// Cari kata berdasarkan keyword yang dimulai dengan [prefix].
  ///
  /// Cocok untuk autocomplete/search-as-you-type.
  Future<List<DictionaryEntry>> searchByPrefix(
    String prefix, {
    int limit = 20,
  }) async {
    final response = await _client
        .from(_tableName)
        .select()
        .ilike('word', '$prefix%')
        .order('word')
        .limit(limit);

    return (response as List)
        .map((json) => DictionaryEntry.fromJson(json))
        .toList();
  }

  /// Ambil kata secara exact match (case-insensitive).
  ///
  /// Bisa mengembalikan lebih dari 1 entry jika word yang sama
  /// memiliki POS berbeda (misal: "free" sebagai adj, adv, verb).
  Future<List<DictionaryEntry>> getExactWord(String word) async {
    final response = await _client
        .from(_tableName)
        .select()
        .ilike('word', word)
        .order('pos');

    return (response as List)
        .map((json) => DictionaryEntry.fromJson(json))
        .toList();
  }

  /// Hitung total entry di dictionary.
  Future<int> getTotalCount() async {
    final response = await _client
        .from(_tableName)
        .select('id')
        .count(CountOption.exact);

    return response.count;
  }

  /// Ambil daftar semua POS unik yang ada di dictionary.
  Future<List<String>> getUniquePosValues() async {
    final response = await _client
        .from(_tableName)
        .select('pos')
        .order('pos');

    final allPos = (response as List).map((r) => r['pos'] as String).toSet();
    return allPos.toList()..sort();
  }

  /// Query dengan pagination, search, dan multi-filter POS.
  ///
  /// [searchQuery] — keyword pencarian (partial match, case-insensitive).
  /// [posFilters] — list POS yang ingin ditampilkan (kosong = semua).
  /// [limit] — jumlah item per halaman.
  /// [offset] — offset untuk pagination.
  ///
  /// Mengembalikan `({List<DictionaryEntry> entries, int totalCount})`.
  Future<({List<DictionaryEntry> entries, int totalCount})> queryDictionary({
    String searchQuery = '',
    List<String> posFilters = const [],
    int limit = 100,
    int offset = 0,
  }) async {
    // Build base query for data
    var dataQuery = _client.from(_tableName).select();

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      dataQuery = dataQuery.ilike('word', '%$searchQuery%');
    }

    // Apply POS filter (multi-select)
    if (posFilters.isNotEmpty) {
      dataQuery = dataQuery.inFilter('pos', posFilters);
    }

    // Get paginated results
    final dataResponse = await dataQuery
        .order('word')
        .range(offset, offset + limit - 1);

    final entries = (dataResponse as List)
        .map((json) => DictionaryEntry.fromJson(json))
        .toList();

    // Build separate count query — filters before count
    var countQuery = _client.from(_tableName).select('id');

    if (searchQuery.isNotEmpty) {
      countQuery = countQuery.ilike('word', '%$searchQuery%');
    }

    if (posFilters.isNotEmpty) {
      countQuery = countQuery.inFilter('pos', posFilters);
    }

    final countResponse = await countQuery.count(CountOption.exact);
    final totalCount = countResponse.count;

    return (entries: entries, totalCount: totalCount);
  }

  /// Ambil satu kata acak secara online dari Supabase
  Future<DictionaryEntry?> getRandomWord({String? pos}) async {
    final words = await getRandomWords(pos: pos, count: 1);
    return words.isNotEmpty ? words.first : null;
  }

  /// Ambil beberapa kata acak untuk batch scheduling notifikasi
  Future<List<DictionaryEntry>> getRandomWords({String? pos, int count = 15}) async {
    try {
      var query = _client.from(_tableName).select();
      if (pos != null && pos != 'all') {
        query = query.eq('pos', pos);
      }
      final response = await query.limit(50);
      final list = (response as List).map((json) => DictionaryEntry.fromJson(json)).toList();
      if (list.isNotEmpty) {
        list.shuffle();
        return list.take(count).toList();
      }
    } catch (_) {}
    return [];
  }
}
