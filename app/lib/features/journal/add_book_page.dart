import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/models/journal_entry.dart';
import 'package:app/data/repositories/journal_repository.dart';

/// Halaman untuk membuat atau mengedit buku journal.
class AddBookPage extends StatefulWidget {
  final JournalEntry? editEntry;

  const AddBookPage({super.key, this.editEntry});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final JournalRepository _repo = JournalRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _storyController = TextEditingController();
  String _imageUrl = '';
  bool _isSaving = false;

  bool get _isEditMode => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _titleController.text = widget.editEntry!.title;
      _storyController.text = widget.editEntry!.story;
      _imageUrl = widget.editEntry!.imageUrl;
    }
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF059669),
      ),
    );
  }

  Future<void> _saveBook() async {
    final title = _titleController.text.trim();
    final story = _storyController.text.trim();

    if (title.isEmpty || story.isEmpty) {
      _showSnack(title.isEmpty ? 'Title cannot be empty' : 'Story cannot be empty', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditMode) {
        final updated = await _repo.update(id: widget.editEntry!.id!, title: title, story: story, imageUrl: _imageUrl);
        if (mounted) {
          _showSnack(updated.isSynced ? 'Journal Updated Successfully' : 'Saved Offline (Will sync when online)');
          Navigator.pop(context, true);
        }
      } else {
        final created = await _repo.create(title: title, story: story, imageUrl: _imageUrl);
        if (mounted) {
          _showSnack(created.isSynced ? 'Journal Saved Successfully' : 'Saved Offline (Will sync when online)');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Failed to save: $e', isError: true);
      }
    }
  }

  void _addPicture() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Tambah Gambar Cerita', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              _buildSheetItem(Icons.photo_library_rounded, const Color(0xFF6B4EFF), 'Pilih dari Galeri', () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              }),
              _buildSheetItem(Icons.camera_alt_rounded, const Color(0xFF059669), 'Ambil dengan Kamera', () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              }),
              if (_imageUrl.isNotEmpty) ...[
                const Divider(),
                _buildSheetItem(Icons.delete_outline_rounded, Colors.red, 'Hapus Gambar', () {
                  Navigator.pop(ctx);
                  setState(() => _imageUrl = '');
                }, isDanger: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetItem(IconData icon, Color color, String title, VoidCallback onTap, {bool isDanger = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDanger ? Colors.red : null)),
      onTap: onTap,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (image == null) return;

      String finalUrl = '';
      try {
        final bytes = await image.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        await Supabase.instance.client.storage.from('journals').uploadBinary(fileName, bytes);
        finalUrl = Supabase.instance.client.storage.from('journals').getPublicUrl(fileName);
      } catch (_) {
        // Fallback offline / saat upload storage gagal:
        // Gunakan path lokal perangkat secara langsung (ringan, tidak membebani database)
        finalUrl = image.path;
      }

      if (mounted) setState(() => _imageUrl = finalUrl);
    } catch (e) {
      _showSnack('Gagal mengambil gambar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _storyController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildTitleCard(),
                  const SizedBox(height: 10),
                  _buildCard(
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF67B54C),
                    title: 'Write Your Story',
                    subtitle: 'What happened today?',
                    trailing: Text('Words: $wordCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      child: TextField(
                        controller: _storyController,
                        maxLines: 6,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Today I learned the word "luminous"...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4EFF),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(_isEditMode ? 'Update Book' : 'Save Book', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
          child: Image.asset('assets/images/journal.png', width: double.infinity, height: 200, fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Your\nBook' : 'Write Your\nNew Book',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF332211), height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEditMode ? 'Update your story.\nMake it even better.' : 'Every book is a step forward.\nWrite from your heart.',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF4A3728).withValues(alpha: 0.8), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleCard() {
    return _buildCard(
      icon: Icons.title_rounded,
      iconColor: const Color(0xFF7B52D9),
      title: 'Book Title',
      subtitle: 'Give your story a title',
      trailing: InkWell(
        onTap: _addPicture,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6B4EFF).withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_imageUrl.isNotEmpty ? Icons.image_rounded : Icons.add_photo_alternate_outlined, size: 14, color: const Color(0xFF6B4EFF)),
              const SizedBox(width: 4),
              Text(
                _imageUrl.isNotEmpty ? 'Change' : 'Add Picture',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B4EFF)),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: _titleController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'A Night of Stars',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${_titleController.text.length}/100', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ),
          if (_imageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: _buildImageWidget(_imageUrl, height: 56, width: 56)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Image attached', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
                  GestureDetector(
                    onTap: () => setState(() => _imageUrl = ''),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: Colors.grey.shade700, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF332211))),
                    Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildImageWidget(String pathOrUrl, {required double height, required double width, BoxFit fit = BoxFit.cover}) {
    Widget errorWidget() => Container(
      height: height,
      width: width,
      color: Colors.grey.shade200,
      child: Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 24)),
    );

    if (pathOrUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(pathOrUrl.split(',').last);
        return Image.memory(bytes, height: height, width: width, fit: fit, errorBuilder: (_, _, _) => errorWidget());
      } catch (_) {
        return errorWidget();
      }
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://') || pathOrUrl.startsWith('blob:')) {
      return Image.network(pathOrUrl, height: height, width: width, fit: fit, errorBuilder: (_, _, _) => errorWidget());
    }
    if (pathOrUrl.startsWith('assets/')) {
      return Image.asset(pathOrUrl, height: height, width: width, fit: fit, errorBuilder: (_, _, _) => errorWidget());
    }
    if (!kIsWeb) {
      try {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return Image.file(file, height: height, width: width, fit: fit, errorBuilder: (_, _, _) => errorWidget());
        }
      } catch (_) {}
    }
    return errorWidget();
  }
}
