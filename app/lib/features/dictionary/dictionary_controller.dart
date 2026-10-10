import 'package:flutter/foundation.dart';
import 'package:app/data/models/dictionary_entry.dart';
import 'package:app/data/repositories/dictionary_repository.dart';

/// Controller layer untuk Kamus sesuai perancangan sistem
/// (sequence_diagram_kamus.drawio: Boundary -> Control -> Entity).
class DictionaryController extends ChangeNotifier {
  final DictionaryRepository _repository;

  DictionaryController({DictionaryRepository? repository})
      : _repository = repository ?? DictionaryRepository();

  static const int pageSize = 100;

  List<DictionaryEntry> _entries = [];
  List<String> _availablePos = [];
  final Set<String> _selectedPos = {};
  int _totalCount = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isPosLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  List<DictionaryEntry> get entries => _entries;
  List<String> get availablePos => _availablePos;
  Set<String> get selectedPos => _selectedPos;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  bool get isPosLoading => _isPosLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;
  int get totalPages => (_totalCount / pageSize).ceil().clamp(1, 999999);

  /// Memuat daftar Part of Speech (POS) yang tersedia di database
  Future<void> loadPosValues() async {
    _isPosLoading = true;
    notifyListeners();
    try {
      _availablePos = await _repository.getUniquePosValues();
    } catch (_) {
      // Ignore or empty
    } finally {
      _isPosLoading = false;
      notifyListeners();
    }
  }

  /// Alur utama cari kata (keyword, filter, page) sesuai Sequence Diagram Kamus
  Future<void> cariKata({
    String? keyword,
    Set<String>? filters,
    int? page,
  }) async {
    if (keyword != null) _searchQuery = keyword.trim();
    if (filters != null) {
      _selectedPos.clear();
      _selectedPos.addAll(filters);
    }
    if (page != null) _currentPage = page;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final offset = (_currentPage - 1) * pageSize;
      final result = await _repository.queryDictionary(
        searchQuery: _searchQuery,
        posFilters: _selectedPos.toList(),
        limit: pageSize,
        offset: offset,
      );

      _entries = result.entries;
      _totalCount = result.totalCount;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle filter POS tertentu
  void togglePos(String pos) {
    if (_selectedPos.contains(pos)) {
      _selectedPos.remove(pos);
    } else {
      _selectedPos.add(pos);
    }
    _currentPage = 1;
    cariKata();
  }

  /// Reset semua filter POS
  void clearPosFilters() {
    _selectedPos.clear();
    _currentPage = 1;
    cariKata();
  }

  /// Ganti halaman pagination
  void setPage(int page) {
    if (page < 1 || page > totalPages) return;
    _currentPage = page;
    cariKata(page: page);
  }

  /// Reset pencarian
  void clearSearch() {
    _searchQuery = '';
    _currentPage = 1;
    cariKata();
  }
}
