import 'dart:math';
import 'package:flutter/material.dart';

class PrayerRingWidget extends StatelessWidget {
  final double percent;
  final Color color;

  const PrayerRingWidget({
    super.key,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: SizedBox.expand(
          child: CustomPaint(
            painter: RingPainter(percent: percent, color: color),
          ),
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double percent;
  final Color color;

  RingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Background Circle (Dark Grey)
    final bgPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, bgPaint);

    // Thin Golden Borders
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer border
    canvas.drawCircle(center, radius + 5, borderPaint);
    // Inner border
    canvas.drawCircle(center, radius - 5, borderPaint);

    // Progress Arc (Gold)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    // Start from top (-pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percent,
      false,
      progressPaint,
    );

    // Add Shadow/Glow effect nicely?
    // keeping it simple as prompt requested "High Fidelity" which usually means clean.
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}
