import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class OwnerLeasesScreen extends StatefulWidget {
  const OwnerLeasesScreen({super.key});

  @override
  State<OwnerLeasesScreen> createState() => _OwnerLeasesScreenState();
}

class _OwnerLeasesScreenState extends State<OwnerLeasesScreen> {
  List<dynamic> _leases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeases();
  }

  Future<void> _loadLeases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/properties/leases/');
      if (!mounted) return;
      setState(() => _leases = res.data as List<dynamic>? ?? []);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load leases.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endTenancy(Map<String, dynamic> lease) async {
    final unit = lease['unit_number']?.toString() ?? '—';
    final leaseId = lease['id'];

    double unpaid = 0;
    try {
      final preview =
          await apiClient.get('/api/v1/properties/leases/$leaseId/end/');
      unpaid = (preview.data['unpaid_amount'] as num?)?.toDouble() ?? 0;
    } on DioException {
      // continue with generic confirm
    }

    if (!mounted) return;

    final hasUnpaid = unpaid > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasUnpaid ? 'Pending rent on this unit' : 'End tenancy?'),
        content: Text(
          hasUnpaid
              ? 'Unit $unit still has ₹${unpaid.toStringAsFixed(0)} unpaid rent '
                  '(pending/overdue).\n\n'
                  'If you end tenancy now, that unpaid rent will be removed from '
                  'analytics. Paid history is kept.\n\n'
                  'Do you still want to remove this tenant?'
              : 'This will end the lease for Unit $unit, mark the unit vacant, '
                  'and the tenant will no longer see an active lease. '
                  'Paid invoices stay for your records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              hasUnpaid ? 'End anyway & clear pending' : 'End tenancy',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await apiClient.post(
        '/api/v1/properties/leases/$leaseId/end/',
        data: {'clear_pending': true},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasUnpaid
                ? 'Tenancy ended. Pending rent cleared for Unit $unit.'
                : 'Tenancy ended for Unit $unit.',
          ),
        ),
      );
      _loadLeases();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detail ?? 'Could not end tenancy.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(
            child: CircularProgressIndicator(color: context.colors.primary))
        : _error != null
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _loadLeases,
                color: context.colors.primary,
                child: _leases.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _leases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildLeaseCard(_leases[i]),
                      ),
              );
  }

  Widget _buildLeaseCard(Map<String, dynamic> lease) {
    final status = lease['status'] as String? ?? 'active';
    final isActive = status == 'active';

    Color statusColor;
    if (isActive) {
      statusColor = context.accentGreen();
    } else if (status == 'ended' || status == 'expired') {
      statusColor = context.colors.onSurfaceVariant;
    } else {
      statusColor = context.accentOrange();
    }

    return Container(
      decoration: context.cardDecoration(radius: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
          '/owner/billing',
          extra: {
            'leaseId': lease['id'] as int,
            'unitNumber': lease['unit_number'] as String? ?? '—',
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.brandText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: context.brandText,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit ${lease['unit_number'] ?? '—'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: context.brandText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lease['building_name'] ?? '—',
                            style: context.mutedBodyStyle.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _detail(
                        Icons.currency_rupee_rounded,
                        '₹${lease['monthly_rent'] ?? '—'}',
                        'Monthly Rent',
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 32,
                        color: context.colors.outlineVariant),
                    Expanded(
                      child: _detail(
                        Icons.calendar_today_rounded,
                        _ordinal(lease['due_day'] as int? ?? 1),
                        'Due Day',
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 32,
                        color: context.colors.outlineVariant),
                    Expanded(
                      child: _detail(
                        Icons.date_range_rounded,
                        lease['start_date'] ?? '—',
                        'Start Date',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isActive)
                    TextButton(
                      onPressed: () => _endTenancy(lease),
                      style: TextButton.styleFrom(
                        foregroundColor: context.accentRed(),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'End tenancy',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    'View Invoices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.brandText.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: context.brandText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 15, color: context.accentBlue()),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: context.brandText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.mutedBodyStyle.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    final muted = context.colors.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: muted),
          const SizedBox(height: 16),
          Text(
            'No leases yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a lease to start tracking payments.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
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
          Text(_error!, style: TextStyle(color: muted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLeases,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
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
