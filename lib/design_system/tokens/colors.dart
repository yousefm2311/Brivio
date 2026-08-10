import 'package:flutter/material.dart';

/// Apple HIG — OLED-first dark color system.
/// Every color here is intentionally chosen for contrast, vibrancy,
/// and harmony on both OLED (true black) and LCD (near-black) displays.
class AppColors {
  AppColors._();

  // ─── Brand / Primary ───────────────────────────────────────────────────────
  /// Apple Blue — Dark-mode optimized vibrant blue
  static const Color primary        = Color(0xFF0A84FF);
  static const Color primaryDark    = Color(0xFF0066CC);
  static const Color primaryLight   = Color(0xFF409CFF);
  static const Color primaryGlow    = Color(0x330A84FF);  // for glow shadows
  static const Color primarySubtle  = Color(0x1A0A84FF);  // for backgrounds

  /// Apple Teal — secondary accent
  static const Color secondary      = Color(0xFF64D2FF);
  static const Color secondaryGlow  = Color(0x2264D2FF);

  // ─── Role Accent Colors ────────────────────────────────────────────────────
  static const Color studentRole    = Color(0xFF0A84FF);  // Apple Blue
  static const Color teacherRole    = Color(0xFFBF5AF2);  // Apple Purple
  static const Color parentRole     = Color(0xFFFF9F0A);  // Apple Orange
  static const Color adminRole      = Color(0xFFFF453A);  // Apple Red
  static const Color staffRole      = Color(0xFF30D158);  // Apple Green

  // ─── OLED Dark Backgrounds ────────────────────────────────────────────────
  static const Color darkBackground        = Color(0xFF000000);  // True OLED black
  static const Color darkBackgroundElevated = Color(0xFF0A0A0A); // Slightly lifted
  static const Color darkSurface           = Color(0xFF111111);  // Cards / sheets
  static const Color darkSurfaceSecondary  = Color(0xFF1A1A1A);  // Nested surfaces
  static const Color darkCard              = Color(0xFF161616);  // Card background
  static const Color darkCardSecondary     = Color(0xFF222222);  // Secondary card

  // ─── Glass / Frosted surfaces ─────────────────────────────────────────────
  static const Color glassLight      = Color(0x1AFFFFFF);  // 10% white
  static const Color glassMedium     = Color(0x26FFFFFF);  // 15% white
  static const Color glassStrong     = Color(0x33FFFFFF);  // 20% white
  static const Color glassBorder     = Color(0x1AFFFFFF);  // subtle white border
  static const Color glassBorderHover = Color(0x33FFFFFF); // hovered border

  // ─── Borders & Separators ─────────────────────────────────────────────────
  static const Color darkBorder      = Color(0xFF2A2A2A);
  static const Color darkSeparator   = Color(0xFF1F1F1F);
  static const Color darkDivider     = Color(0xFF242424);

  // ─── Light Theme (kept for system support) ────────────────────────────────
  static const Color lightBackground        = Color(0xFFF2F2F7);
  static const Color lightSurface          = Color(0xFFFFFFFF);
  static const Color lightCard             = Color(0xFFFFFFFF);
  static const Color lightCardSecondary    = Color(0xFFE5E5EA);
  static const Color lightBorder           = Color(0xFFE5E5EA);
  static const Color lightGlassBorder      = Color(0x20000000);

  // ─── Semantic / Status ────────────────────────────────────────────────────
  static const Color success        = Color(0xFF30D158);  // Apple Green
  static const Color successSubtle  = Color(0x1A30D158);
  static const Color warning        = Color(0xFFFF9F0A);  // Apple Orange
  static const Color warningSubtle  = Color(0x1AFF9F0A);
  static const Color error          = Color(0xFFFF453A);  // Apple Red
  static const Color errorSubtle    = Color(0x1AFF453A);
  static const Color info           = Color(0xFF0A84FF);  // Apple Blue
  static const Color infoSubtle     = Color(0x1A0A84FF);
  static const Color purple         = Color(0xFFBF5AF2);
  static const Color purpleSubtle   = Color(0x1ABF5AF2);
  static const Color teal           = Color(0xFF5AC8FA);
  static const Color yellow         = Color(0xFFFFD60A);  // Apple Yellow
  static const Color yellowSubtle   = Color(0x1AFFD60A);
  static const Color pink           = Color(0xFFFF375F);  // Apple Pink
  static const Color mint           = Color(0xFF63E6BE);

  // ─── Text / Typography ────────────────────────────────────────────────────
  static const Color darkTextPrimary    = Color(0xFFFFFFFF);
  static const Color darkTextSecondary  = Color(0x99EBEBF5);  // 60% label
  static const Color darkTextTertiary   = Color(0x66EBEBF5);  // 40% label
  static const Color darkTextPlaceholder = Color(0x4DEBEBF5); // 30% placeholder
  static const Color lightTextPrimary   = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0x993C3C43);
  static const Color lightTextTertiary  = Color(0x663C3C43);

  // ─── Gradient presets ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A84FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient learningGradient = LinearGradient(
    colors: [Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF30D158), Color(0xFF25A244)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF9F0A), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cosmicGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
