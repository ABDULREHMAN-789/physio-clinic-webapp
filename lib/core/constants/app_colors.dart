import 'package:flutter/material.dart';

class AppColors {
  // Medical/Clinical Primary Palette
  static const Color primary = Color(0xFF1E88E5); // Rich Medical Blue
  static const Color primaryLight = Color(0xFFE3F2FD); // Light Blue for backgrounds/hover
  static const Color primaryDark = Color(0xFF1565C0); // Darker Blue for headers/focus
  
  static const Color secondary = Color(0xFF00ACC1); // Clean Teal for accents
  static const Color accent = Color(0xFF3F51B5); // Indigo accent

  // Neutral Colors
  static const Color background = Color(0xFFF8FAFC); // Soft off-white background
  static const Color surface = Color(0xFFFFFFFF); // High quality pure white card surface
  static const Color border = Color(0xFFE2E8F0); // Subtle gray borders

  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B); // Dark Slate for main reading
  static const Color textSecondary = Color(0xFF64748B); // Cool Gray for subtitles/captions
  static const Color textLight = Color(0xFF94A3B8); // Very light gray for disabled text/icons

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green for paid/active
  static const Color warning = Color(0xFFF59E0B); // Amber for pending/due
  static const Color error = Color(0xFFEF4444); // Red for unpaid/danger

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF1565C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dashboardCardGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
