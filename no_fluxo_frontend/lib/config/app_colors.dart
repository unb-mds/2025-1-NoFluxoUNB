import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52D5);
  static const Color purple = Color(0xFF9C27B0);
  static const Color pink = Color(0xFFE91E63);
  static const Color yellow = Color(0xFFFFC107);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray = Color(0xFF9E9E9E);
  static const Color darkGray = Color(0xFF424242);

  static const Color dialogBackground = Color(0xFF1A1A1A);

  // Course Card Colors
  // Completed Subject Colors
  static const Color completedStart = Color.fromARGB(255, 45, 192, 99);
  static const Color completedEnd = Color.fromARGB(255, 11, 125, 53);

  // Current Subject Colors
  static const Color currentStart = Color(0xFFA78BFA);
  static const Color currentEnd = Color(0xFF8B5CF6);

  // Selected Subject Colors
  static const Color selectedStart = Color(0xFFFB7185);
  static const Color selectedEnd = Color(0xFFE11D48);

  // Optative Subject Colors
  static const Color optativeStart = Color(0xFF3B82F6);
  static const Color optativeEnd = Color(0xFF1D4ED8);

  // Ready Subject Colors (prerequisites completed)
  static const Color readyStart = Color(0xFFF59E0B);
  static const Color readyEnd = Color(0xFFD97706);

  // Future Subject Colors (with opacity)
  static Color get futureStart => white.withOpacity(0.1);
  static Color get futureEnd => white.withOpacity(0.1);

  // Material Colors (with opacity)
  static Color get completedBackground => Colors.green.withOpacity(0.1);
  static Color get currentBackground => Colors.blue.withOpacity(0.1);

  // Shadow and Container Colors (with opacity)
  static Color get cardShadow => black.withOpacity(0.3);
  static Color get containerBackground => black.withOpacity(0.2);
}
