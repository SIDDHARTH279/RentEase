import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_portfolioId == null) {
      setState(() => _errorMessage = 'No portfolio found. Please create one first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await apiClient.post(
        '/api/v1/properties/buildings/',
        data: {
          'portfolio': _portfolioId,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3C6E),
        foregroundColor: Colors.white,
        elevation: 0,
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
              // header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C6E).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1A3C6E).withOpacity(0.12),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.apartment_rounded,
                        color: Color(0xFF1A3C6E), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fill in the building details below.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A3C6E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // building name
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

              // address
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

              // city
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

              // building type
              _buildLabel('Building Type'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.category_outlined,
                        color: Color(0xFF2E6DA4), size: 20),
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

              // error
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFD32F2F), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3C6E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF1A3C6E).withOpacity(0.5),
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2D3748),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF2E6DA4), size: 20),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF2E6DA4), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
    );
  }
}
