import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';
import 'add_expense_screen.dart';

class OwnerExpensesScreen extends StatefulWidget {
  const OwnerExpensesScreen({super.key});

  @override
  State<OwnerExpensesScreen> createState() => _OwnerExpensesScreenState();
}

class _OwnerExpensesScreenState extends State<OwnerExpensesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/expenses/');
      if (!mounted) return;
      setState(() => _items = res.data as List<dynamic>? ?? []);
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load expenses.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiClient.delete('/api/v1/expenses/$id/');
      _load();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed.'), backgroundColor: Colors.red),
      );
    }
  }

  String _catLabel(String c) {
    if (c.isEmpty) return 'Other';
    return c[0].toUpperCase() + c.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
                title: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
                icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary))
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colors.onSurfaceVariant),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: context.colors.primary,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No expenses yet.\nTrack maintenance, tax, utilities here.',
                                textAlign: TextAlign.center,
                                style: context.mutedBodyStyle,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final e = Map<String, dynamic>.from(_items[i] as Map);
                            final amount = e['amount']?.toString() ?? '0';
                            final dateStr = e['date']?.toString() ?? '';
                            String dateLabel = dateStr;
                            try {
                              final d = DateTime.parse(dateStr);
                              const months = [
                                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                              ];
                              dateLabel =
                                  '${d.day} ${months[d.month - 1]} ${d.year}';
                            } catch (_) {}
                            final building = e['building_name']?.toString() ?? '';
                            final unit = e['unit_number']?.toString();
                            final note = e['note']?.toString() ?? '';
                            return Container(
                              decoration: context.cardDecoration(radius: 14),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      context.brandText.withValues(alpha: 0.1),
                                  child: Icon(Icons.payments_outlined,
                                      color: context.brandText, size: 20),
                                ),
                                title: Text(
                                  '₹$amount · ${_catLabel(e['category']?.toString() ?? '')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: context.brandText,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    dateLabel,
                                    if (building.isNotEmpty) building,
                                    if (unit != null && unit.isNotEmpty) 'Unit $unit',
                                    if (note.isNotEmpty) note,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.mutedBodyStyle,
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: context.accentRed()),
                                  onPressed: () => _delete(e['id'] as int),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
