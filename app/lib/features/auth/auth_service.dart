import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service untuk menangani otentikasi Supabase.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sign In dengan Email & Password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign Up dengan Email & Password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: (name != null && name.trim().isNotEmpty)
          ? {'full_name': name.trim(), 'name': name.trim()}
          : null,
    );
  }

  /// Sign In dengan Google OAuth
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? '${Uri.base.origin}/' : 'io.supabase.flutter://login-callback',
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
