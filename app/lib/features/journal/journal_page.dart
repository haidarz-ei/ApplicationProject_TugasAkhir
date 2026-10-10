import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app/features/journal/add_book_page.dart';
import 'package:app/data/models/journal_entry.dart';
import 'package:app/data/repositories/journal_repository.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final JournalRepository _repo = JournalRepository();
  List<JournalEntry> _journals = [];
  bool _isLoading = true;

  // Variasi warna untuk dot dan thumbnail card
  static const List<Color> _cardColors = [
    Colors.purple,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.pink,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF059669),
      ),
    );
  }

  Future<void> _loadJournals() async {
    try {
      // Coba sinkronisasi jurnal offline jika koneksi online tersedia
      await _repo.syncUnsyncedJournals().catchError((_) => 0);
      final journals = await _repo.getAll();
      if (mounted) {
        setState(() {
          _journals = journals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Failed to load journals: $e', isError: true);
      }
    }
  }

  Future<void> _navigateToAddBook({JournalEntry? editEntry}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddBookPage(editEntry: editEntry),
      ),
    );

    if (result == true) {
      _loadJournals();
    }
  }

  Future<void> _deleteJournal(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Book?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Book "${entry.title}" will be permanently deleted.', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && entry.id != null) {
      try {
        await _repo.delete(entry.id!);
        _showSnack('"${entry.title}" deleted successfully');
        _loadJournals();
      } catch (e) {
        _showSnack('Failed to delete: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Background Image
            Image.asset(
              'assets/images/journal.png',
              width: double.infinity,
              height: 380,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),

            // Gradient overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Konten Utama
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 110),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDFBF7),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Pages',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      else if (_journals.isEmpty)
                        _buildEmptyState()
                      else
                        ..._journals.asMap().entries.map(
                          (entry) => _buildJournalCard(entry.value, entry.key),
                        ),

                      _buildAddBookButton(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'My Journal',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A3728),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your personal book\nof growth and\nprogress.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4A3728),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text(
              'No books written yet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Start writing your first story below!',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBookButton() {
    return GestureDetector(
      onTap: () => _navigateToAddBook(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F0FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Color(0xFF6B4EFF), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Your New Book',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B4EFF),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Write a new chapter in your journal',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.auto_awesome, color: Colors.orange, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalCard(JournalEntry entry, int index) {
    final dotColor = _cardColors[index % _cardColors.length];

    return GestureDetector(
      onTap: () => _navigateToAddBook(editEntry: entry),
      onLongPress: () => _deleteJournal(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail kotak kiri
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                constraints: const BoxConstraints(minHeight: 56, maxHeight: 100),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: entry.imageUrl.isNotEmpty
                    ? _buildThumbnailImage(entry.imageUrl, dotColor)
                    : SizedBox(
                        height: 72,
                        child: Icon(
                          Icons.image,
                          color: dotColor.withValues(alpha: 0.5),
                          size: 28,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),

            // Konten kanan
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!entry.isSynced) ...[
                            Icon(Icons.cloud_off_rounded, size: 12, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            entry.formattedDate,
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.storyPreview,
                    style: const TextStyle(fontSize: 10, color: Colors.black54, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: dotColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entry.wordCount} words',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: dotColor,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _deleteJournal(entry),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailImage(String pathOrUrl, Color dotColor) {
    Widget errorWidget() => Icon(
      Icons.image,
      color: dotColor.withValues(alpha: 0.5),
      size: 28,
    );

    if (pathOrUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(pathOrUrl.split(',').last);
        return Image.memory(bytes, width: 72, fit: BoxFit.contain, errorBuilder: (_, _, _) => errorWidget());
      } catch (_) {
        return errorWidget();
      }
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://') || pathOrUrl.startsWith('blob:')) {
      return Image.network(pathOrUrl, width: 72, fit: BoxFit.contain, errorBuilder: (_, _, _) => errorWidget());
    }
    if (pathOrUrl.startsWith('assets/')) {
      return Image.asset(pathOrUrl, width: 72, fit: BoxFit.contain, errorBuilder: (_, _, _) => errorWidget());
    }
    if (!kIsWeb) {
      try {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return Image.file(file, width: 72, fit: BoxFit.contain, errorBuilder: (_, _, _) => errorWidget());
        }
      } catch (_) {}
    }

    return errorWidget();
  }
}
