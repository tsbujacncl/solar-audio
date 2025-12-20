import 'package:flutter/material.dart';

/// Centralized color constants for Boojy Audio DAW
/// Based on dark theme with cyan accent
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============================================
  // Primary Colors
  // ============================================

  /// Primary accent color (cyan)
  static const Color primary = Color(0xFF00BCD4);

  /// Success/positive color (green)
  static const Color success = Color(0xFF4CAF50);

  /// Error/warning color (orange-red)
  static const Color error = Color(0xFFFF5722);

  // ============================================
  // Background Colors (darkest to lightest)
  // ============================================

  /// Darkest background (panels, deep areas)
  static const Color backgroundDarkest = Color(0xFF181818);

  /// Dark background (main surfaces)
  static const Color backgroundDark = Color(0xFF202020);

  /// Standard background (most panels)
  static const Color background = Color(0xFF242424);

  /// Elevated background (cards, menus)
  static const Color backgroundElevated = Color(0xFF2B2B2B);

  /// Surface color (interactive elements)
  static const Color surface = Color(0xFF303030);

  /// Divider/border color
  static const Color divider = Color(0xFF363636);

  /// Subtle surface (hover states)
  static const Color surfaceHover = Color(0xFF404040);

  // ============================================
  // Text Colors
  // ============================================

  /// Primary text (white/light)
  static const Color textPrimary = Color(0xFFE0E0E0);

  /// Secondary text (grey)
  static const Color textSecondary = Color(0xFFBDBDBD);

  /// Muted text (dark grey)
  static const Color textMuted = Color(0xFF9E9E9E);

  /// Disabled text
  static const Color textDisabled = Color(0xFF616161);

  // ============================================
  // Mixer/Track Colors
  // ============================================

  /// Mixer strip background
  static const Color mixerBackground = Color(0xFF656565);

  /// Mixer strip border
  static const Color mixerBorder = Color(0xFF909090);

  /// Mixer header background
  static const Color mixerHeader = Color(0xFF707070);

  /// Mixer control text
  static const Color mixerText = Color(0xFF202020);

  // ============================================
  // MIDI Note Color
  // ============================================

  /// Base mint green for MIDI notes (FL Studio style)
  static const Color midiNote = Color(0xFF7FD4A0);
}
