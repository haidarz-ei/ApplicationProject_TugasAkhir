import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/features/auth/auth_service.dart';
import 'package:app/features/main_navigation.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  static const _brandColor = Color(0xFF6B4EFF);

  @override
  void initState() {
    super.initState();
    if (_authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      });
    }

    _authSubscription = _authService.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (_isSignUp && name.isEmpty) {
      setState(() { _errorMessage = 'Please enter your name.'; _infoMessage = null; });
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() { _errorMessage = 'Please fill in both email and password.'; _infoMessage = null; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _infoMessage = null; });

    try {
      if (_isSignUp) {
        final response = await _authService.signUpWithEmail(email: email, password: password, name: name);
        if (response.session != null) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          }
        } else {
          // If session is null, email confirmation is required or user already exists
          if (mounted) {
            setState(() {
              _isSignUp = false;
              _infoMessage = 'Account created/pending. If email confirmation is enabled, check your inbox to confirm, or Sign In with your credentials.';
            });
          }
        }
      } else {
        final response = await _authService.signInWithEmail(email: email, password: password);
        if (response.session != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (errStr.contains('invalid_credentials')) {
          setState(() => _errorMessage = 'Invalid email or password. If you originally registered with Google, please tap "Continue with Google".');
        } else if (errStr.contains('user_already_exists')) {
          setState(() => _errorMessage = 'This email is already registered. Please Sign In using your password or Google.');
        } else {
          setState(() => _errorMessage = errStr.replaceAll('AuthApiException:', '').replaceAll('Exception:', '').trim());
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; _infoMessage = null; });
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/images/logoAplikasi.png', width: 72, height: 72, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OnePath Lingua',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Master English naturally through structured immersion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),

                  // Auth Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Toggle Sign In / Sign Up
                        Row(
                          children: [
                            _buildTabItem('Sign In', !_isSignUp, () => setState(() { _isSignUp = false; _errorMessage = null; _infoMessage = null; })),
                            _buildTabItem('Sign Up', _isSignUp, () => setState(() { _isSignUp = true; _errorMessage = null; _infoMessage = null; })),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Info Banner
                        if (_infoMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Text(_infoMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                          ),
                          const SizedBox(height: 14),
                        ],

                        if (_isSignUp) ...[
                          _buildInputField(label: 'Full Name', hint: 'Your name', controller: _nameController, icon: Icons.person_outline_rounded),
                          const SizedBox(height: 14),
                        ],

                        _buildInputField(
                          label: 'Email',
                          hint: 'name@example.com',
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),

                        _buildInputField(
                          label: 'Password',
                          hint: '••••••••',
                          controller: _passwordController,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitEmailAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // OR Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google Sign-In Button
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E293B),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/images/icons8-google-logo-48.png', width: 20, height: 20),
                                const SizedBox(width: 10),
                                const Text('Continue with Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
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
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? _brandColor : Colors.transparent, width: 2.5))),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? _brandColor : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
        final isObscured = _obscurePassword == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              obscureText: isPassword ? isObscured : false,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(icon, size: 20),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !isObscured),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ],
        );
  }
}
