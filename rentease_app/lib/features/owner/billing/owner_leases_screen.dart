import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

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

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A3C6E)))
        : _error != null
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _loadLeases,
                color: const Color(0xFF1A3C6E),
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
      statusColor = const Color(0xFF388E3C);
    } else if (status == 'expired') {
      statusColor = Colors.grey;
    } else {
      statusColor = const Color(0xFFE65100);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                          color: const Color(0xFF1A3C6E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF1A3C6E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit ${lease['unit_number'] ?? '—'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A3C6E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lease['building_name'] ?? '—',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
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
                  color: const Color(0xFFF5F7FA),
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
                        color: Colors.grey.shade200),
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
                        color: Colors.grey.shade200),
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
                  const Spacer(),
                  Text(
                    'View Invoices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A3C6E).withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF1A3C6E),
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
        Icon(icon, size: 15, color: const Color(0xFF2E6DA4)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A3C6E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No leases yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3C6E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a lease to start tracking payments.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLeases,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3C6E),
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
