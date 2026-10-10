import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:app/data/database/app_database.dart';

class SoundService {
  static VideoPlayerController? _correctPlayer;
  static VideoPlayerController? _wrongPlayer;
  static bool _isEnabled = true;
  static bool _isLoaded = false;

  static bool get isEnabled => _isEnabled;

  /// Memuat status sound effects dari SQLite app_preferences
  static Future<void> loadSettings() async {
    try {
      final val = await AppDatabase().getPreference('sound_effects_enabled');
      if (val != null) {
        _isEnabled = val == 'true';
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('SoundService loadSettings error: $e');
    }
  }

  /// Mengubah dan menyimpan status efek suara ke SQLite app_preferences
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      await AppDatabase().setPreference('sound_effects_enabled', enabled ? 'true' : 'false');
    } catch (e) {
      debugPrint('SoundService setEnabled error: $e');
    }
  }

  /// Play sound when answer is correct (green)
  static Future<void> playCorrect() async {
    if (!_isLoaded) await loadSettings();
    if (!_isEnabled) return;

    try {
      if (_correctPlayer == null) {
        _correctPlayer = VideoPlayerController.asset('assets/sound/rightAnwser.mp3');
        await _correctPlayer!.initialize();
      }
      await _correctPlayer!.seekTo(Duration.zero);
      await _correctPlayer!.play();
    } catch (e) {
      debugPrint('SoundService playCorrect error: $e');
    }
  }

  /// Play sound when answer is wrong (red)
  static Future<void> playWrong() async {
    if (!_isLoaded) await loadSettings();
    if (!_isEnabled) return;

    try {
      if (_wrongPlayer == null) {
        _wrongPlayer = VideoPlayerController.asset('assets/sound/wrongAnswer.mp3');
        await _wrongPlayer!.initialize();
      }
      await _wrongPlayer!.seekTo(Duration.zero);
      await _wrongPlayer!.play();
    } catch (e) {
      debugPrint('SoundService playWrong error: $e');
    }
  }
}
