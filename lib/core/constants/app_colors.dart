// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Base Colors
  static const primaryColor = Color(
    0xFF6B4EFF,
  ); // Purple accent color
  static const backgroundColor = Color(
    0xFF0A0B2F,
  ); // Dark blue background
  static const surfaceColor = Color(
    0xFF1A1B3F,
  ); // Slightly lighter blue for cards
  static const textColor = Colors.white;
  static const secondaryTextColor = Color(0xFF9EA3B5);
  static const errorColor = Color(0xFFFF4444);

  // Additional Colors
  static const buttonGradientStart = Color(0xFF1A1B3F);
  static const buttonGradientEnd = Color(0xFF1A1B3F);
  static const descriptiveText = Color(
    0xFFB4B9C9,
  ); // Light purple/periwinkle for descriptive text

  // Opacity Variations
  static Color surfaceColorWithOpacity(double opacity) =>
      surfaceColor.withOpacity(opacity);
  static Color primaryColorWithOpacity(double opacity) =>
      primaryColor.withOpacity(opacity);
}
