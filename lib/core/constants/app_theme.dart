import 'package:flutter/material.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.backgroundColor,
      primaryColor: AppColors.primaryColor,

      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryColor,
        surface: AppColors.surfaceColor,
        onSurface: AppColors.textColor,
        background: AppColors.backgroundColor,
        error: AppColors.errorColor,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textColor,
        ),
        displayMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textColor,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textColor,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: AppColors.secondaryTextColor,
          height: 1.5,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryColor,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textColor,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  // Custom button decoration for gradient buttons
  static BoxDecoration get gradientButtonDecoration {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        colors: [
          AppColors.buttonGradientStart,
          AppColors.buttonGradientEnd.withOpacity(0.8),
        ],
      ),
    );
  }

  // Pill decoration for badges/chips
  static BoxDecoration get pillDecoration {
    return BoxDecoration(
      color: AppColors.primaryColor,
      borderRadius: BorderRadius.circular(50),
    );
  }
}
