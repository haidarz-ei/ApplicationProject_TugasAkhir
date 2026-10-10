import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utilitas sederhana untuk mengecek koneksi internet.
/// Menggunakan DNS lookup ke google.com — tidak butuh package tambahan.
class ConnectivityHelper {
  ConnectivityHelper._();

  /// Mengecek apakah perangkat terhubung ke internet.
  /// Return `true` jika terhubung, `false` jika tidak.
  static Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true; // Web selalu dianggap online

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
