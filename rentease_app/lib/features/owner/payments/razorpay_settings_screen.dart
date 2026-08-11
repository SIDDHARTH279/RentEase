import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

/// Owner payment setup: Razorpay (optional) + UPI / bank / QR for offline rent.
class RazorpaySettingsScreen extends StatefulWidget {
  const RazorpaySettingsScreen({super.key});

  @override
  State<RazorpaySettingsScreen> createState() => _RazorpaySettingsScreenState();
}

class _RazorpaySettingsScreenState extends State<RazorpaySettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _razorpayFormKey = GlobalKey<FormState>();
  final _manualFormKey = GlobalKey<FormState>();
  final _keyIdController = TextEditingController();
  final _secretController = TextEditingController();
  final _upiController = TextEditingController();
  final _holderController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _configured = false;
  bool _enabled = true;
  bool _showManual = true;
  bool _hasManual = false;
  bool _obscureSecret = true;
  String? _maskedSecret;
  String? _qrUrl;
  File? _pickedQr;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _keyIdController.dispose();
    _secretController.dispose();
    _upiController.dispose();
    _holderController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/billing/payment-settings/');
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      setState(() {
        _keyIdController.text = data['razorpay_key_id']?.toString() ?? '';
        _configured = data['is_configured'] == true;
        _enabled = data['is_enabled'] != false;
        _maskedSecret = data['key_secret_masked']?.toString();
        _upiController.text = data['upi_id']?.toString() ?? '';
        _holderController.text = data['account_holder_name']?.toString() ?? '';
        _bankController.text = data['bank_name']?.toString() ?? '';
        _accountController.text = data['account_number']?.toString() ?? '';
        _ifscController.text = data['ifsc_code']?.toString() ?? '';
        _notesController.text = data['payment_notes']?.toString() ?? '';
        _showManual = data['show_manual_details'] != false;
        _hasManual = data['has_manual_details'] == true;
        _qrUrl = data['qr_code_url']?.toString();
        if (_qrUrl != null && _qrUrl!.isEmpty) _qrUrl = null;
        _pickedQr = null;
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load payment settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickQr() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;
    setState(() => _pickedQr = File(file.path));
  }

  Future<void> _saveRazorpay() async {
    if (!_razorpayFormKey.currentState!.validate()) return;

    final keyId = _keyIdController.text.trim();
    final secret = _secretController.text.trim();

    if (!_configured && secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Key Secret is required for first-time setup.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'razorpay_key_id': keyId,
        'is_enabled': _enabled,
      };
      if (secret.isNotEmpty) body['razorpay_key_secret'] = secret;

      final res = await apiClient.patch(
        '/api/v1/billing/payment-settings/',
        data: body,
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      setState(() {
        _configured = data['is_configured'] == true;
        _enabled = data['is_enabled'] != false;
        _maskedSecret = data['key_secret_masked']?.toString();
        _secretController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Razorpay settings saved.'),
          backgroundColor: Color(0xFF388E3C),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? 'Failed to save settings.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveManual({bool clearQr = false}) async {
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        'upi_id': _upiController.text.trim(),
        'account_holder_name': _holderController.text.trim(),
        'bank_name': _bankController.text.trim(),
        'account_number': _accountController.text.trim(),
        'ifsc_code': _ifscController.text.trim().toUpperCase(),
        'payment_notes': _notesController.text.trim(),
        'show_manual_details': _showManual.toString(),
        if (clearQr) 'clear_qr_code': 'true',
      });
      if (_pickedQr != null && !clearQr) {
        form.files.add(
          MapEntry(
            'qr_code',
            await MultipartFile.fromFile(
              _pickedQr!.path,
              filename: _pickedQr!.path.split(Platform.pathSeparator).last,
            ),
          ),
        );
      }

      final res = await apiClient.patch(
        '/api/v1/billing/payment-settings/',
        data: form,
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      setState(() {
        _hasManual = data['has_manual_details'] == true;
        _showManual = data['show_manual_details'] != false;
        _qrUrl = data['qr_code_url']?.toString();
        if (_qrUrl != null && _qrUrl!.isEmpty) _qrUrl = null;
        _pickedQr = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clearQr
                ? 'QR code removed.'
                : 'Bank / UPI / QR details saved. Tenants can use these to pay.',
          ),
          backgroundColor: const Color(0xFF388E3C),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? 'Failed to save details.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Bank / QR'),
            Tab(text: 'Razorpay'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildManualTab(scheme),
                    _buildRazorpayTab(scheme),
                  ],
                ),
    );
  }

  Widget _buildManualTab(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _manualFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBanner(
              scheme,
              icon: _hasManual ? Icons.check_circle_rounded : Icons.info_outline,
              good: _hasManual,
              text: _hasManual
                  ? 'Tenants can see your UPI / bank / QR and pay offline. Mark rent paid after you receive cash or transfer.'
                  : 'Add UPI ID, bank details, and/or a payment QR if you do not use Razorpay. Tenants will see these on Billing.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Show details to tenants',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.brandText,
                ),
              ),
              subtitle: Text(
                'Turn off to hide bank/QR while keeping them saved.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              value: _showManual,
              onChanged: (v) => setState(() => _showManual = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Payment QR',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.brandText,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickQr,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedQr != null
                    ? Image.file(_pickedQr!, fit: BoxFit.contain)
                    : (_qrUrl != null
                        ? Image.network(_qrUrl!, fit: BoxFit.contain)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2_rounded,
                                  size: 40, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload QR code',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )),
              ),
            ),
            if (_qrUrl != null || _pickedQr != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (_pickedQr != null && _qrUrl == null) {
                          setState(() => _pickedQr = null);
                          return;
                        }
                        await _saveManual(clearQr: true);
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove QR'),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _upiController,
              decoration: _decoration('UPI ID', hint: 'name@upi'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holderController,
              decoration: _decoration('Account holder name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankController,
              decoration: _decoration('Bank name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Account number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ifscController,
              textCapitalization: TextCapitalization.characters,
              decoration: _decoration('IFSC code'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: _decoration(
                'Note for tenants (optional)',
                hint: 'e.g. Add unit number in transfer remark',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : () => _saveManual(),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Save bank / QR details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRazorpayTab(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _razorpayFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBanner(
              scheme,
              icon: _configured
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              good: _configured,
              text: _configured
                  ? 'Razorpay is connected. Tenants can pay online to your account.'
                  : 'Optional. Add Razorpay keys for in-app checkout. Skip this if you only use cash / UPI / bank.',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Accept Razorpay payments',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.brandText,
                ),
              ),
              subtitle: Text(
                'Turn off to temporarily disable online checkout.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _keyIdController,
              decoration: _decoration(
                'Key ID',
                hint: 'rzp_test_… or rzp_live_…',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Key ID is required to enable Razorpay';
                }
                if (!v.trim().startsWith('rzp_')) {
                  return 'Key ID should start with rzp_';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _secretController,
              obscureText: _obscureSecret,
              decoration: _decoration(
                _configured
                    ? 'Key Secret (leave blank to keep current)'
                    : 'Key Secret',
                hint: _configured
                    ? (_maskedSecret ?? 'Secret already saved')
                    : 'Your Razorpay key secret',
                suffix: IconButton(
                  icon: Icon(
                    _obscureSecret
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureSecret = !_obscureSecret),
                ),
              ),
              validator: (v) {
                if (!_configured && (v == null || v.trim().isEmpty)) {
                  return 'Key Secret is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _saveRazorpay,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Save Razorpay settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner(
    ColorScheme scheme, {
    required IconData icon,
    required bool good,
    required String text,
  }) {
    final bg = good
        ? scheme.primaryContainer.withValues(alpha: 0.45)
        : scheme.surfaceContainerHighest;
    final fg = good ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    Widget? suffix,
  }) {
    final scheme = context.colors;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: context.softFill,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }
}
