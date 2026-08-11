import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<dynamic> _buildings = [];
  List<dynamic> _units = [];
  int? _buildingId;
  int? _unitId;
  String _category = 'maintenance';
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _categories = [
    'maintenance',
    'plumbing',
    'painting',
    'electrical',
    'tax',
    'insurance',
    'utilities',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/properties/buildings/');
      if (!mounted) return;
      final list = res.data as List<dynamic>? ?? [];
      setState(() {
        _buildings = list;
        if (list.isNotEmpty) {
          _buildingId = (list.first as Map)['id'] as int;
          _loadUnits(_buildingId!);
        }
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load buildings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnits(int buildingId) async {
    try {
      final res = await apiClient.get(
        '/api/v1/properties/units/',
        queryParameters: {'building_id': buildingId},
      );
      if (!mounted) return;
      setState(() {
        _units = res.data as List<dynamic>? ?? [];
        _unitId = null;
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _units = []);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_buildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a property first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await apiClient.post(
        '/api/v1/expenses/',
        data: {
          'building': _buildingId,
          if (_unitId != null) 'unit': _unitId,
          'category': _category,
          'amount': _amountController.text.trim(),
          'date':
              '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          'note': _noteController.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?.toString() ?? 'Could not save expense.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(String c) => c[0].toUpperCase() + c.substring(1);

  String _monthShort(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
                title: const Text('Add expense'),
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          value: _buildingId,
                          decoration: InputDecoration(
                            labelText: 'Building',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: context.softFill,
                          ),
                          items: _buildings
                              .map((b) {
                                final m = b as Map;
                                return DropdownMenuItem<int>(
                                  value: m['id'] as int,
                                  child: Text(m['name']?.toString() ?? 'Building'),
                                );
                              })
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _buildingId = v);
                            _loadUnits(v);
                          },
                          validator: (v) =>
                              v == null ? 'Select a building' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int?>(
                          value: _unitId,
                          decoration: InputDecoration(
                            labelText: 'Unit (optional)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: context.softFill,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Whole building'),
                            ),
                            ..._units.map((u) {
                              final m = u as Map;
                              return DropdownMenuItem<int?>(
                                value: m['id'] as int,
                                child: Text('Unit ${m['unit_number']}'),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => _unitId = v),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: context.softFill,
                          ),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(_label(c)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _category = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: context.softFill,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: context.softFill,
                              suffixIcon: const Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              '${_date.day} ${_monthShort(_date.month)} ${_date.year}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Note (optional)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: context.softFill,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save expense'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
