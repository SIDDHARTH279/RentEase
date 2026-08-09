import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

class OwnerBillingScreen extends StatefulWidget {
  final int leaseId;
  final String unitNumber;

  const OwnerBillingScreen({
    super.key,
    required this.leaseId,
    required this.unitNumber,
  });

  @override
  State<OwnerBillingScreen> createState() => _OwnerBillingScreenState();
}

class _OwnerBillingScreenState extends State<OwnerBillingScreen> {
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await apiClient
          .get('/api/v1/billing/invoices/lease/${widget.leaseId}/');
      if (!mounted) return;
      setState(() => _invoices = res.data as List<dynamic>? ?? []);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load invoices.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInvoice() async {
    setState(() => _isGenerating = true);
    try {
      final res = await apiClient.post(
        '/api/v1/billing/invoices/lease/${widget.leaseId}/generate/',
      );
      if (!mounted) return;
      final created = res.data['created'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created
                ? 'Invoice generated!'
                : 'Invoice already exists for this month.',
          ),
          backgroundColor: created ? const Color(0xFF388E3C) : Colors.orange,
        ),
      );
      await _loadInvoices();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg =
          e.response?.data?['detail'] ?? 'Failed to generate invoice.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
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
        title: Text(
          'Unit ${widget.unitNumber} — Invoices',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _isGenerating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Generate Invoice',
                  onPressed: _generateInvoice,
                ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A3C6E)))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  color: const Color(0xFF1A3C6E),
                  child: _invoices.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _invoices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) =>
                              _buildInvoiceCard(_invoices[index]),
                        ),
                ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final status = invoice['status'] as String;
    final isPaid = status == 'paid';
    final isOverdue = status == 'overdue';
    final isCancelled = status == 'cancelled';

    Color statusColor;
    IconData statusIcon;
    if (isPaid) {
      statusColor = const Color(0xFF388E3C);
      statusIcon = Icons.check_circle_rounded;
    } else if (isOverdue) {
      statusColor = const Color(0xFFD32F2F);
      statusIcon = Icons.warning_rounded;
    } else if (isCancelled) {
      statusColor = Colors.grey;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFE65100);
      statusIcon = Icons.hourglass_empty_rounded;
    }

    final shares = invoice['shares'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${invoice['period_start']} → ${invoice['period_end']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A3C6E),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _infoChip(
                        Icons.currency_rupee_rounded,
                        '₹${invoice['total_amount']}',
                        'Total',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoChip(
                        Icons.calendar_today_rounded,
                        invoice['due_date'] ?? '—',
                        'Due Date',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (shares.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tenant Shares',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...shares.map((share) {
                    final shareStatus = share['status'] as String;
                    final shareIsPaid = shareStatus == 'paid';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            shareIsPaid
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: shareIsPaid
                                ? Colors.green.shade600
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              share['tenant_email'] ?? '—',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1A3C6E),
                              ),
                            ),
                          ),
                          Text(
                            '₹${share['amount']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: shareIsPaid
                                  ? Colors.green.shade700
                                  : const Color(0xFF1A3C6E),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E6DA4)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3C6E),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
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
            'No invoices yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3C6E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to generate this month\'s invoice',
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
            onPressed: _loadInvoices,
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
