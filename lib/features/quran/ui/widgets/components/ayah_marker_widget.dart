import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';

/// A premium custom ayah-end marker widget that renders the Ayah.svg
/// as the background with the Arabic ayah number centred on top.
///
/// Drop directly in a [Row.children] list (WBW view) OR inside a [WidgetSpan]
/// with [alignment: PlaceholderAlignment.middle] (RichText view).
class AyahMarkerWidget extends StatelessWidget {
  final int ayahNumber;

  /// The overall size of the square container that holds the SVG + number.
  /// Default 50 — large enough to be clearly readable at a glance.
  final double size;

  /// Colour of the Arabic numeral drawn on top of the SVG.
  /// Defaults to a deep brown that matches classic Quran colouring.
  final Color numberColor;

  /// Font size of the Arabic numeral inside the marker.
  final double fontSize;

  const AyahMarkerWidget({
    super.key,
    required this.ayahNumber,
    this.size = 50,
    this.numberColor = const Color(0xFF3E2723),
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Background SVG ──────────────────────────────────────────────
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/images/Ayah.svg',
              fit: BoxFit.contain,
            ),
          ),

          // ── Ayah number (Arabic numerals) ────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Text(
              ayahNumber.toArabicNums,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize + 1, // slight bump to match proportions
                fontWeight: FontWeight.bold,
                color: numberColor,
                height: 1.0,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience factory that returns the [WidgetSpan] ready to be inserted
/// into a [TextSpan] children list (used by mobile/tablet RichText views).
///
/// [size] defaults to 50 — visually prominent and clearly readable.
WidgetSpan ayahMarkerSpan({
  required int ayahNumber,
  double size = 50,
  Color numberColor = const Color(0xFF3E2723),
  double fontSize = 14,
  bool isDark = false,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      // A tiny breathing room so the marker doesn't touch adjacent glyphs.
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AyahMarkerWidget(
        ayahNumber: ayahNumber,
        size: size,
        fontSize: fontSize,
        // In dark mode use warm cream; in light mode use deep brown.
        numberColor: isDark ? const Color(0xFFFFF8E1) : numberColor,
      ),
    ),
  );
}
