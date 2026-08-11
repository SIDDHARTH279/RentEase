import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class TenantIssuesScreen extends StatefulWidget {
  const TenantIssuesScreen({super.key});

  @override
  State<TenantIssuesScreen> createState() => _TenantIssuesScreenState();
}

class _TenantIssuesScreenState extends State<TenantIssuesScreen> {
  List<dynamic> _issues = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await apiClient.get('/api/v1/issues/my-issues/');
      if (!mounted) return;
      setState(() => _issues = res.data as List<dynamic>? ?? []);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load issues.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRaiseIssueSheet() async {
    final raised = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RaiseIssueSheet(),
    );
    if (raised == true) _loadIssues();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Issues', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRaiseIssueSheet,
        icon: const Icon(Icons.add),
        label: const Text('Raise Issue', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary))
          : _error != null
          ? _buildError()
          : RefreshIndicator(
        onRefresh: _loadIssues,
        color: context.colors.primary,
        child: _issues.isEmpty ? _buildEmpty() : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _issues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _IssueCard(issue: _issues[i]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.build_outlined,
            size: 64,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No issues raised yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the button below to report a problem.',
            style: context.mutedBodyStyle,
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

// ─── Issue Card ───────────────────────────────────────────────────────────────

class _IssueCard extends StatelessWidget {
  final Map<String, dynamic> issue;
  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    final status = issue['status'] as String? ?? 'open';
    final category = issue['category'] as String? ?? 'other';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'in_progress':
        statusColor = context.accentBlue();
        statusIcon = Icons.engineering_rounded;
        break;
      case 'resolved':
        statusColor = context.accentGreen();
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'closed':
        statusColor = context.colors.onSurfaceVariant;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = context.accentOrange();
        statusIcon = Icons.report_problem_rounded;
    }

    final categoryIcons = {
      'plumbing': Icons.water_drop_outlined,
      'electrical': Icons.bolt_outlined,
      'carpentry': Icons.carpenter,
      'cleaning': Icons.cleaning_services_outlined,
      'other': Icons.build_outlined,
    };

    return Container(
      decoration: context.cardDecoration(radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcons[category] ?? Icons.build_outlined, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((issue['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                issue['description'] as String,
                style: context.mutedBodyStyle,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.category_outlined,
                    size: 13, color: context.colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  category.toUpperCase(),
                  style: context.mutedBodyStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time_rounded,
                    size: 13, color: context.colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  (issue['created_at'] as String? ?? '').substring(0, 10),
                  style: context.mutedBodyStyle.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Raise Issue Bottom Sheet ─────────────────────────────────────────────────

class _RaiseIssueSheet extends StatefulWidget {
  const _RaiseIssueSheet();

  @override
  State<_RaiseIssueSheet> createState() => _RaiseIssueSheetState();
}

class _RaiseIssueSheetState extends State<_RaiseIssueSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'plumbing';
  File? _photo;
  bool _isSubmitting = false;
  int? _unitId;

  final _categories = ['plumbing', 'electrical', 'carpentry', 'cleaning', 'other'];

  @override
  void initState() {
    super.initState();
    _loadUnitId();
  }

  Future<void> _loadUnitId() async {
    try {
      final res = await apiClient.get('/api/v1/properties/my-unit/');
      if (mounted) setState(() => _unitId = res.data['id'] as int?);
    } catch (_) {}
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not find your unit. Try again.'),
          backgroundColor: context.accentRed(),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      FormData formData;
      if (_photo != null) {
        formData = FormData.fromMap({
          'unit': _unitId,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'category': _category,
          'photo': await MultipartFile.fromFile(_photo!.path),
        });
      } else {
        formData = FormData.fromMap({
          'unit': _unitId,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'category': _category,
        });
      }

      await apiClient.post('/api/v1/issues/my-issues/', data: formData);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Issue raised successfully!'),
          backgroundColor: context.accentGreen(),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?.toString() ?? 'Failed to raise issue.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: context.accentRed()),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Raise an Issue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Leaking tap in bathroom',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Describe the problem in detail...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c[0].toUpperCase() + c.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  height: _photo != null ? 160 : 80,
                  decoration: BoxDecoration(
                    color: context.softFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.outlineVariant),
                  ),
                  child: _photo != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photo!, fit: BoxFit.cover),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 30,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add Photo (optional)',
                        style: context.mutedBodyStyle,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Submit Issue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
