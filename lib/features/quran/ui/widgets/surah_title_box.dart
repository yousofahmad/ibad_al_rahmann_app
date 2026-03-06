import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/adaptive_layout.dart';

class SurahTitleBox extends StatelessWidget {
  final String text;
  final bool selected;

  const SurahTitleBox({super.key, required this.text, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      mobileLayout: (_) => SurahTitleBoxMobile(text: text, selected: selected),
      tabletLayout: (_) => SurahTitleBoxTablet(text: text, selected: selected),
    );
  }
}

class SurahTitleBoxMobile extends StatelessWidget {
  final String text;
  final bool selected;

  const SurahTitleBoxMobile({
    super.key,
    required this.text,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // رجعنا المسافات والمقاسات الكبيرة بتاعة القديم
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 160.w,
      height: 45.h,
      child: CustomPaint(
        painter: FramePainter(
          selected: selected,
          backgroundColor: selected ? context.surfaceColor : context.secondary,
          borderColor: selected ? context.outline : context.secondary,
          borderWidth: 4, // رجعنا سمك الإطار زي القديم
        ),
        child: Center(
          child: Text(
            'سُورَة $text',
            // رجعنا الخط الكبير بتاع زمان
            style: AppStyles.style22u.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class SurahTitleBoxTablet extends StatelessWidget {
  final String text;
  final bool selected;

  const SurahTitleBoxTablet({
    super.key,
    required this.text,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 160.w,
      height: 50.h,
      child: CustomPaint(
        painter: FramePainter(
          selected: selected,
          backgroundColor: selected ? context.surfaceColor : context.secondary,
          borderColor: selected ? context.outline : context.secondary,
          borderWidth: 4,
        ),
        child: Center(
          child: Text(
            'سُورَة $text',
            style: context.headlineSmall.copyWith(
              color: Colors.white,
              fontSize: 22.sp,
            ),
          ),
        ),
      ),
    );
  }
}

class FramePainter extends CustomPainter {
  final bool selected;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  FramePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();

    final double width = size.width;
    final double height = size.height;
    const double cornerSize = 15.0;
    const double pointSize = 15.0;

    // Start top-left corner
    path.moveTo(0, cornerSize);

    // Left side with point
    path.lineTo(-pointSize, height * 0.5); // outward point
    path.lineTo(0, height - cornerSize);

    // Bottom-left corner
    path.lineTo(0, height);

    // Bottom side with inward point
    path.lineTo(width * 0.4, height);
    path.lineTo(width * 0.5, height + pointSize);
    path.lineTo(width * 0.6, height);
    path.lineTo(width, height);

    // Bottom-right corner
    path.lineTo(width, height - cornerSize);

    // Right side with point
    path.lineTo(width + pointSize, height * 0.5);
    path.lineTo(width, cornerSize);

    // Top-right corner
    path.lineTo(width, 0);

    // Top side with inward point
    path.lineTo(width * 0.6, 0);
    path.lineTo(width * 0.5, -pointSize);
    path.lineTo(width * 0.4, 0);
    path.lineTo(0, 0);

    // Close the path
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant FramePainter oldDelegate) {
    return oldDelegate.selected != selected;
  }
}