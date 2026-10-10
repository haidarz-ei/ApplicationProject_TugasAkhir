import 'package:flutter/material.dart';
import 'package:app/features/dashboard/dashboard_page.dart';
import 'package:app/features/dictionary/dictionary_page.dart';
import 'package:app/features/journal/journal_page.dart';
import 'package:app/features/settings/settings_page.dart';
import 'package:app/services/dictionary_notification_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DictionaryNotificationService().checkPendingNotification();
    });
  }

  // Daftar halaman yang akan ditampilkan
  late final List<Widget> _pages = [
    const DashboardPage(),
    const DictionaryPage(),
    const JournalPage(),
    const SettingsPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack digunakan agar state tiap halaman tidak hilang saat pindah tab
      body: IndexedStack(index: _currentIndex, children: _pages),

      // Bottom Navigation Bar custom
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_filled, "Home", 0),
            _buildNavItem(Icons.book, "Dictionary", 1),
            _buildNavItem(Icons.edit, "Journal", 2),
            _buildNavItem(Icons.settings, "Settings", 3),
          ],
        ),
      ),
    );
  }

  // Helper untuk membuat ikon navigasi
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF6B4EFF) : Colors.grey;

    return InkWell(
      onTap: () => _onTabTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
