import 'package:flutter/material.dart';

/// Central color-decision helper for the Quran reader.
///
/// All components that need to adapt colors to the current paper or accent
/// should call these helpers instead of duplicating luminance checks inline.
///
/// Two independent systems:
///   • [accentColor] – the app-level primary color (blue/red/cyan/green)
///   • [paperColor]  – the page background (white/cream/antique/black/dark/navy)
abstract final class QuranColors {
  // ── Accent palette ──────────────────────────────────────────────────────
  static const accentBlue = Color(0xFF1565C0);
  static const accentRed = Color(0xFFC62828);
  static const accentCyan = Color(0xFF00838F);
  static const accentGreen = Color(0xFF2E7D32);

  /// Returns the accent [Color] for a stored theme key.
  static Color accentFromKey(String? key) => switch (key) {
    'red' => accentRed,
    'cyan' => accentCyan,
    'green' => accentGreen,
    _ => accentBlue,
  };

  // ── Paper-color helpers ─────────────────────────────────────────────────

  /// `true` when the paper is light (luminance > 0.5).
  static bool isLightPaper(Color? paperColor) =>
      paperColor == null || paperColor.computeLuminance() > 0.5;

  /// Foreground (text / icon) color that contrasts against [paperColor].
  static Color onPaper(Color? paperColor) =>
      isLightPaper(paperColor) ? Colors.black : Colors.white;

  // ── Overlay backgrounds ─────────────────────────────────────────────────

  /// Background for single-tap, long-tap, and colors menus.
  /// User requested: "يبقي الهيدر بتاع الحاجات دي او الخلفية ... نفس لون الثيم بتاع الوضع المصغر ... وباقي القايمة تكون ... ابيض لو فاتح واسود لو غامق"
  /// We will return the accent color for headers/tap bars.
  static Color tapBarBg(Color? paperColor, Color accentColor) => accentColor;

  /// Background for the *rest* of the menu (e.g. bottom sheet content body).
  static Color menuBodyBg(Color? paperColor) =>
      isLightPaper(paperColor) ? Colors.white : Colors.black;

  /// [AutoScrollControlOverlay] card background.
  static Color autoScrollBg(Color? paperColor) => isLightPaper(paperColor)
      ? Colors.white.withValues(alpha: 0.93)
      : Colors.black.withValues(alpha: 0.93);

  /// [AutoScrollControlOverlay] content color.
  static Color autoScrollContent(Color? paperColor) =>
      isLightPaper(paperColor) ? Colors.black87 : Colors.white;

  // ── Scaffold / page ─────────────────────────────────────────────────────

  /// Quran [Scaffold] background — uses the actual paper color, never binary
  /// white/black from the app theme brightness.
  static Color scaffoldBg(Color? paperColor, bool isDark) =>
      paperColor ?? (isDark ? Colors.black : Colors.white);

  // ── Fehres dialog ───────────────────────────────────────────────────────

  /// Individual Juz/Hizb/Rub' card background in [QuranFehresDialog].
  static Color fehresCardBg({required bool isLightBg}) =>
      isLightBg ? Colors.white : Colors.black;

  /// Juz group-header tinted band background.
  static Color juzHeaderTint(Color accent, {required bool isLightBg}) =>
      accent.withValues(alpha: isLightBg ? 0.08 : 0.18);

  /// Juz group-header foreground text color.
  static Color juzHeaderText(Color accent) => accent;
}
