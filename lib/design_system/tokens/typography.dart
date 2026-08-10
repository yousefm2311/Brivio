import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple HIG Typography system — Inter font with precise sizing,
/// weight, tracking, and line-height for every scale step.
class AppTypography {
  AppTypography._();

  // ─── Hero / Display ───────────────────────────────────────────────────────

  /// Massive hero number or greeting — 52px bold
  static TextStyle hero(Color color) => GoogleFonts.inter(
    fontSize: 52,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.0,
    letterSpacing: -2.0,
  );

  /// Display Large — page titles, splash text — 36px
  static TextStyle displayLarge(Color color) => GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.1,
    letterSpacing: -1.0,
  );

  /// Display Medium — section hero cards — 28px
  static TextStyle displayMedium(Color color) => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.15,
    letterSpacing: -0.7,
  );

  /// Display Small — prominent card headings — 24px
  static TextStyle displaySmall(Color color) => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
    letterSpacing: -0.5,
  );

  // ─── Title ────────────────────────────────────────────────────────────────

  /// Title Large — section headers — 22px semibold
  static TextStyle titleLarge(Color color) => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.25,
    letterSpacing: -0.4,
  );

  /// Title Medium — card headers — 17px semibold (Apple's "headline")
  static TextStyle titleMedium(Color color) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// Title Small — labels, chips — 15px semibold
  static TextStyle titleSmall(Color color) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.3,
    letterSpacing: -0.2,
  );

  // ─── Body ────────────────────────────────────────────────────────────────

  /// Body Large — primary readable text — 17px regular
  static TextStyle bodyLarge(Color color) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.47,
    letterSpacing: -0.2,
  );

  /// Body Medium — secondary text — 15px regular
  static TextStyle bodyMedium(Color color) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
    letterSpacing: -0.15,
  );

  /// Body Small — tertiary, descriptions — 13px regular
  static TextStyle bodySmall(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.38,
    letterSpacing: -0.08,
  );

  // ─── Label ────────────────────────────────────────────────────────────────

  /// Label Large — button text, CTAs — 15px semibold
  static TextStyle labelLarge(Color color) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// Label Medium — tags, pills — 13px medium
  static TextStyle labelMedium(Color color) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// Label Small — badges, overlines — 11px medium
  static TextStyle labelSmall(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.3,
    letterSpacing: 0.06,
  );

  // ─── Caption ─────────────────────────────────────────────────────────────

  /// Caption — timestamps, hints — 12px regular
  static TextStyle caption(Color color) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.33,
    letterSpacing: 0.0,
  );

  /// Caption Semibold — section overlines — 11px semibold allcaps
  static TextStyle overline(Color color) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.4,
    letterSpacing: 0.8,
  );

  // ─── Numeric / Mono ───────────────────────────────────────────────────────

  /// Big numeric display — scores, balances
  static TextStyle numericDisplay(Color color) => GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.0,
    letterSpacing: -1.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Tabular number — for stats/tables
  static TextStyle numericMedium(Color color) => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.1,
    letterSpacing: -0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
