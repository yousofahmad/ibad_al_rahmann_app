import 'dart:math';

import 'package:flutter/material.dart';

class CompassCustomPainter extends CustomPainter {
  final double angle;

  const CompassCustomPainter({required this.angle});

  // Keeps rotating the North Red Triangle
  double get rotation => -angle * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    // Minimal Compass

    // Center The Compass In The Middle Of The Screen
    canvas.translate(size.width / 2, size.height / 2);

    Paint circle = Paint()
      ..strokeWidth = 2
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    Paint shadowCircle = Paint()
      ..strokeWidth = 2
      ..color = const Color.fromARGB(50, 158, 158, 158)
      ..style = PaintingStyle.fill;

    // Draw Shadow For Outer Circle
    canvas.drawCircle(Offset.zero, 107, shadowCircle);

    // Draw Outer Circle
    canvas.drawCircle(Offset.zero, 100, circle);

    Paint darkIndexLine = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    Paint lightIndexLine = Paint()
      ..color = Colors.grey
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    Paint goldNeedleBrush = Paint()
      ..color =
          const Color(0xFFD0A871) // Gold
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    canvas.rotate(-pi / 2);

    // Draw The Light Grey Lines
    for (int i = 1; i <= 16; i++) {
      canvas.drawLine(
        Offset.fromDirection(-(angle + 22.5 * i) * pi / 180, 60),
        Offset.fromDirection(-(angle + 22.5 * i) * pi / 180, 80),
        lightIndexLine,
      );
    }

    // Draw The Dark Grey Lines
    for (int i = 1; i <= 3; i++) {
      canvas.drawLine(
        Offset.fromDirection(-(angle + 90 * i) * pi / 180, 60),
        Offset.fromDirection(-(angle + 90 * i) * pi / 180, 80),
        darkIndexLine,
      );
    }

    // Draw North Needle (Gold)
    Path needlePath = Path();
    needlePath.moveTo(60 * cos(rotation), 60 * sin(rotation));
    needlePath.lineTo(85 * cos(rotation), 85 * sin(rotation));

    // Make it a bit fancier (triangle)
    // Actually simplicity is better for now, keeping line but thicker/Gold.
    canvas.drawLine(
      Offset.fromDirection(rotation, 60),
      Offset.fromDirection(rotation, 90), // Longer
      goldNeedleBrush,
    );

    // Draw Shadow For Inner Circle
    canvas.drawCircle(Offset.zero, 68, shadowCircle);

    // Draw Inner Circle
    canvas.drawCircle(Offset.zero, 65, circle);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
