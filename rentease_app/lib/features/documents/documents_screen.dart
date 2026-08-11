import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme/app_surfaces.dart';

class DocumentsScreen extends StatefulWidget {
  final bool isOwner;
  final int? unitId;
  final String? unitNumber;

  const DocumentsScreen({
    super.key,
    required this.isOwner,
    this.unitId,
    this.unitNumber,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<dynamic> _docs = [];
  List<Map<String, dynamic>> _units = [];
  int? _selectedUnitId;
  String? _selectedUnitLabel;
  bool _isLoading = true;
  bool _uploading = false;
  String? _error;

  String get _listPath =>
      widget.isOwner ? '/api/v1/documents/owner/' : '/api/v1/documents/my/';

  @override
  void initState() {
    super.initState();
    _selectedUnitId = widget.unitId;
    _selectedUnitLabel = widget.unitNumber;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (widget.isOwner) {
        await _loadOwnerUnits();
        // If opened from menu with no unit, keep "All units" (null) for list
      } else {
        await _resolveTenantUnit();
      }
      await _loadDocs();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOwnerUnits() async {
    final res = await apiClient.get('/api/v1/properties/units/');
    final list = (res.data as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (!mounted) return;
    setState(() => _units = list);

    // Prefill label if we were given a unit id
    if (_selectedUnitId != null) {
      final match = list.where((u) => u['id'] == _selectedUnitId).toList();
      if (match.isNotEmpty) {
        final u = match.first;
        final building = u['building_name']?.toString() ?? '';
        final num = u['unit_number']?.toString() ?? '';
        _selectedUnitLabel =
            building.isNotEmpty ? 'Unit $num · $building' : 'Unit $num';
      }
    }
  }

  Future<void> _resolveTenantUnit() async {
    try {
      final unitRes = await apiClient.get('/api/v1/properties/my-unit/');
      final data = unitRes.data as Map<String, dynamic>;
      _selectedUnitId = data['id'] as int?;
      _selectedUnitLabel = data['unit_number']?.toString();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('No active unit on your lease. Ask your owner to invite you.');
      }
      rethrow;
    }
  }

  Future<void> _loadDocs() async {
    try {
      final res = await apiClient.get(
        _listPath,
        queryParameters: _selectedUnitId != null
            ? {'unit_id': _selectedUnitId}
            : null,
      );
      if (!mounted) return;
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['results'] as List? ?? []) : <dynamic>[]);
      setState(() {
        _docs = list;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      setState(() => _error = detail ?? 'Could not load documents.');
    }
  }

  Future<void> _pickUnitForUpload() async {
    if (_units.isEmpty) {
      await _loadOwnerUnits();
    }
    if (!mounted) return;
    if (_units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a unit first, then upload documents for it.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Upload document for which unit?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _units.length,
                  itemBuilder: (_, i) {
                    final u = _units[i];
                    final building = u['building_name']?.toString() ?? '';
                    final num = u['unit_number']?.toString() ?? '—';
                    final label = building.isNotEmpty
                        ? 'Unit $num · $building'
                        : 'Unit $num';
                    return ListTile(
                      leading: const Icon(Icons.door_front_door_outlined),
                      title: Text(label),
                      onTap: () => Navigator.pop(ctx, u),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (chosen != null) {
      setState(() {
        _selectedUnitId = chosen['id'] as int?;
        final building = chosen['building_name']?.toString() ?? '';
        final num = chosen['unit_number']?.toString() ?? '';
        _selectedUnitLabel =
            building.isNotEmpty ? 'Unit $num · $building' : 'Unit $num';
      });
      await _loadDocs();
      await _upload(skipUnitPick: true);
    }
  }

  Future<void> _upload({bool skipUnitPick = false}) async {
    if (widget.isOwner && _selectedUnitId == null && !skipUnitPick) {
      await _pickUnitForUpload();
      return;
    }

    if (!widget.isOwner && _selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active unit found for your account.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read that file. Try another file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    final titleController = TextEditingController(
      text: result.files.single.name.split('.').first,
    );
    var docType = widget.isOwner ? 'lease' : 'id_proof';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Upload document'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedUnitLabel != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Unit: $_selectedUnitLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<String>(
                    initialSelection: docType,
                    label: const Text('Type'),
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 'lease', label: 'Lease'),
                      DropdownMenuEntry(value: 'id_proof', label: 'ID proof'),
                      DropdownMenuEntry(
                          value: 'move_in', label: 'Move-in checklist'),
                      DropdownMenuEntry(
                          value: 'move_out', label: 'Move-out checklist'),
                      DropdownMenuEntry(value: 'other', label: 'Other'),
                    ],
                    onSelected: (v) {
                      if (v != null) setLocal(() => docType = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final form = FormData.fromMap({
        'unit': _selectedUnitId,
        'title': titleController.text.trim(),
        'doc_type': docType,
        'file': await MultipartFile.fromFile(
          path,
          filename: result.files.single.name,
        ),
      });
      await apiClient.post(_listPath, data: form);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded'),
          backgroundColor: Color(0xFF388E3C),
        ),
      );
      await _loadDocs();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = 'Upload failed';
      if (data is Map) {
        msg = data['detail']?.toString() ??
            data['file']?.toString() ??
            data['unit']?.toString() ??
            msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
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
      await apiClient.delete('/api/v1/documents/$id/');
      await _loadDocs();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _selectedUnitLabel != null
        ? 'Documents · $_selectedUnitLabel'
        : 'Documents';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : () => _upload(),
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? 'Uploading…' : 'Upload'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary))
          : Column(
              children: [
                if (widget.isOwner && _units.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownMenu<int?>(
                      key: ValueKey(_selectedUnitId),
                      initialSelection: _selectedUnitId,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Filter by unit'),
                      dropdownMenuEntries: [
                        const DropdownMenuEntry<int?>(
                          value: null,
                          label: 'All units',
                        ),
                        ..._units.map((u) {
                          final building = u['building_name']?.toString() ?? '';
                          final num = u['unit_number']?.toString() ?? '—';
                          final label = building.isNotEmpty
                              ? 'Unit $num · $building'
                              : 'Unit $num';
                          return DropdownMenuEntry<int?>(
                            value: u['id'] as int,
                            label: label,
                          );
                        }),
                      ],
                      onSelected: (v) async {
                        setState(() {
                          _selectedUnitId = v;
                          if (v == null) {
                            _selectedUnitLabel = null;
                          } else {
                            final match =
                                _units.firstWhere((u) => u['id'] == v);
                            final building =
                                match['building_name']?.toString() ?? '';
                            final num = match['unit_number']?.toString() ?? '';
                            _selectedUnitLabel = building.isNotEmpty
                                ? 'Unit $num · $building'
                                : 'Unit $num';
                          }
                          _isLoading = true;
                        });
                        await _loadDocs();
                        if (mounted) setState(() => _isLoading = false);
                      },
                    ),
                  ),
                if (!widget.isOwner && _selectedUnitLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Your unit: $_selectedUnitLabel',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _bootstrap,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDocs,
                          color: context.colors.primary,
                          child: _docs.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 100),
                                    Icon(
                                      Icons.folder_open_outlined,
                                      size: 56,
                                      color: context.colors.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.isOwner
                                          ? 'No documents yet.\nTap Upload and choose a unit.'
                                          : 'No documents yet.\nYou can upload your ID proof here.',
                                      textAlign: TextAlign.center,
                                      style: context.mutedBodyStyle,
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                                  itemCount: _docs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final d = Map<String, dynamic>.from(
                                        _docs[i] as Map);
                                    final fileUrl = d['file_url']?.toString() ??
                                        d['file']?.toString();
                                    return Container(
                                      decoration:
                                          context.cardDecoration(radius: 14),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        leading: Icon(Icons.description_outlined,
                                            color: scheme.primary),
                                        title: Text(
                                          d['title']?.toString() ?? 'Document',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.onSurface,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${d['doc_type'] ?? ''} · unit ${d['unit_number'] ?? '—'}',
                                          style: context.mutedBodyStyle,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (widget.isOwner)
                                              IconButton(
                                                icon: Icon(
                                                    Icons.delete_outline,
                                                    color: context.accentRed()),
                                                onPressed: () =>
                                                    _delete(d['id'] as int),
                                              ),
                                            Icon(
                                              Icons.open_in_new,
                                              size: 18,
                                              color: context
                                                  .colors.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                        onTap: () => _openFile(fileUrl),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
    );
  }
}
