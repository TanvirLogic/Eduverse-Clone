import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/app/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme => _baseTheme(Brightness.light);
  static ThemeData get darkTheme => _baseTheme(Brightness.dark);

  static ThemeData _baseTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.themeColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.themeColor,
        onPrimary: Colors.white,
        secondary: AppColors.themeColor,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1F2937),
        onSurface: isLight ? const Color(0xFF1F2937) : Colors.white,
        outline: isLight ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
        outlineVariant: isLight ? AppColors.border : const Color(0xFF374151),
        surfaceContainerLow: isLight ? const Color(0xFFF3F4F6) : const Color(0xFF1E293B),
        surfaceContainer: isLight ? const Color(0xFFEEF0F2) : const Color(0xFF1F2937),
        surfaceContainerHigh: isLight ? const Color(0xFFE5E7EB) : const Color(0xFF273548),
      ),
      scaffoldBackgroundColor: isLight ? const Color(0xFFFCFCFD) : const Color(0xFF111827),
      textTheme: GoogleFonts.urbanistTextTheme(isLight ? null : ThemeData.dark().textTheme).apply(
        bodyColor: isLight ? const Color(0xFF1F2937) : Colors.white,
        displayColor: isLight ? const Color(0xFF1F2937) : Colors.white,
      ).copyWith(
        bodyLarge: GoogleFonts.urbanist(fontWeight: FontWeight.w500, color: isLight ? null : Colors.white),
        bodyMedium: GoogleFonts.urbanist(fontWeight: FontWeight.w500, color: isLight ? null : Colors.white),
        titleLarge: GoogleFonts.urbanist(fontWeight: FontWeight.w700, color: isLight ? null : Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF1F2937),
        hintStyle: GoogleFonts.urbanist(
          color: isLight ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: isLight
              ? const BorderSide(color: AppColors.border, width: 1)
              : BorderSide.none,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide(color: AppColors.themeColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide(color: AppColors.themeColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.urbanist(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }
}
