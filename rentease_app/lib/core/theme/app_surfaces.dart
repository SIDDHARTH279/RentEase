import 'package:flutter/material.dart';

/// Shared dark/light-aware surfaces used across feature screens.
extension AppSurfaces on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  TextStyle get sectionTitleStyle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: colors.onSurface,
      );

  TextStyle get cardTitleStyle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      );

  TextStyle get mutedBodyStyle => TextStyle(
        fontSize: 13,
        color: colors.onSurfaceVariant,
      );

  BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.outlineVariant),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  Color get softFill =>
      isDark ? colors.surfaceContainerHighest : const Color(0xFFF5F7FA);

  Color get brandText => isDark ? colors.primary : const Color(0xFF1A3C6E);

  Color accentBlue([double lightAlpha = 1]) =>
      isDark ? const Color(0xFF64B5F6) : const Color(0xFF2E6DA4);

  Color accentGreen() =>
      isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C);

  Color accentRed() =>
      isDark ? const Color(0xFFEF9A9A) : const Color(0xFFD32F2F);

  Color accentOrange() =>
      isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
}

/// Theme-aware card shell used for list/overview tiles.
class ThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const ThemedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: context.cardDecoration(radius: radius),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}
