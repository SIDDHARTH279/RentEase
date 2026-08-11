import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

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

  Future<void> _confirmMarkPaid(Map<String, dynamic> share) async {
    final name = share['tenant_name']?.toString().isNotEmpty == true
        ? share['tenant_name'].toString()
        : (share['tenant_email'] ?? 'tenant').toString();
    final amount = share['amount']?.toString() ?? '';
    String method = 'cash';
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Mark rent as paid'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record ₹$amount from $name as received.'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI / QR')),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Bank transfer'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => method = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Mark paid'),
                ),
              ],
            );
          },
        );
      },
    );

    final notes = notesController.text.trim();
    notesController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await apiClient.post(
        '/api/v1/billing/shares/${share['id']}/mark-paid/',
        data: {
          'method': method,
          if (notes.isNotEmpty) 'notes': notes,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as paid.'),
          backgroundColor: Color(0xFF388E3C),
        ),
      );
      await _loadInvoices();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? 'Could not mark as paid.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
      );
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
            appBar: AppBar(
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
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  color: context.colors.primary,
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
      statusColor = context.accentGreen();
      statusIcon = Icons.check_circle_rounded;
    } else if (isOverdue) {
      statusColor = context.accentRed();
      statusIcon = Icons.warning_rounded;
    } else if (isCancelled) {
      statusColor = context.colors.onSurfaceVariant;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = context.accentOrange();
      statusIcon = Icons.hourglass_empty_rounded;
    }

    final shares = invoice['shares'] as List<dynamic>? ?? [];

    return Container(
      decoration: context.cardDecoration(radius: 18),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.brandText,
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
            Divider(height: 1, color: context.colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tenant Shares',
                    style: context.mutedBodyStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...shares.map((share) {
                    final shareMap = Map<String, dynamic>.from(share as Map);
                    final shareStatus = shareMap['status'] as String;
                    final shareIsPaid = shareStatus == 'paid';
                    final name =
                        shareMap['tenant_name']?.toString().isNotEmpty == true
                            ? shareMap['tenant_name'].toString()
                            : (shareMap['tenant_email'] ?? '—').toString();
                    final pct = shareMap['rent_share_pct'];
                    final method = shareMap['payment_method']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            shareIsPaid
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: shareIsPaid
                                ? context.accentGreen()
                                : context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.brandText,
                                  ),
                                ),
                                Text(
                                  [
                                    if (pct != null) '$pct% share',
                                    shareStatus.toUpperCase(),
                                    if (shareIsPaid && method.isNotEmpty)
                                      method.replaceAll('_', ' '),
                                  ].join(' · '),
                                  style: context.mutedBodyStyle
                                      .copyWith(fontSize: 11),
                                ),
                                if (!shareIsPaid) ...[
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _confirmMarkPaid(shareMap),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: context.accentBlue(),
                                    ),
                                    icon: const Icon(Icons.payments_outlined,
                                        size: 16),
                                    label: const Text(
                                      'Mark paid',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '₹${shareMap['amount']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: shareIsPaid
                                  ? context.accentGreen()
                                  : context.brandText,
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
        color: context.softFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.accentBlue()),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.brandText,
                  ),
                ),
                Text(
                  label,
                  style: context.mutedBodyStyle.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
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
            'No invoices yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to generate this month\'s invoice',
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
            onPressed: _loadInvoices,
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
}
