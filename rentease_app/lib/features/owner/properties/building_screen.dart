import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';
import 'add_unit_screen.dart';

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
      final res = await apiClient.get(
        '/api/v1/properties/units/',
        queryParameters: {'building_id': widget.building['id']},
      );
      if (!mounted) return;
      setState(() => _units = res.data as List<dynamic>? ?? []);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load units.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addUnit() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddUnitScreen(
          buildingId: widget.building['id'] as int,
          buildingName: widget.building['name']?.toString() ?? 'Building',
        ),
      ),
    );
    if (added == true) _loadUnits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadUnits,
                  color: context.colors.primary,
                  child: _units.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
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
    final vacantColor = context.accentOrange();
    final occupiedColor = context.accentGreen();

    return Container(
      decoration: context.cardDecoration(radius: 18),
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
                        color: context.brandText.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.door_front_door_outlined,
                        color: context.brandText,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit ${unit['unit_number'] ?? '—'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: context.brandText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Floor ${unit['floor'] ?? '—'} • ${unit['bedrooms'] ?? '—'} BHK',
                          style: context.mutedBodyStyle.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isVacant ? vacantColor : occupiedColor)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isVacant ? 'VACANT' : 'OCCUPIED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isVacant ? vacantColor : occupiedColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.softFill,
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
                    width: 1,
                    height: 32,
                    color: context.colors.outlineVariant,
                  ),
                  Expanded(
                    child: _detail(
                      Icons.savings_outlined,
                      '₹${unit['deposit'] ?? '—'}',
                      'Deposit',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: context.colors.outlineVariant,
                  ),
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(
                  '/documents',
                  extra: {
                    'isOwner': true,
                    'unitId': unit['id'],
                    'unitNumber': unit['unit_number']?.toString(),
                  },
                ),
                icon: const Icon(Icons.folder_outlined, size: 18),
                label: const Text('Documents'),
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
        Icon(icon, size: 15, color: context.accentBlue()),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: context.brandText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.mutedBodyStyle.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.door_front_door_outlined,
          size: 64,
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'No units yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap Add Unit to create flats or rooms for this building.',
          textAlign: TextAlign.center,
          style: context.mutedBodyStyle,
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: _addUnit,
            icon: const Icon(Icons.add),
            label: const Text('Add Unit'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
            onPressed: _loadUnits,
            style: ElevatedButton.styleFrom(
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
