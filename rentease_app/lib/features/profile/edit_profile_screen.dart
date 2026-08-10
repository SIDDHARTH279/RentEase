import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

class EditProfileScreen extends StatefulWidget {
  /// If true, user cannot go back until profile is complete.
  final bool requireComplete;

  const EditProfileScreen({super.key, this.requireComplete = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  String _email = '';
  String _role = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/auth/profile/');
      final data = res.data as Map<String, dynamic>;
      _firstNameController.text = data['first_name']?.toString() ?? '';
      _lastNameController.text = data['last_name']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _email = data['email']?.toString() ?? '';
      _role = data['role']?.toString() ?? '';
      await _storage.write(key: 'user_first_name', value: _firstNameController.text);
      await _storage.write(key: 'user_last_name', value: _lastNameController.text);
      await _storage.write(key: 'user_phone', value: _phoneController.text);
      await _storage.write(key: 'user_email', value: _email);
    } on DioException {
      _error = 'Could not load profile.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final res = await apiClient.patch(
        '/api/v1/auth/profile/',
        data: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      await _storage.write(
          key: 'user_first_name', value: data['first_name']?.toString() ?? '');
      await _storage.write(
          key: 'user_last_name', value: data['last_name']?.toString() ?? '');
      await _storage.write(
          key: 'user_phone', value: data['phone']?.toString() ?? '');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Color(0xFF388E3C),
        ),
      );

      final role = data['role']?.toString() ?? _role;
      if (widget.requireComplete) {
        context.go(role == 'tenant' ? '/tenant/home' : '/owner/home');
      } else if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(role == 'tenant' ? '/tenant/home' : '/owner/home');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'Failed to save profile.';
      if (data is Map) {
        msg = data['phone']?.first?.toString() ??
            data['first_name']?.first?.toString() ??
            data['detail']?.toString() ??
            msg;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3C6E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.requireComplete ? 'Complete your profile' : 'Edit Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: widget.requireComplete
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              ),
        automaticallyImplyLeading: !widget.requireComplete,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A3C6E)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.requireComplete) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Add your name and phone so owners/tenants can identify you.',
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _label('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _email,
                      enabled: false,
                      decoration: _decoration(icon: Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    _label('First name'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        icon: Icons.person_outline,
                        hint: 'e.g. Rahul',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'First name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _label('Last name'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        icon: Icons.badge_outlined,
                        hint: 'e.g. Sharma',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Phone number'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: _decoration(
                        icon: Icons.phone_outlined,
                        hint: 'e.g. 9876543210',
                      ).copyWith(counterText: ''),
                      validator: (v) {
                        final raw = (v ?? '').replaceAll(RegExp(r'[\s\-+]'), '');
                        if (raw.isEmpty) return 'Phone number is required';
                        if (!RegExp(r'^\d+$').hasMatch(raw)) {
                          return 'Enter a valid phone number';
                        }
                        if (raw.length != 10) {
                          return 'Phone number must be exactly 10 digits';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFD32F2F))),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3C6E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.requireComplete
                                    ? 'Save & Continue'
                                    : 'Save Changes',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A3C6E),
          fontSize: 14,
        ),
      );

  InputDecoration _decoration({required IconData icon, String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF2E6DA4), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E6DA4), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }
}
