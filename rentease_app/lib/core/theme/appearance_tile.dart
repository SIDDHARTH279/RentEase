import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Segmented light / dark / system control for Profile.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  _chip(context, ThemeMode.light, Icons.light_mode_outlined, 'Light'),
                  _chip(context, ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
                  _chip(context, ThemeMode.system, Icons.settings_suggest_outlined, 'System'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final controller = ThemeController.instance;
    final selected = controller.mode == mode;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.setMode(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
