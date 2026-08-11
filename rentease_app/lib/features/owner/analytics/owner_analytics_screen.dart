import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class OwnerAnalyticsScreen extends StatefulWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  State<OwnerAnalyticsScreen> createState() => _OwnerAnalyticsScreenState();
}

class _OwnerAnalyticsScreenState extends State<OwnerAnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/billing/analytics/');
      if (!mounted) return;
      setState(() => _data = res.data as Map<String, dynamic>);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load analytics.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: context.colors.primary))
        : _error != null
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _load,
                color: context.colors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildExpenseSummary(),
                      const SizedBox(height: 24),
                      _buildPaymentBreakdown(),
                      const SizedBox(height: 24),
                      _buildMonthlyChart(),
                      const SizedBox(height: 24),
                      _buildExpenseByCategory(),
                      const SizedBox(height: 24),
                      _buildIssueBreakdown(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
  }

  // ─── Summary Cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: context.sectionTitleStyle.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.check_circle_rounded,
                label: 'Collected',
                value: '₹${_formatAmount(summary['total_collected'])}',
                color: context.accentGreen(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.hourglass_empty_rounded,
                label: 'Pending',
                value: '₹${_formatAmount(summary['total_pending'])}',
                color: context.accentOrange(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.warning_rounded,
                label: 'Overdue',
                value: '₹${_formatAmount(summary['total_overdue'])}',
                color: context.accentRed(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.apartment_rounded,
                label: 'Active Leases',
                value: '${summary['active_leases'] ?? 0}',
                color: context.brandText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.build_rounded,
                label: 'Total Issues',
                value: '${summary['total_issues'] ?? 0}',
                color: context.isDark
                    ? const Color(0xFFCE93D8)
                    : const Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.report_problem_rounded,
                label: 'Open Issues',
                value: '${summary['open_issues'] ?? 0}',
                color: context.accentOrange(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseSummary() {
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_down_rounded,
            label: 'Expenses',
            value: '₹${_formatAmount(summary['total_expenses'])}',
            color: context.accentRed(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance_rounded,
            label: 'Net income',
            value: '₹${_formatAmount(summary['net_income'])}',
            color: context.accentBlue(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseByCategory() {
    final breakdown =
        _data?['expense_by_category'] as Map<String, dynamic>? ?? {};
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final entries = breakdown.entries.toList()
      ..sort((a, b) =>
          ((b.value as num?) ?? 0).compareTo((a.value as num?) ?? 0));
    final total = entries.fold<double>(
        0, (sum, e) => sum + ((e.value as num?)?.toDouble() ?? 0));

    final expenseColor = context.accentRed();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expenses by Category',
            style: context.cardTitleStyle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 16),
          ...entries.map((e) {
            final amount = (e.value as num?)?.toDouble() ?? 0;
            final pct = total > 0 ? amount / total : 0.0;
            final label = e.key.isEmpty
                ? 'Other'
                : e.key[0].toUpperCase() + e.key.substring(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.colors.onSurfaceVariant)),
                      Text('₹${_formatAmount(amount)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: expenseColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: context.softFill,
                      valueColor: AlwaysStoppedAnimation<Color>(expenseColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final breakdown = _data?['payment_breakdown'] as Map<String, dynamic>? ?? {};
    final paid = breakdown['paid'] as int? ?? 0;
    final pending = breakdown['pending'] as int? ?? 0;
    final overdue = breakdown['overdue'] as int? ?? 0;
    final total = paid + pending + overdue;
    if (total == 0) return const SizedBox.shrink();

    final items = [
      {'label': 'Paid', 'count': paid, 'color': context.accentGreen()},
      {'label': 'Pending', 'count': pending, 'color': context.accentOrange()},
      {'label': 'Overdue', 'count': overdue, 'color': context.accentRed()},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rent Share Status',
            style: context.cardTitleStyle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '$total shares across invoices',
            style: context.mutedBodyStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final count = item['count'] as int;
            final pct = count / total;
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['label'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.colors.onSurfaceVariant)),
                      Text('$count',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: context.softFill,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Monthly Bar Chart ──────────────────────────────────────────────────────

  Widget _buildMonthlyChart() {
    final trend = (_data?['monthly_trend'] as List<dynamic>?) ?? [];
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxY = trend
        .map((e) {
          final c = (e['collected'] as num?)?.toDouble() ?? 0;
          final x = (e['expenses'] as num?)?.toDouble() ?? 0;
          return c > x ? c : x;
        })
        .fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY == 0 ? 10000.0 : maxY * 1.3;

    final collectedColor = context.brandText;
    final expenseColor = context.accentRed();
    final muted = context.colors.onSurfaceVariant;
    final gridColor = context.colors.outlineVariant;

    final barGroups = trend.asMap().entries.map((entry) {
      final collected = (entry.value['collected'] as num?)?.toDouble() ?? 0;
      final expenses = (entry.value['expenses'] as num?)?.toDouble() ?? 0;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: collected,
            color: collectedColor,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: expenses,
            color: expenseColor,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Income vs Expenses',
            style: context.cardTitleStyle.copyWith(fontSize: 15),
          ),
          Text(
            'Last 6 months · blue = collected, red = expenses',
            style: context.mutedBodyStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: chartMax / 4,
                      getTitlesWidget: (value, meta) => Text(
                        '₹${_formatAmount(value)}',
                        style: TextStyle(fontSize: 9, color: muted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                        final label = (trend[idx]['month'] as String).split(' ')[0];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = trend[group.x]['month'] as String;
                      final label = rodIndex == 0 ? 'Collected' : 'Expenses';
                      return BarTooltipItem(
                        '$month\n$label ₹${_formatAmount(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Issue Breakdown ────────────────────────────────────────────────────────

  Widget _buildIssueBreakdown() {
    final breakdown = _data?['issue_breakdown'] as Map<String, dynamic>? ?? {};
    final total = (breakdown.values.fold<int>(0, (sum, v) => sum + (v as int)));

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: context.cardDecoration(radius: 20),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: context.accentGreen(), size: 28),
            const SizedBox(width: 12),
            Text('No issues raised yet — all clear!',
                style: TextStyle(
                    fontSize: 14,
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final items = [
      {'label': 'Open', 'key': 'open', 'color': context.accentOrange()},
      {'label': 'In Progress', 'key': 'in_progress', 'color': context.accentBlue()},
      {'label': 'Resolved', 'key': 'resolved', 'color': context.accentGreen()},
      {
        'label': 'Closed',
        'key': 'closed',
        'color': context.colors.onSurfaceVariant
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issues Breakdown',
            style: context.cardTitleStyle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final count = breakdown[item['key']] as int? ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['label'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.colors.onSurfaceVariant)),
                      Text('$count',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: context.softFill,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatAmount(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    if (num >= 100000) return '${(num / 100000).toStringAsFixed(1)}L';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toStringAsFixed(0);
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
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card Widget ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: context.mutedBodyStyle.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
