import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class TenantBillingScreen extends StatefulWidget {
  const TenantBillingScreen({super.key});

  @override
  State<TenantBillingScreen> createState() => _TenantBillingScreenState();
}

class _TenantBillingScreenState extends State<TenantBillingScreen> {
  Map<String, dynamic>? _currentShare;
  Map<String, dynamic>? _ownerPayInfo;
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isPaying = false;
  String? _error;
  late Razorpay _razorpay;
  int? _pendingShareId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _loadData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
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
        apiClient.get('/api/v1/billing/owner-payment-info/').catchError(
              (e) => Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: 404,
                data: null,
              ),
            ),
      ]);
      if (!mounted) return;
      setState(() {
        final currentData = results[0].data;
        _currentShare =
            (currentData is Map) ? currentData as Map<String, dynamic> : null;
        _history = results[1].data as List<dynamic>? ?? [];
        final payInfo = results[2].data;
        _ownerPayInfo =
            (payInfo is Map) ? Map<String, dynamic>.from(payInfo) : null;
      });
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load billing data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _payNow() async {
    if (_currentShare == null || _isPaying) return;
    final shareId = _currentShare!['id'] as int;

    setState(() => _isPaying = true);
    try {
      // Razorpay order API can be slow; don't use the default 10s client timeout.
      final res = await apiClient.post(
        '/api/v1/billing/pay/$shareId/create-order/',
        options: Options(
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
      if (!mounted) return;

      final data = Map<String, dynamic>.from(res.data as Map);
      final keyId = data['key_id']?.toString() ?? '';
      final orderId = data['order_id']?.toString() ?? '';
      final amountRaw = data['amount'];
      final amount = amountRaw is int
          ? amountRaw
          : int.tryParse(amountRaw.toString()) ?? 0;

      if (keyId.isEmpty || orderId.isEmpty || amount < 100) {
        throw Exception('Invalid order response from server.');
      }

      final prefill = Map<String, dynamic>.from(
        (data['prefill'] as Map?) ?? {},
      );
      // UPI intent apps (PhonePe/Paytm/GPay) often need a contact number.
      final contact = prefill['contact']?.toString().trim() ?? '';
      if (contact.isEmpty) {
        prefill['contact'] = '9999999999';
      }
      prefill.removeWhere(
        (key, value) =>
            key != 'contact' &&
            (value == null || value.toString().trim().isEmpty),
      );

      _pendingShareId = shareId;

      final options = <String, dynamic>{
        'key': keyId,
        'amount': amount,
        'currency': data['currency'] ?? 'INR',
        'name': 'RentEase',
        'description': data['description'] ?? 'Rent payment',
        'order_id': orderId,
        'timeout': 300,
        'theme': {'color': '#1A3C6E'},
        'prefill': prefill,
        // Explicitly allow common India methods
        'method': {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
        },
      };

      // Stop spinner as soon as checkout is launched.
      setState(() => _isPaying = false);
      _razorpay.open(options);
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'Could not start payment.';
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        msg = 'Payment server timed out. Check internet and try again.';
      } else if (e.response?.data is Map &&
          e.response?.data['detail'] != null) {
        msg = e.response!.data['detail'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
      setState(() => _isPaying = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isPaying = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _verifyAfterCheckout(response);
  }

  Future<void> _verifyAfterCheckout(PaymentSuccessResponse response) async {
    final shareId = _pendingShareId ?? _currentShare?['id'];
    try {
      await apiClient.post(
        '/api/v1/billing/pay/verify/',
        data: {
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
          'rent_share_id': shareId,
        },
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
      final msg = e.response?.data?['detail'] ??
          'Paid, but verification failed. Contact owner if status stays unpaid.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.orange),
      );
      await _loadData();
    } finally {
      _pendingShareId = null;
      if (mounted) setState(() => _isPaying = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingShareId = null;
    if (!mounted) return;
    setState(() => _isPaying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message?.isNotEmpty == true
              ? response.message!
              : 'Payment cancelled or failed.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
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
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: context.colors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentInvoiceCard(),
                        if (_currentShare != null) ...[
                          const SizedBox(height: 20),
                          _buildOwnerPaymentDetails(),
                        ],
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
        decoration: context.cardDecoration(radius: 20),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 52, color: context.accentGreen()),
            const SizedBox(height: 12),
            Text(
              'No pending payment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'re all caught up!',
              style: context.mutedBodyStyle,
            ),
          ],
        ),
      );
    }

    final amount = _currentShare!['amount'] ?? '—';
    final status = _currentShare!['status'] ?? 'pending';
    final dueDate = _currentShare!['due_date'] ?? '—';
    final period =
        '${_currentShare!['period_start'] ?? ''} → ${_currentShare!['period_end'] ?? ''}';
    final unit = _currentShare!['unit_number'] ?? '—';
    final pct = _currentShare!['rent_share_pct'];
    final invoiceTotal = _currentShare!['invoice_total'];
    final co = _currentShare!['co_tenants_pending'] as Map?;
    final othersPending = co?['pending'] as int? ?? 0;
    final othersTotal = co?['total_others'] as int? ?? 0;

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
                .withValues(alpha: 0.25),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
          if (pct != null || invoiceTotal != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (pct != null) 'Your share: $pct%',
                if (invoiceTotal != null) 'of ₹$invoiceTotal total',
              ].join(' '),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (othersTotal > 0) ...[
            const SizedBox(height: 4),
            Text(
              othersPending > 0
                  ? '$othersPending of $othersTotal co-tenant share(s) still unpaid'
                  : 'All co-tenant shares paid',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
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
          const SizedBox(height: 8),
          Text(
            _razorpayAvailable
                ? 'Pay online with Razorpay, or use UPI / bank / QR below'
                : 'Pay via owner UPI / bank / QR below, then ask owner to mark paid',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (_razorpayAvailable) ...[
            const SizedBox(height: 16),
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
                        isOverdue
                            ? 'Pay online (Overdue)'
                            : 'Pay with Razorpay',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _razorpayAvailable =>
      _ownerPayInfo?['razorpay_available'] == true;

  bool get _hasManualPay => _ownerPayInfo?['has_manual_details'] == true;

  Widget _buildOwnerPaymentDetails() {
    if (_ownerPayInfo == null || (!_hasManualPay && !_razorpayAvailable)) {
      final warn = context.accentOrange();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: warn.withValues(alpha: context.isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: warn.withValues(alpha: 0.45)),
        ),
        child: Text(
          'Owner has not added payment details yet. Ask them to add UPI / bank / QR or Razorpay in Payment settings.',
          style: TextStyle(color: warn, fontSize: 13),
        ),
      );
    }
    if (!_hasManualPay) {
      return const SizedBox.shrink();
    }

    final upi = _ownerPayInfo!['upi_id']?.toString() ?? '';
    final holder = _ownerPayInfo!['account_holder_name']?.toString() ?? '';
    final bank = _ownerPayInfo!['bank_name']?.toString() ?? '';
    final account = _ownerPayInfo!['account_number']?.toString() ?? '';
    final ifsc = _ownerPayInfo!['ifsc_code']?.toString() ?? '';
    final notes = _ownerPayInfo!['payment_notes']?.toString() ?? '';
    final qr = _ownerPayInfo!['qr_code_url']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: context.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay owner directly',
            style: context.sectionTitleStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'Transfer rent using these details. Owner will mark it paid after receiving.',
            style: context.mutedBodyStyle.copyWith(fontSize: 12),
          ),
          if (qr.isNotEmpty) ...[
            const SizedBox(height: 14),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  qr,
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.qr_code_2_rounded,
                    size: 64,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (upi.isNotEmpty) _copyRow('UPI ID', upi),
          if (holder.isNotEmpty) _copyRow('Account name', holder),
          if (bank.isNotEmpty) _copyRow('Bank', bank),
          if (account.isNotEmpty) _copyRow('Account no.', account),
          if (ifsc.isNotEmpty) _copyRow('IFSC', ifsc),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: context.mutedBodyStyle.copyWith(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.mutedBodyStyle.copyWith(fontSize: 11),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.brandText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment History',
          style: context.sectionTitleStyle.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No payment history yet.',
                style: context.mutedBodyStyle.copyWith(fontSize: 14),
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
              final statusColor = isPaid
                  ? context.accentGreen()
                  : isOverdue
                      ? context.accentRed()
                      : context.accentOrange();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: context.cardDecoration(),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : isOverdue
                                ? Icons.warning_rounded
                                : Icons.hourglass_empty_rounded,
                        color: statusColor,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: context.brandText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due: ${share['due_date'] ?? '—'}',
                            style: context.mutedBodyStyle.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${share['amount'] ?? '—'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: context.brandText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (share['status'] as String).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
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
            onPressed: _loadData,
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
