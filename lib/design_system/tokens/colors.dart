import 'package:flutter/material.dart';

/// Centralized color design tokens for Educational Academy Platform.
class AppColors {
  // Brand Primary & Accent
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF0EA5E9); // Sky Blue
  static const Color accent = Color(0xFF10B981); // Emerald Green

  // Role Accent Colors
  static const Color studentRole = Color(0xFF6366F1);
  static const Color teacherRole = Color(0xFF8B5CF6); // Purple
  static const Color parentRole = Color(0xFFF59E0B); // Amber
  static const Color adminRole = Color(0xFFEF4444); // Rose/Red

  // Dark Theme Neutral Palette
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCard = Color(0xFF334155); // Slate 700
  static const Color darkBorder = Color(0xFF475569); // Slate 600

  // Light Theme Neutral Palette
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
}
