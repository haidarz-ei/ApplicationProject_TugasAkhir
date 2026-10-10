import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/features/auth/auth_service.dart';
import 'package:app/features/auth/auth_page.dart';
import 'package:app/services/dictionary_notification_service.dart';
import 'package:app/data/repositories/progress_repository.dart';
import 'package:app/features/dashboard/dashboard_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _authService = AuthService();
  final _notifService = DictionaryNotificationService();
  late WordReminderSettings _reminderSettings;

  @override
  void initState() {
    super.initState();
    _reminderSettings = _notifService.settings;
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _updateSettings(WordReminderSettings newSettings) async {
    setState(() => _reminderSettings = newSettings);
    if (newSettings.isActive) {
      await _notifService.requestPermissions();
    }
    await _notifService.updateSettings(newSettings);
  }

  // ---------------------------------------------------------------------------
  // Dialogs & Actions
  // ---------------------------------------------------------------------------

  void _showSelectionSheet<T>({
    required String title,
    required List<T> items,
    required T selectedItem,
    required String Function(T) labelBuilder,
    required void Function(T) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...items.map((item) {
                final isSelected = item == selectedItem;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: isSelected ? const Color(0xFF6B4EFF) : Colors.grey,
                  ),
                  title: Text(
                    labelBuilder(item),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF6B4EFF) : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected(item);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderSettings.startTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6B4EFF), onPrimary: Colors.white, onSurface: Color(0xFF1E293B)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      _updateSettings(_reminderSettings.copyWith(startTime: picked));
      _showSnack('Start Time set to ${_notifService.formatTimeOfDay(picked)}');
    }
  }

  Future<bool?> _showConfirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white, elevation: 0),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.logout_rounded,
      iconColor: Colors.redAccent,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out of your account on this device?',
      confirmLabel: 'Sign Out',
      confirmColor: Colors.redAccent,
    );

    if (confirmed == true && mounted) {
      _showSnack('Signing out...');
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthPage()), (route) => false);
      }
    }
  }

  Future<void> _handleResetProgress() async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.restart_alt_rounded,
      iconColor: Colors.deepOrange,
      title: 'Reset Progres Belajar',
      content: 'Semua pencapaian level akan di-reset kembali ke Level 0 untuk keperluan pengujian.\n\nApakah Anda yakin ingin mereset?',
      confirmLabel: 'Ya, Reset',
      confirmColor: Colors.deepOrange,
    );

    if (confirmed == true && mounted) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await ProgressRepository().resetAllProgress(userId);
      }
      ref.read(sectionsProvider.notifier).resetAllSections();
      _showSnack('Seluruh progres level berhasil di-reset ke Level 0.', color: Colors.deepOrange);
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/images/logoAplikasi.png', width: 32, height: 32)),
            const SizedBox(width: 10),
            const Text('OnePath Lingua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF6B4EFF))),
            SizedBox(height: 8),
            Text(
              'Master English naturally through 6 structured acquisition phases:\n\n'
              '1. Newborn (Phonics & Visuals)\n'
              '2. Listener (Audio Comprehension)\n'
              '3. Speaker (Speech Mimicry)\n'
              '4. Builder (Sentence Formation)\n'
              '5. Converser (AI Dialogue)\n'
              '6. Native Mind (Cognitive Strategy)',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }

  String get _posDisplayName => switch (_reminderSettings.selectedPos) {
        'noun' => 'Noun',
        'verb' => 'Verb',
        'adj' => 'Adjective',
        'adv' => 'Adverb',
        'phrase' => 'Phrase & Idiom',
        _ => 'All Categories',
      };

  // ---------------------------------------------------------------------------
  // Build Page
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final userEmail = currentUser?.email ?? 'Guest / Anonymous User';
    final userId = currentUser?.id ?? '';
    final shortUserId = userId.isNotEmpty ? (userId.length > 12 ? '${userId.substring(0, 12)}...' : userId) : 'Offline';

    const posOptions = [
      ('all', 'All Categories (Semua Kata)'),
      ('noun', 'Noun (Kata Benda)'),
      ('verb', 'Verb (Kata Kerja)'),
      ('adj', 'Adjective (Kata Sifat)'),
      ('adv', 'Adverb (Kata Keterangan)'),
      ('phrase', 'Phrases & Idioms'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Image.asset('assets/images/setting.png', width: double.infinity, height: 380, fit: BoxFit.cover, alignment: Alignment.topCenter),
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
                    colors: [Colors.white.withValues(alpha: 0.4), Colors.transparent],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 110),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Color(0xFFFDFBF7), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                  padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAccountSection(userEmail, shortUserId),
                      const SizedBox(height: 20),
                      _buildFeederSection(posOptions),
                      const SizedBox(height: 20),
                      _buildGeneralSection(),
                      const SizedBox(height: 100),
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
    return const SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A3728))),
            SizedBox(height: 8),
            Text('Manage your preferences\nand account settings.', style: TextStyle(fontSize: 14, color: Color(0xFF4A3728), height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(String email, String shortId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.account_circle_outlined, const Color(0xFF6B4EFF), 'Account'),
        const SizedBox(height: 10),
        _buildSectionContainer([
          _buildItem(
            icon: Icons.person_rounded,
            iconColor: const Color(0xFF6B4EFF),
            title: email,
            subtitle: 'User ID: $shortId',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ),
          ),
          _buildItem(
            icon: Icons.logout_rounded,
            iconColor: Colors.redAccent,
            title: 'Sign Out',
            titleColor: Colors.redAccent,
            subtitle: 'Log out of your OnePath Lingua session',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.redAccent, size: 12),
            onTap: _handleSignOut,
          ),
        ]),
      ],
    );
  }

  Widget _buildFeederSection(List<(String, String)> posOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.notifications_rounded, const Color(0xFF6B4EFF), 'Dictionary Notification & Word Feeder'),
        const SizedBox(height: 10),
        _buildSectionContainer([
          _buildItem(
            icon: Icons.track_changes_rounded,
            iconColor: Colors.redAccent,
            title: 'Daily Goal',
            subtitle: 'Target vocabulary per day',
            trailing: _buildTrailingPill('${_reminderSettings.dailyGoal} Words'),
            onTap: () => _showSelectionSheet<int>(
              title: 'Select Daily Goal',
              items: const [6, 12, 18, 24],
              selectedItem: _reminderSettings.dailyGoal,
              labelBuilder: (g) => '$g Words',
              onSelected: (g) => _updateSettings(_reminderSettings.copyWith(dailyGoal: g)),
            ),
          ),
          _buildItem(
            icon: Icons.calendar_today_rounded,
            iconColor: Colors.green,
            title: 'Reminder Frequency',
            subtitle: 'Delivery interval (~${_notifService.wordsPerSession} words per reminder)',
            trailing: _buildTrailingPill(_reminderSettings.frequency),
            onTap: () => _showSelectionSheet<String>(
              title: 'Select Reminder Frequency',
              items: const ['Every 30 Minutes', 'Every 1 Hour', 'Every 2 Hours', 'Every 3 Hours'],
              selectedItem: _reminderSettings.frequency,
              labelBuilder: (f) => f,
              onSelected: (f) => _updateSettings(_reminderSettings.copyWith(frequency: f)),
            ),
          ),
          _buildItem(
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFFD97706),
            title: 'Start Time',
            subtitle: 'Scheduled start time for first daily word',
            trailing: _buildTrailingPill(_notifService.formatTimeOfDay(_reminderSettings.startTime)),
            onTap: _pickStartTime,
          ),
          _buildItem(
            icon: Icons.category_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Choose Part of Speech',
            subtitle: 'Filter types of words to feed from dictionary',
            trailing: _buildTrailingPill(_posDisplayName),
            onTap: () {
              final current = posOptions.firstWhere((o) => o.$1 == _reminderSettings.selectedPos, orElse: () => posOptions.first);
              _showSelectionSheet<(String, String)>(
                title: 'Choose Part of Speech',
                items: posOptions,
                selectedItem: current,
                labelBuilder: (o) => o.$2,
                onSelected: (o) => _updateSettings(_reminderSettings.copyWith(selectedPos: o.$1)),
              );
            },
          ),
          _buildItem(
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFF6B4EFF),
            title: 'Activate Notification',
            titleColor: const Color(0xFF6B4EFF),
            subtitle: "We'll spoil you with fresh words based on your schedule.",
            backgroundColor: const Color(0xFFF9F5FF),
            trailing: Transform.scale(
              scale: 0.75,
              child: Switch(
                value: _reminderSettings.isActive,
                onChanged: (val) {
                  _updateSettings(_reminderSettings.copyWith(isActive: val));
                  _showSnack(val ? 'Word Feeder notifications activated!' : 'Word Feeder notifications paused.');
                },
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF6B4EFF),
              ),
            ),
          ),
          if (_reminderSettings.isActive)
            _buildItem(
              icon: Icons.send_to_mobile_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Test Notification Now',
              subtitle: 'Send test word to phone top bar & lock screen immediately',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF10B981), size: 12),
              onTap: () async {
                await _notifService.requestPermissions();
                await _notifService.showInstantNativeNotification();
                _showSnack('Notifikasi dikirim ke status bar & lock screen!');
              },
            ),
        ]),
      ],
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.settings_rounded, Colors.grey.shade700, 'General Settings'),
        const SizedBox(height: 10),
        _buildSectionContainer([
          _buildItem(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF6B4EFF),
            title: 'About OnePath Lingua',
            subtitle: 'App information, phases, and version',
            onTap: _showAboutDialog,
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('v 1.0.0', style: TextStyle(fontSize: 11, color: Colors.black54)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.black38, size: 12),
              ],
            ),
          ),
          _buildItem(
            icon: Icons.restart_alt_rounded,
            iconColor: Colors.deepOrange,
            title: 'Reset Learning Progress',
            subtitle: 'Reset all phases and levels back to Level 0 (Dev)',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black38, size: 12),
            onTap: _handleResetProgress,
          ),
        ]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable Widgets
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(IconData icon, Color color, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSectionContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 48),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    Color? titleColor,
    Color backgroundColor = Colors.transparent,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: backgroundColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor ?? Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    );

    return onTap != null ? InkWell(onTap: onTap, child: content) : content;
  }

  Widget _buildTrailingPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black38, size: 9),
        ],
      ),
    );
  }
}
