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
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: RingPainter(percent: percent, color: color),
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
    final radius = size.width / 2;

    // Background Circle (Dark Grey)
    final bgPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, bgPaint);

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
