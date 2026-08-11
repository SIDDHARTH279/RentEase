import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_utils.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../core/theme/theme_controller.dart';
import '../../activity/notification_bell.dart';
import '../../chat/tenant_chat_entry.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _lease;
  Map<String, dynamic>? _unit;
  bool _isLoading = true;
  String? _error;
  String _displayName = 'Tenant';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadData();
  }

  Future<void> _loadProfile() async {
    final first = await _storage.read(key: 'user_first_name') ?? '';
    final last = await _storage.read(key: 'user_last_name') ?? '';
    final phone = await _storage.read(key: 'user_phone') ?? '';
    final name = '$first $last'.trim();
    if (!mounted) return;
    setState(() {
      _displayName = name.isEmpty ? 'Tenant' : name;
      _phone = phone;
    });
  }

  Future<void> _openProfile() async {
    await context.push('/profile');
    await _loadProfile();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.get('/api/v1/properties/my-lease/'),
        apiClient.get('/api/v1/properties/my-unit/'),
      ]);
      if (!mounted) return;
      setState(() {
        _lease = results[0].data as Map<String, dynamic>;
        _unit = results[1].data as Map<String, dynamic>;
      });
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your lease details.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  int _daysUntilDue(int dueDay) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, dueDay);
    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = DateTime(now.year, now.month + 1, dueDay);
    }
    return next.difference(now).inDays;
  }

  Future<void> _cycleTheme() async {
    final c = ThemeController.instance;
    final next = switch (c.mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await c.setMode(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Theme: ${c.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.home_work_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'RentEase',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) {
              final mode = ThemeController.instance.mode;
              final icon = switch (mode) {
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
                ThemeMode.system => Icons.brightness_auto_outlined,
              };
              return IconButton(
                icon: Icon(icon),
                onPressed: _cycleTheme,
                tooltip: 'Theme: ${ThemeController.instance.label}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => openTenantChat(context),
            tooltip: 'Message Owner',
          ),
          const NotificationBell(),
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 16,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            onSelected: (value) {
              if (value == 'profile') _openProfile();
              if (value == 'documents') {
                context.push('/documents', extra: {'isOwner': false});
              }
              if (value == 'logout') logout(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (_phone.isNotEmpty)
                            Text(_phone,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'documents',
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Documents'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadProfile();
                    await _loadData();
                  },
                  color: context.colors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(),
                        const SizedBox(height: 20),
                        _buildRentCard(),
                        const SizedBox(height: 20),
                        _buildUnitCard(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    final muted = context.colors.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDark
              ? const [Color(0xFF152033), Color(0xFF1E3A5F)]
              : const [Color(0xFF1A3C6E), Color(0xFF2E6DA4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $_displayName 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _phone.isNotEmpty
                ? '$_phone · Unit ${_unit?['unit_number'] ?? '—'}'
                : 'Unit ${_unit?['unit_number'] ?? '—'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentCard() {
    final rent = _lease?['monthly_rent'] ?? '—';
    final dueDay = _lease?['due_day'] as int?;
    final daysLeft = dueDay != null ? _daysUntilDue(dueDay) : null;

    Color dueBadgeColor;
    String dueText;

    if (daysLeft == null) {
      dueBadgeColor = context.colors.onSurfaceVariant;
      dueText = 'Due day not set';
    } else if (daysLeft == 0) {
      dueBadgeColor = context.accentRed();
      dueText = 'Due today!';
    } else if (daysLeft <= 3) {
      dueBadgeColor = context.accentOrange();
      dueText = 'Due in $daysLeft day${daysLeft == 1 ? '' : 's'}';
    } else {
      dueBadgeColor = context.accentGreen();
      dueText = 'Due in $daysLeft days';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Rent',
                style: TextStyle(
                  fontSize: 14,
                  color: context.brandText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: dueBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dueText,
                  style: TextStyle(
                    fontSize: 11,
                    color: dueBadgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹$rent',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.brandText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dueDay != null
                ? 'Due on ${_ordinal(dueDay)} of every month'
                : 'Due day not set',
            style: context.mutedBodyStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/tenant/billing'),
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: const Text(
                'Pay Rent',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Unit',
            style: TextStyle(
              fontSize: 14,
              color: context.brandText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _unitDetail(
                  Icons.door_front_door_outlined,
                  'Unit',
                  _unit?['unit_number'] ?? '—',
                ),
              ),
              Expanded(
                child: _unitDetail(
                  Icons.layers_outlined,
                  'Floor',
                  '${_unit?['floor'] ?? '—'}',
                ),
              ),
              Expanded(
                child: _unitDetail(
                  Icons.bed_outlined,
                  'Bedrooms',
                  '${_unit?['bedrooms'] ?? '—'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.colors.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.monetization_on_outlined,
                  size: 16, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Security deposit: ₹${_unit?['deposit'] ?? '—'}',
                style: context.mutedBodyStyle.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: context.accentBlue(), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.brandText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.mutedBodyStyle.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: context.sectionTitleStyle),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.build_outlined,
                label: 'Raise Issue',
                color: context.accentOrange(),
                onTap: () => context.push('/tenant/issues'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.receipt_long_outlined,
                label: 'Payment History',
                color: context.accentGreen(),
                onTap: () => context.push('/tenant/billing'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message Owner',
                color: context.accentBlue(),
                onTap: () => openTenantChat(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: context.cardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
