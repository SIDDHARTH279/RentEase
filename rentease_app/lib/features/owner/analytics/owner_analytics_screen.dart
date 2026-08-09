import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

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
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A3C6E)))
        : _error != null
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF1A3C6E),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildMonthlyChart(),
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
        const Text(
          'Overview',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A3C6E)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.check_circle_rounded,
                label: 'Collected',
                value: '₹${_formatAmount(summary['total_collected'])}',
                color: const Color(0xFF388E3C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.hourglass_empty_rounded,
                label: 'Pending',
                value: '₹${_formatAmount(summary['total_pending'])}',
                color: const Color(0xFFE65100),
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
                color: const Color(0xFFD32F2F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.apartment_rounded,
                label: 'Active Leases',
                value: '${summary['active_leases'] ?? 0}',
                color: const Color(0xFF1A3C6E),
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
                color: const Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.report_problem_rounded,
                label: 'Open Issues',
                value: '${summary['open_issues'] ?? 0}',
                color: const Color(0xFFE65100),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Monthly Bar Chart ──────────────────────────────────────────────────────

  Widget _buildMonthlyChart() {
    final trend = (_data?['monthly_trend'] as List<dynamic>?) ?? [];
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxY = trend
        .map((e) => (e['collected'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY == 0 ? 10000.0 : maxY * 1.3;

    final barGroups = trend.asMap().entries.map((entry) {
      final val = (entry.value['collected'] as num).toDouble();
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: val,
            color: const Color(0xFF1A3C6E),
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Collections',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A3C6E)),
          ),
          const Text(
            'Last 6 months',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    color: Colors.grey.shade100,
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
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
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
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                      return BarTooltipItem(
                        '$month\n₹${_formatAmount(rod.toY)}',
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF388E3C), size: 28),
            SizedBox(width: 12),
            Text('No issues raised yet — all clear!',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A3C6E), fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final items = [
      {'label': 'Open', 'key': 'open', 'color': const Color(0xFFE65100)},
      {'label': 'In Progress', 'key': 'in_progress', 'color': const Color(0xFF1565C0)},
      {'label': 'Resolved', 'key': 'resolved', 'color': const Color(0xFF388E3C)},
      {'label': 'Closed', 'key': 'closed', 'color': Colors.grey},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issues Breakdown',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A3C6E)),
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                      Text('$count',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3C6E),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
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
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
