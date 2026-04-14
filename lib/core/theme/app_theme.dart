import 'package:flutter/material.dart';

class AppColors {
  static const primary    = Color(0xFFF97316); // orange
  static const success    = Color(0xFF10B981); // emerald
  static const danger     = Color(0xFFEF4444); // red
  static const warning    = Color(0xFFF59E0B); // amber
  static const bg         = Color(0xFFFAFAF9); // warm white
  static const surface    = Color(0xFFFFFFFF);
  static const border     = Color(0xFFE7E5E4);
  static const textMain   = Color(0xFF1C1917);
  static const textSub    = Color(0xFF78716C);
  static const textMuted  = Color(0xFFA8A29E);
  static const textInverse = Color(0xFFFFFFFF);
}

class AppTextStyles {
  static const _base = TextStyle(fontFamily: 'Inter', color: AppColors.textMain);

  static final h1    = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w800);
  static final h2    = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static final h3    = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
  static final body  = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final label = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSub);
  static final hero  = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textInverse);
  static final heroSub = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textMain,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
  );
}
