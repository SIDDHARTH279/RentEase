import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

class TenantBillingScreen extends StatefulWidget {
  const TenantBillingScreen({super.key});

  @override
  State<TenantBillingScreen> createState() => _TenantBillingScreenState();
}

class _TenantBillingScreenState extends State<TenantBillingScreen> {
  Map<String, dynamic>? _currentShare;
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isPaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.get('/api/v1/billing/my-shares/current/').catchError(
              (e) => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 404,
            data: null,
          ),
        ),
        apiClient.get('/api/v1/billing/my-shares/'),
      ]);
      if (!mounted) return;
      setState(() {
        final currentData = results[0].data;
        _currentShare =
        (currentData is Map) ? currentData as Map<String, dynamic> : null;
        _history = results[1].data as List<dynamic>? ?? [];
      });
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load billing data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _payNow() async {
    if (_currentShare == null) return;
    final shareId = _currentShare!['id'];

    setState(() => _isPaying = true);
    try {
      await apiClient.post(
        '/api/v1/billing/pay/$shareId/',
        data: {'gateway_payment_id': 'flutter_pay_$shareId'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful!'),
          backgroundColor: Color(0xFF388E3C),
        ),
      );
      await _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? 'Payment failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Billing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A3C6E)),
      )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF1A3C6E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentInvoiceCard(),
              const SizedBox(height: 28),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentInvoiceCard() {
    if (_currentShare == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 52, color: Colors.green.shade400),
            const SizedBox(height: 12),
            const Text(
              'No pending payment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3C6E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'re all caught up!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final amount = _currentShare!['amount'] ?? '—';
    final status = _currentShare!['status'] ?? 'pending';
    final dueDate = _currentShare!['due_date'] ?? '—';
    final period = '${_currentShare!['period_start'] ?? ''} → ${_currentShare!['period_end'] ?? ''}';
    final unit = _currentShare!['unit_number'] ?? '—';

    final isOverdue = status == 'overdue';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverdue
              ? [const Color(0xFFB71C1C), const Color(0xFFD32F2F)]
              : [const Color(0xFF1A3C6E), const Color(0xFF2E6DA4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOverdue ? Colors.red : const Color(0xFF1A3C6E))
                .withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOverdue ? 'OVERDUE' : 'PAYMENT DUE',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Unit $unit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹$amount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Period: $period',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Due: $dueDate',
            style: TextStyle(
              color: isOverdue ? Colors.red.shade100 : Colors.white70,
              fontSize: 12,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isPaying ? null : _payNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isOverdue
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF1A3C6E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isPaying
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1A3C6E),
                ),
              )
                  : Text(
                isOverdue ? 'Pay Now (Overdue)' : 'Pay Now',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment History',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A3C6E),
          ),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No payment history yet.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final share = _history[index] as Map<String, dynamic>;
              final isPaid = share['status'] == 'paid';
              final isOverdue = share['status'] == 'overdue';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.shade50
                            : isOverdue
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : isOverdue
                            ? Icons.warning_rounded
                            : Icons.hourglass_empty_rounded,
                        color: isPaid
                            ? Colors.green.shade600
                            : isOverdue
                            ? Colors.red.shade600
                            : Colors.orange.shade600,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${share['period_start'] ?? ''} → ${share['period_end'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1A3C6E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due: ${share['due_date'] ?? '—'}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${share['amount'] ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A3C6E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.shade50
                                : isOverdue
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (share['status'] as String).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? Colors.green.shade700
                                  : isOverdue
                                  ? Colors.red.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
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
            onPressed: _loadData,
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
}