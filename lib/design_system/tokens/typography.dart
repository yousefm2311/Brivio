import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography design tokens using Outfit & Inter Google Fonts.
class AppTypography {
  static TextStyle displayLarge(Color color) => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: color,
    height: 1.2,
  );

  static TextStyle displayMedium(Color color) => GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.25,
  );

  static TextStyle titleLarge(Color color) => GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle titleMedium(Color color) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle bodyLarge(Color color) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle bodyMedium(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle labelLarge(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle caption(Color color) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
  );
}
