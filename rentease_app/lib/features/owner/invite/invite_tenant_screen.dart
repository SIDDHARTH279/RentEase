import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class InviteTenantScreen extends StatefulWidget {
  const InviteTenantScreen({super.key});

  @override
  State<InviteTenantScreen> createState() => _InviteTenantScreenState();
}

class _InviteTenantScreenState extends State<InviteTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _shareController = TextEditingController(text: '100');
  final _dueDayController = TextEditingController(text: '5');

  List<dynamic> _units = [];
  int? _unitId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _shareController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/properties/units/');
      final list = res.data as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _units = list;
        if (list.isNotEmpty) {
          _unitId = (list.first as Map)['id'] as int;
        }
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load units.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _unitLabel(Map unit) {
    final num = unit['unit_number'] ?? '—';
    final building = unit['building_name'] ?? '';
    final vacant = unit['is_vacant'] == true;
    final base = building.toString().isNotEmpty
        ? 'Unit $num · $building'
        : 'Unit $num';
    return vacant ? '$base (vacant)' : base;
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add a unit first.'),
          backgroundColor: context.accentRed(),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final res = await apiClient.post(
        '/api/v1/auth/invite-tenant/',
        data: {
          'email': _emailController.text.trim(),
          'unit_id': _unitId,
          'rent_share_pct': _shareController.text.trim(),
          'due_day': int.tryParse(_dueDayController.text.trim()) ?? 5,
        },
      );
      if (!mounted) return;
      final link = res.data['invite_link']?.toString();
      final token = res.data['invite_token']?.toString();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invite sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email invite was sent to the tenant.'),
              if (link != null && link.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Share link:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SelectableText(link, style: const TextStyle(fontSize: 12)),
              ],
              if (token != null) ...[
                const SizedBox(height: 8),
                Text('Token: $token', style: const TextStyle(fontSize: 11)),
              ],
            ],
          ),
          actions: [
            if (link != null)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                },
                child: const Text('Copy link'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = 'Failed to send invite.';
      if (data is Map) {
        if (data['detail'] != null) {
          msg = data['detail'].toString();
        } else if (data['non_field_errors'] is List &&
            (data['non_field_errors'] as List).isNotEmpty) {
          msg = data['non_field_errors'][0].toString();
        } else if (data['email'] is List) {
          msg = data['email'][0].toString();
        } else if (data['unit_id'] is List) {
          msg = data['unit_id'][0].toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: context.accentRed()),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Tenant',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: context.mutedBodyStyle),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadUnits, child: const Text('Retry')),
                    ],
                  ),
                )
              : _units.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.door_front_door_outlined,
                              size: 56,
                              color: context.colors.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No units yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add a unit to a building first, then invite a tenant.',
                              textAlign: TextAlign.center,
                              style: context.mutedBodyStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick a unit and send an invite. A lease is created '
                              'automatically for vacant units (rent = unit base rent).',
                              style: context.mutedBodyStyle.copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decoration('Tenant email'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              value: _unitId,
                              decoration: _decoration('Unit'),
                              items: _units.map((raw) {
                                final unit =
                                    Map<String, dynamic>.from(raw as Map);
                                return DropdownMenuItem<int>(
                                  value: unit['id'] as int,
                                  child: Text(
                                    _unitLabel(unit),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _unitId = v),
                              validator: (v) =>
                                  v == null ? 'Select a unit' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _dueDayController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _decoration(
                                'Rent due day',
                                hint: '1–28 (used if a new lease is created)',
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1 || n > 28) {
                                  return 'Enter a day between 1 and 28';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _shareController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: _decoration(
                                'Rent share %',
                                hint: 'e.g. 50 for half the rent',
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null) return 'Enter a number';
                                if (n <= 0 || n > 100) {
                                  return 'Must be between 0 and 100';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _sending ? null : _sendInvite,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _sending
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Send Invite',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: context.colors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.outlineVariant),
      ),
    );
  }
}
