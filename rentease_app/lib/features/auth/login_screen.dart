import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api_client.dart';
import '../../core/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Listen for sign-in events from GoogleSignIn v7 stream
    GoogleSignIn.instance.authenticationEvents
        .listen(_handleGoogleAuthEvent)
        .onError((_) {});
  }

  void _handleGoogleAuthEvent(GoogleSignInAuthenticationEvent event) {
    // Handled inline in _googleLogin; stream used for lightweight auth only
  }

  Future<void> _saveAndNavigate(Map<String, dynamic> data) async {
    await _storage.write(key: accessTokenKey, value: data['access']);
    await _storage.write(key: refreshTokenKey, value: data['refresh']);
    await _storage.write(key: 'user_role', value: data['user']['role']);
    if (!mounted) return;
    registerFCMTokenAfterLogin();
    final role = data['user']['role'] as String;
    if (role == 'owner') {
      context.go('/owner/home');
    } else {
      context.go('/tenant/home');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await apiClient.post(
        '/api/v1/auth/login/',
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
      await _saveAndNavigate(response.data as Map<String, dynamic>);
    } on DioException catch (err) {
      setState(() {
        _errorMessage = err.response?.data?['error'] ??
            'Login failed. Please check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });
    try {
      // v7 API: use singleton + authenticate()
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        setState(() => _errorMessage = 'Google sign-in failed: no ID token.');
        return;
      }
      final response = await apiClient.post(
        '/api/v1/auth/google/',
        data: {'id_token': idToken},
      );
      await _saveAndNavigate(response.data as Map<String, dynamic>);
    } on DioException catch (err) {
      setState(() {
        _errorMessage = err.response?.data?['detail'] ??
            'Google sign-in failed. Please try again.';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: size.height,
            child: Stack(
              children: [
                // Top decorative arc
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: size.height * 0.38,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A3C6E), Color(0xFF2E6DA4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(48),
                        bottomRight: Radius.circular(48),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'RentLedger',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage your properties with ease',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Login card
                Positioned(
                  top: size.height * 0.30,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A3C6E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to your account',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: 'Email address',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                  .hasMatch(value.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: _inputDecoration(
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey.shade400,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),

                          // Error message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Color(0xFFD32F2F), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFD32F2F),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A3C6E),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF1A3C6E).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Google Sign-In button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _isGoogleLoading ? null : _googleLogin,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              child: _isGoogleLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF1A3C6E),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.network(
                                          'https://www.google.com/favicon.ico',
                                          height: 20,
                                          width: 20,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.g_mobiledata_rounded,
                                            size: 24,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2E6DA4), size: 20),
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E6DA4), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
    );
  }
}
