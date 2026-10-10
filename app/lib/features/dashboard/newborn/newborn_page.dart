import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'newborn_video_model.dart';
import 'newborn_embed_player.dart';

class NewbornPage extends ConsumerStatefulWidget {
  const NewbornPage({super.key});

  @override
  ConsumerState<NewbornPage> createState() => _NewbornPageState();
}

class _NewbornPageState extends ConsumerState<NewbornPage> {
  int _selectedTabIndex = 0;
  List<NewbornVideo> _currentPlaylist = [];
  int _currentVideoIndex = 0;
  bool _isLoadingVideo = false;
  String? _errorMessage;
  late PageController _pageController;

  static const List<Map<String, dynamic>> _tabs = [
    {'label': 'Greetings', 'icon': Icons.waving_hand, 'folder': 'greetings'},
    {'label': 'Home', 'icon': Icons.home_outlined, 'folder': 'home'},
    {'label': 'Objects', 'icon': Icons.widgets_outlined, 'folder': 'objects'},
    {'label': 'Activities', 'icon': Icons.directions_run, 'folder': 'activities'},
    {'label': 'Social', 'icon': Icons.people_outline, 'folder': 'social'},
    {'label': 'People', 'icon': Icons.person_outline, 'folder': 'people'},
    {'label': 'Places', 'icon': Icons.location_on_outlined, 'folder': 'places'},
    {'label': 'Mixed', 'icon': Icons.extension_outlined, 'folder': 'mixed'},
  ];

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadTabCategory(_selectedTabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Mengambil daftar video dari tabel Supabase `newborn_videos` berdasarkan kategori
  Future<void> _loadTabCategory(int index) async {
    setState(() {
      _selectedTabIndex = index;
      _isLoadingVideo = true;
      _currentPlaylist = [];
      _currentVideoIndex = 0;
      _errorMessage = null;
    });

    final category = _tabs[index]['folder'] as String;

    try {
      final response = await _supabase
          .from('newborn_videos')
          .select()
          .eq('category', category)
          .order('order_index', ascending: true);

      if (!mounted) return;

      final videos = (response as List)
          .map((item) => NewbornVideo.fromMap(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _currentPlaylist = videos;
        _isLoadingVideo = false;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingVideo = false;
        _errorMessage = 'Gagal memuat video dari database.\nPeriksa koneksi internet Anda.';
      });
    }
  }

  void _nextVideo() {
    if (_currentPlaylist.isEmpty) return;
    if (_currentPlaylist.length == 1) {
      _loadTabCategory((_selectedTabIndex + 1) % _tabs.length);
      return;
    }
    final next = (_currentVideoIndex + 1) % _currentPlaylist.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevVideo() {
    if (_currentPlaylist.isEmpty) return;
    if (_currentPlaylist.length == 1) {
      _loadTabCategory((_selectedTabIndex - 1 + _tabs.length) % _tabs.length);
      return;
    }
    final prev = (_currentVideoIndex - 1 + _currentPlaylist.length) % _currentPlaylist.length;
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveVideo = _currentPlaylist.isNotEmpty && _currentVideoIndex < _currentPlaylist.length;
    final currentTab = _tabs[_selectedTabIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Embed Video Player Vertikal FULLSCREEN (Background layer)
          Positioned.fill(
            child: hasActiveVideo
                ? PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _currentPlaylist.length,
                    onPageChanged: (index) {
                      setState(() => _currentVideoIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final video = _currentPlaylist[index];
                      return NewbornEmbedPlayer(
                        key: ValueKey(video.id.isNotEmpty ? video.id : video.embedUrl),
                        video: video,
                        isActive: index == _currentVideoIndex,
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _errorMessage != null
                                  ? Icons.wifi_off_rounded
                                  : currentTab['icon'] as IconData,
                              size: 44,
                              color: _errorMessage != null ? Colors.redAccent : Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage != null
                                ? 'Koneksi Terputus'
                                : currentTab['label'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _errorMessage != null ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ??
                                'Belum ada video untuk kategori ${currentTab['label']}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _loadTabCategory(_selectedTabIndex),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),

          // Loading overlay saat query database
          if (_isLoadingVideo)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 12),
                    Text(
                      'Memuat playlist video...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Bottom gradient overlay — nutup caption TikTok di bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black,
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Tombol Panah Naik/Turun Navigasi
          if (hasActiveVideo)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: SafeArea(
                child: PointerInterceptor(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filled(
                        onPressed: _prevVideo,
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.75),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _nextVideo,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.75),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Top App Bar & Category Tabs (Melayang di atas video)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PointerInterceptor(
              child: _buildTopSection(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Header with Back Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  'Newborn — Passive Exposure',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // Category Tabs dengan mouse-drag support
          SizedBox(
            height: 76,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isSelected = _selectedTabIndex == index;

                  return GestureDetector(
                    onTap: () {
                      if (_selectedTabIndex != index) {
                        _loadTabCategory(index);
                      }
                    },
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.amber : Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.amber.shade200 : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Icon(
                              tab['icon'] as IconData,
                              color: isSelected ? Colors.black87 : Colors.white70,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tab['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.amber : Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
