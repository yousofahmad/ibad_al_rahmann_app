import 'package:flutter/material.dart';

class QuranThemeColors extends ThemeExtension<QuranThemeColors> {
  final Color paperColorLight;
  final Color paperColorDark;

  const QuranThemeColors({
    required this.paperColorLight,
    required this.paperColorDark,
  });

  @override
  QuranThemeColors copyWith({Color? paperColorLight, Color? paperColorDark}) {
    return QuranThemeColors(
      paperColorLight: paperColorLight ?? this.paperColorLight,
      paperColorDark: paperColorDark ?? this.paperColorDark,
    );
  }

  @override
  QuranThemeColors lerp(
    covariant ThemeExtension<QuranThemeColors>? other,
    double t,
  ) {
    if (other is! QuranThemeColors) {
      return this;
    }
    return QuranThemeColors(
      paperColorLight:
          Color.lerp(paperColorLight, other.paperColorLight, t) ??
          paperColorLight,
      paperColorDark:
          Color.lerp(paperColorDark, other.paperColorDark, t) ?? paperColorDark,
    );
  }
}
