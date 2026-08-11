import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/app_surfaces.dart';
import 'add_building_screen.dart';
import 'building_screen.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  List<dynamic> _buildings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await apiClient.get('/api/v1/properties/buildings/');
      if (!mounted) return;
      setState(() => _buildings = response.data as List<dynamic>);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load buildings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToAddBuilding() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddBuildingScreen()),
    );
    if (added == true) _loadBuildings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadBuildings,
                  color: context.colors.primary,
                  child: _buildings.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _buildings.length,
                          itemBuilder: (context, index) {
                            return _buildBuildingCard(_buildings[index]);
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddBuilding,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Building',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBuildingCard(Map<String, dynamic> building) {
    final typeIcons = {
      'house': Icons.house_rounded,
      'apartment': Icons.apartment_rounded,
      'commercial': Icons.store_rounded,
    };
    final icon = typeIcons[building['type']] ?? Icons.apartment_rounded;
    final accent = context.accentBlue();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: context.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.brandText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.brandText, size: 24),
        ),
        title: Text(
          building['name'] ?? '—',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: context.brandText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              building['city'] ?? '—',
              style: context.mutedBodyStyle,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (building['type'] ?? '').toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.brandText,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuildingScreen(building: building),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 72,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No buildings yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add\nyour first building.',
              textAlign: TextAlign.center,
              style: context.mutedBodyStyle,
            ),
          ],
        ),
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
            onPressed: _loadBuildings,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
