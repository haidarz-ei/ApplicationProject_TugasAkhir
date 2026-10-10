import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app/core/utils/connectivity_helper.dart';
import 'package:app/data/models/dictionary_entry.dart';
import 'package:app/features/dictionary/dictionary_controller.dart';

/// Halaman Kamus Bahasa Inggris — search, filter POS, browse dengan pagination.
class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  final DictionaryController _controller = DictionaryController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<DictionaryEntry> get _entries => _controller.entries;
  List<String> get _availablePos => _controller.availablePos;
  Set<String> get _selectedPos => _controller.selectedPos;
  int get _totalCount => _controller.totalCount;
  int get _currentPage => _controller.currentPage;
  bool get _isLoading => _controller.isLoading;
  bool get _isPosLoading => _controller.isPosLoading;
  String get _searchQuery => _controller.searchQuery;



  static const Map<String, Color> _posColors = {
    'noun': Color(0xFF7C3AED), 'verb': Color(0xFF059669), 'adj': Color(0xFFD97706),
    'adv': Color(0xFF2563EB), 'conj': Color(0xFF6366F1), 'prep': Color(0xFFDC2626),
    'pron': Color(0xFF0891B2), 'det': Color(0xFF4F46E5), 'intj': Color(0xFFDB2777),
    'num': Color(0xFF0D9488), 'name': Color(0xFF9333EA), 'phrase': Color(0xFF65A30D),
    'prefix': Color(0xFFCA8A04), 'suffix': Color(0xFFEA580C), 'prep_phrase': Color(0xFF7C3AED),
    'proverb': Color(0xFF0369A1),
  };

  static const Map<String, String> _posLabels = {
    'noun': 'Noun', 'verb': 'Verb', 'adj': 'Adjective', 'adv': 'Adverb',
    'conj': 'Conjunction', 'prep': 'Preposition', 'pron': 'Pronoun', 'det': 'Determiner',
    'intj': 'Interjection', 'num': 'Number', 'name': 'Name', 'phrase': 'Phrase',
    'prefix': 'Prefix', 'suffix': 'Suffix', 'prep_phrase': 'Prep Phrase', 'proverb': 'Proverb',
    'particle': 'Particle', 'postp': 'Postposition', 'contraction': 'Contraction', 'symbol': 'Symbol',
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _checkConnectivityThenLoad();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// Cek koneksi internet sebelum memuat data kamus (wajib online)
  Future<void> _checkConnectivityThenLoad() async {
    final hasInternet = await ConnectivityHelper.hasInternetConnection();
    if (!hasInternet && mounted) {
      _showNoInternetDialog();
      return;
    }
    _controller.loadPosValues();
    _loadData();
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Tidak Ada Koneksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Kamus membutuhkan koneksi internet untuk mengambil data.\nPastikan Anda terhubung ke internet lalu coba lagi.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kembali', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _checkConnectivityThenLoad();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  int get _totalPages => _controller.totalPages;
  Color _getPosColor(String pos) => _posColors[pos] ?? const Color(0xFF475569);
  String _getPosLabel(String pos) => _posLabels[pos] ?? pos;

  Future<void> _loadData() async {
    await _controller.cariKata();
    if (_controller.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: ${_controller.errorMessage}'), backgroundColor: Colors.red.shade600),
      );
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _controller.cariKata(keyword: value.trim(), page: 1);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.clearSearch();
  }

  void _togglePosFilter(String pos) {
    _controller.togglePos(pos);
  }

  void _clearAllFilters() {
    _controller.clearPosFilters();
  }

  void _goToPage(int page) {
    _controller.setPage(page);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset('assets/images/logoAplikasi.png', width: 42, height: 42, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dictionary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            Text(_isLoading ? 'Loading...' : '$_totalCount words found', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSearchBar(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : _buildWordList(),
            ),
            if (!_isLoading && _entries.isNotEmpty) _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onSubmitted: (v) { _controller.cariKata(keyword: v.trim(), page: 1); },
        style: const TextStyle(fontSize: 14),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search words in dictionary...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(onPressed: _clearSearch, icon: Icon(Icons.close, color: Colors.grey.shade500, size: 20))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_isPosLoading) {
      return const SizedBox(height: 36, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _availablePos.length + (_selectedPos.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (_selectedPos.isNotEmpty && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: const Text('Clear Filters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                avatar: const Icon(Icons.clear_all, size: 16),
                onPressed: _clearAllFilters,
                backgroundColor: Colors.red.shade50,
                labelStyle: TextStyle(color: Colors.red.shade600),
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }

          final pos = _availablePos[_selectedPos.isNotEmpty ? index - 1 : index];
          final isSelected = _selectedPos.contains(pos);
          final color = _getPosColor(pos);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_getPosLabel(pos), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : color)),
              selected: isSelected,
              onSelected: (_) => _togglePosFilter(pos),
              backgroundColor: color.withValues(alpha: 0.08),
              selectedColor: color,
              side: BorderSide(color: isSelected ? color : color.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No words found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(_searchQuery.isNotEmpty ? 'Try using different keywords' : 'No data matches the selected filter', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          if (_selectedPos.isNotEmpty || _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                _controller.clearSearch();
                _controller.clearPosFilters();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset Search', style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _entries.length,
      itemBuilder: (context, index) => _buildWordCard(_entries[index]),
    );
  }

  Widget _buildWordCard(DictionaryEntry entry) {
    final posColor = _getPosColor(entry.pos);
    final showVerbForms = entry.pos == 'verb' && entry.v1.isNotEmpty && entry.v2.isNotEmpty && entry.v3.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(entry.word, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: posColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_getPosLabel(entry.pos), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: posColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry.definitionId, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
          if (entry.definitionEn.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(entry.definitionEn, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (showVerbForms) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildVerbCol('V1 (Base)', entry.v1),
                  _buildVerbCol('V2 (Past)', entry.v2),
                  _buildVerbCol('V3 (Participle)', entry.v3),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerbCol(String title, String word) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(word, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPageBtn(icon: Icons.chevron_left, label: 'Prev', isLeft: true, onTap: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null),
          Text('Page $_currentPage of $_totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          _buildPageBtn(icon: Icons.chevron_right, label: 'Next', isLeft: false, onTap: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null),
        ],
      ),
    );
  }

  Widget _buildPageBtn({required IconData icon, required String label, required bool isLeft, VoidCallback? onTap}) {
    final isEnabled = onTap != null;
    final color = isEnabled ? const Color(0xFF6B4EFF) : Colors.grey.shade300;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLeft) Icon(icon, size: 18, color: color),
            if (isLeft) const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            if (!isLeft) const SizedBox(width: 4),
            if (!isLeft) Icon(icon, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
