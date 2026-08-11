import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_utils.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../core/theme/theme_controller.dart';
import '../../activity/notification_bell.dart';
import '../analytics/owner_analytics_screen.dart';
import '../billing/owner_leases_screen.dart';
import '../issues/owner_issues_screen.dart';
import '../properties/add_building_screen.dart';
import '../properties/buildings_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final _storage = const FlutterSecureStorage();
  int _selectedIndex = 0;
  String _displayName = 'Owner';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final first = await _storage.read(key: 'user_first_name') ?? '';
    final last = await _storage.read(key: 'user_last_name') ?? '';
    final phone = await _storage.read(key: 'user_phone') ?? '';
    final name = '$first $last'.trim();
    if (!mounted) return;
    setState(() {
      _displayName = name.isEmpty ? 'Owner' : name;
      _phone = phone;
    });
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _openProfile() async {
    await context.push('/profile');
    await _loadProfile();
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.home_work_rounded, size: 22),
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
            onPressed: () => context.push('/chat'),
            tooltip: 'Messages',
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
                context.push('/documents', extra: {'isOwner': true});
              }
              if (value == 'razorpay') {
                context.push('/owner/razorpay-settings');
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
                                    fontSize: 11, color: Colors.grey.shade600)),
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
                value: 'razorpay',
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Payment settings'),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            displayName: _displayName,
            phone: _phone,
            onOpenProperties: () => _onNavTap(1),
            onOpenPayments: () => _onNavTap(2),
          ),
          const BuildingsScreen(),
          const OwnerLeasesScreen(),
          const OwnerAnalyticsScreen(),
          const OwnerIssuesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment_rounded),
            label: 'Properties',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build_rounded),
            label: 'Issues',
          ),
        ],
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final String displayName;
  final String phone;
  final VoidCallback onOpenProperties;
  final VoidCallback onOpenPayments;

  const _HomeTab({
    required this.displayName,
    required this.phone,
    required this.onOpenProperties,
    required this.onOpenPayments,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final res = await apiClient.get('/api/v1/billing/analytics/');
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _summary = Map<String, dynamic>.from(
            data['summary'] as Map? ?? {});
      });
    } on DioException {
      // keep zeros / empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _num(dynamic v) => '${v ?? 0}';

  String _money(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '') ?? 0;
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  Future<void> _addProperty() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
    );
    if (added == true) {
      widget.onOpenProperties();
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDark;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: scheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF152033), Color(0xFF1E3A5F)]
                      : const [Color(0xFF1A3C6E), Color(0xFF2E6DA4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: isDark
                    ? Border.all(color: scheme.outlineVariant)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${widget.displayName} 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.phone.isNotEmpty
                        ? widget.phone
                        : 'Here\'s your portfolio overview',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Overview', style: context.sectionTitleStyle),
            const SizedBox(height: 12),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.apartment_rounded,
                      label: 'Properties',
                      value: _num(_summary['total_buildings']),
                      color: isDark
                          ? const Color(0xFF64B5F6)
                          : const Color(0xFF2E6DA4),
                      onTap: widget.onOpenProperties,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.people_rounded,
                      label: 'Tenants',
                      value: _num(_summary['total_tenants']),
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF388E3C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Paid shares',
                      value: _num(_summary['paid_shares_count']),
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF388E3C),
                      onTap: widget.onOpenPayments,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Overdue',
                      value: _money(_summary['total_overdue']),
                      color: isDark
                          ? const Color(0xFFEF9A9A)
                          : const Color(0xFFD32F2F),
                      onTap: widget.onOpenPayments,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Quick Actions', style: context.sectionTitleStyle),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.add_home_rounded,
                    label: 'Add Property',
                    onTap: _addProperty,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.person_add_rounded,
                    label: 'Invite Tenant',
                    onTap: () => context.push('/invite-tenant'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Expenses',
                    onTap: () => context.push('/owner/expenses'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    onTap: () => context.push('/chat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: context.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.mutedBodyStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: context.cardDecoration(),
          child: Column(
            children: [
              Icon(icon, color: context.colors.primary, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
