import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';

import '../../../../../core/theme/app_images.dart';

class FullHeaderWidget extends StatelessWidget {
  final int surahNumber;
  final Color? color;
  final double? width;

  const FullHeaderWidget({
    super.key,
    required this.surahNumber,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    const double mobileWidth = 500;
    final double targetWidth = width ?? (context.isTablet ? 750 : mobileWidth);

    return Container(
      width: targetWidth,
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(AppImages.ayaFrame, fit: BoxFit.fill, width: targetWidth),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: targetWidth * 0.12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'surah${surahNumber.toString().padLeft(3, '0')}',
                textAlign: TextAlign.center,
                style: context.headlineMedium.copyWith(
                  fontSize: context.isTablet ? 54 : 48,
                  color: color,
                  fontFamily: 'SurahNames',
                  fontWeight: FontWeight.normal,
                  height: 0.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MinHeaderWidget extends StatelessWidget {
  final int surahNumber;
  final Color? color;

  const MinHeaderWidget({super.key, required this.surahNumber, this.color});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Stack(
        children: [
          Center(
            child: Image.asset(
              AppImages.ayaFrame,
              width: 380,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50.0),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'surah${surahNumber.toString().padLeft(3, '0')}',
                  textAlign: TextAlign.center,
                  style: context.labelSmall.copyWith(
                    fontSize: context.isTablet ? 32 : 28,
                    color: color,
                    fontFamily: 'SurahNames', // Use the new font
                    fontWeight: FontWeight.normal,
                    height: 0.7,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
