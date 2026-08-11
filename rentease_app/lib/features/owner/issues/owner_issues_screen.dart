import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class OwnerIssuesScreen extends StatefulWidget {
  const OwnerIssuesScreen({super.key});

  @override
  State<OwnerIssuesScreen> createState() => _OwnerIssuesScreenState();
}

class _OwnerIssuesScreenState extends State<OwnerIssuesScreen> {
  List<dynamic> _issues = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all';

  final _statuses = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await apiClient.get('/api/v1/issues/all/');
      if (!mounted) return;
      setState(() => _issues = res.data as List<dynamic>? ?? []);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load issues.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredIssues {
    if (_filterStatus == 'all') return _issues;
    return _issues.where((i) => i['status'] == _filterStatus).toList();
  }

  Future<void> _updateStatus(int issueId, String newStatus) async {
    try {
      await apiClient.patch(
        '/api/v1/issues/$issueId/status/',
        data: {'status': newStatus},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.replaceAll('_', ' ')}'),
          backgroundColor: context.accentGreen(),
        ),
      );
      await _loadIssues();
    } on DioException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Failed to update status.'), backgroundColor: context.accentRed()),
      );
    }
  }

  void _showStatusPicker(Map<String, dynamic> issue) {
    final statuses = ['open', 'in_progress', 'resolved', 'closed'];
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: sheetCtx.colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...statuses.map((s) {
              final isCurrent = issue['status'] == s;
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: sheetCtx.brandText,
                ),
                title: Text(
                  s.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: sheetCtx.colors.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (!isCurrent) _updateStatus(issue['id'] as int, s);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: context.colors.primary))
        : _error != null
        ? _buildError()
        : Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadIssues,
            color: context.colors.primary,
            child: _filteredIssues.isEmpty
                ? _buildEmpty()
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredIssues.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildIssueCard(_filteredIssues[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statuses.map((s) {
            final isSelected = _filterStatus == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterStatus = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.primary
                        : context.softFill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? context.colors.onPrimary
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final status = issue['status'] as String? ?? 'open';

    Color statusColor;
    switch (status) {
      case 'in_progress':
        statusColor = context.accentBlue();
        break;
      case 'resolved':
        statusColor = context.accentGreen();
        break;
      case 'closed':
        statusColor = context.colors.onSurfaceVariant;
        break;
      default:
        statusColor = context.accentOrange();
    }

    return Container(
      decoration: context.cardDecoration(radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue['title'] ?? '—',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            if ((issue['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                issue['description'] as String,
                style: context.mutedBodyStyle,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 13, color: context.colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  issue['reported_by_email'] ?? '—',
                  style: context.mutedBodyStyle.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 12),
                Icon(Icons.door_front_door_outlined,
                    size: 13, color: context.colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Unit ${issue['unit_number'] ?? '—'}',
                  style: context.mutedBodyStyle.copyWith(fontSize: 11),
                ),
                const Spacer(),
                Text(
                  (issue['created_at'] as String? ?? '').substring(0, 10),
                  style: context.mutedBodyStyle.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showStatusPicker(issue),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Update Status'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.brandText,
                  side: BorderSide(color: context.brandText),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No issues found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text('All clear!', style: context.mutedBodyStyle),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(_error!, style: context.mutedBodyStyle),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadIssues,
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
