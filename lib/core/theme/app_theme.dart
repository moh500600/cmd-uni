import 'package:flutter/material.dart';

/// Academic palette: royal blue primary, amber accent (graduation gold),
/// status colours, and a course colour set.
class AppColors {
  static const primary = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFF3B82F6);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF059669);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0891B2);
  static const purple = Color(0xFF7C3AED);
  static const ink = Color(0xFF0B1220);
  static const inkCard = Color(0xFF131C2E);

  static const courseColors = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFDB2777),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFEA580C),
    Color(0xFF65A30D),
    Color(0xFFDC2626),
    Color(0xFF4F46E5),
    Color(0xFF0D9488),
    Color(0xFF64748B),
  ];

  static Color course(int value) => value == 0 ? courseColors.first : Color(value);

  static Color kind(String kind) => switch (kind) {
    'lecture' => primaryLight,
    'exam' => danger,
    'assignment' => accent,
    'project' => purple,
    'study' => success,
    _ => info,
  };

  static Color status(String s) => switch (s) {
    'not_started' => const Color(0xFF64748B),
    'in_progress' => primaryLight,
    'completed' => success,
    'submitted' => const Color(0xFF0D9488),
    'late' => danger,
    'cancelled' => const Color(0xFF94A3B8),
    _ => primaryLight,
  };
}

class AppTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b).copyWith(
      primary: dark ? const Color(0xFF93B4FF) : AppColors.primary,
      secondary: AppColors.accent,
      surface: dark ? AppColors.ink : const Color(0xFFF5F7FB),
      surfaceContainerLowest: dark ? AppColors.inkCard : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF172238) : Colors.white,
      surfaceContainer: dark ? const Color(0xFF1B2740) : const Color(0xFFEEF2F8),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.25 : 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        selectedLabelTextStyle: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: scheme.primary),
        unselectedLabelTextStyle: TextStyle(fontFamily: 'Tajawal', color: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 14)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.4), space: 1),
    );
  }
}
