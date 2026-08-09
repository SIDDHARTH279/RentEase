import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

class BuildingScreen extends StatefulWidget {
  final Map<String, dynamic> building;

  const BuildingScreen({super.key, required this.building});

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  List<dynamic> _units = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/properties/units/');
      if (!mounted) return;
      final all = res.data as List<dynamic>? ?? [];
      setState(() {
        _units = all
            .where((u) => u['building'] == widget.building['id'])
            .toList();
      });
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load units.');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.building['name'] ?? 'Building',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            if ((widget.building['city'] ?? '').toString().isNotEmpty)
              Text(
                widget.building['city'] as String,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A3C6E)))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadUnits,
                  color: const Color(0xFF1A3C6E),
                  child: _units.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _units.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _buildUnitCard(_units[i]),
                        ),
                ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit) {
    final isVacant = unit['is_vacant'] as bool? ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C6E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.door_front_door_outlined,
                        color: Color(0xFF1A3C6E),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit ${unit['unit_number'] ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A3C6E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Floor ${unit['floor'] ?? '—'} • ${unit['bedrooms'] ?? '—'} BHK',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVacant
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isVacant ? 'VACANT' : 'OCCUPIED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isVacant
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _detail(
                      Icons.currency_rupee_rounded,
                      '₹${unit['base_rent'] ?? '—'}',
                      'Base Rent',
                    ),
                  ),
                  Container(
                      width: 1, height: 32, color: Colors.grey.shade200),
                  Expanded(
                    child: _detail(
                      Icons.savings_outlined,
                      '₹${unit['deposit'] ?? '—'}',
                      'Deposit',
                    ),
                  ),
                  Container(
                      width: 1, height: 32, color: Colors.grey.shade200),
                  Expanded(
                    child: _detail(
                      Icons.bed_outlined,
                      '${unit['bedrooms'] ?? '—'}',
                      'Bedrooms',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF2E6DA4)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A3C6E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.door_front_door_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No units yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3C6E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add units to this building from the admin panel.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUnits,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3C6E),
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
