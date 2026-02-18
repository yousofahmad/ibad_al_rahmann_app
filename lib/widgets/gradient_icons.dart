import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// GradientIcon
/// A small reusable widget that renders an [Icon] filled with the app's gold gradient.
/// Used across the app to keep icon styling consistent (e.g. in ServiceCard).
class GradientIcon extends StatelessWidget {
  // The icon glyph to draw.
  final IconData icon;
  // Desired icon size in logical pixels.
  final double size;
  // Optional shadow color (reserved for future use).
  final Color? shadowColor;

  const GradientIcon(this.icon, {this.size = 24, this.shadowColor, super.key});

  @override
  Widget build(BuildContext context) {
    // ShaderMask applies a gradient shader to the child widget.
    // We draw a plain white Icon and let the ShaderMask replace its color
    // with the gold gradient defined in AppColors.
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return AppColors.goldGradient.createShader(bounds);
      },
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
