import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';

class AddBuildingScreen extends StatefulWidget {
  const AddBuildingScreen({super.key});

  @override
  State<AddBuildingScreen> createState() => _AddBuildingScreenState();
}

class _AddBuildingScreenState extends State<AddBuildingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  String _selectedType = 'apartment';
  bool _isLoading = false;
  String? _errorMessage;

  int? _portfolioId;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio() async {
    try {
      final response = await apiClient.get('/api/v1/properties/portfolios/');
      final portfolios = response.data as List<dynamic>;
      if (portfolios.isNotEmpty && mounted) {
        setState(() => _portfolioId = portfolios.first['id'] as int);
      }
    } catch (_) {}
  }

  Future<int> _ensurePortfolio() async {
    if (_portfolioId != null) return _portfolioId!;

    final response = await apiClient.get('/api/v1/properties/portfolios/');
    final portfolios = response.data as List<dynamic>;
    if (portfolios.isNotEmpty) {
      final id = portfolios.first['id'] as int;
      if (mounted) setState(() => _portfolioId = id);
      return id;
    }

    final created = await apiClient.post(
      '/api/v1/properties/portfolios/',
      data: {'name': 'My Portfolio'},
    );
    final id = created.data['id'] as int;
    if (mounted) setState(() => _portfolioId = id);
    return id;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final portfolioId = await _ensurePortfolio();
      await apiClient.post(
        '/api/v1/properties/buildings/',
        data: {
          'portfolio': portfolioId,
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'type': _selectedType,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (err) {
      setState(() {
        _errorMessage = err.response?.data.toString() ??
            'Failed to add building. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brandText;
    final accent = context.accentBlue();
    final errColor = context.accentRed();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Building',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: brand.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.apartment_rounded, color: brand, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fill in the building details below.',
                        style: TextStyle(fontSize: 13, color: brand),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('Building Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hint: 'e.g. Sunshine Apartments',
                  icon: Icons.apartment_rounded,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Building name is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Address'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.next,
                maxLines: 2,
                decoration: _inputDecoration(
                  hint: 'e.g. 123 Main Street',
                  icon: Icons.location_on_outlined,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Address is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('City'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.done,
                decoration: _inputDecoration(
                  hint: 'e.g. Mumbai',
                  icon: Icons.location_city_outlined,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'City is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Building Type'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.category_outlined,
                        color: accent, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'apartment',
                      child: Text('Apartment'),
                    ),
                    DropdownMenuItem(
                      value: 'house',
                      child: Text('House'),
                    ),
                    DropdownMenuItem(
                      value: 'commercial',
                      child: Text('Commercial'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: errColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: errColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: errColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        context.colors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add Building',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.onSurface,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    final accent = context.accentBlue();
    final errColor = context.accentRed();
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: accent, size: 20),
      hintStyle: TextStyle(
        color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      filled: true,
      fillColor: context.colors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errColor, width: 1.5),
      ),
    );
  }
}
