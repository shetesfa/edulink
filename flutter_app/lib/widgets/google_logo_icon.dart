import 'package:flutter/material.dart';

class GoogleLogoIcon extends StatelessWidget {
  final double size;
  const GoogleLogoIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double s = width / 24.0; // Scale factor for 24x24 standard SVG viewport

    // Official Google Brand Colors
    final Paint redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final Paint yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final Paint greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
    final Paint bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;

    // 1. Red Path (Top Arc - fully filled & crisp)
    final Path redPath = Path()
      ..moveTo(12 * s, 4.75 * s)
      ..cubicTo(13.77 * s, 4.75 * s, 15.35 * s, 5.36 * s, 16.6 * s, 6.55 * s)
      ..lineTo(20.02 * s, 3.13 * s)
      ..cubicTo(17.95 * s, 1.19 * s, 15.24 * s, 0 * s, 12 * s, 0 * s)
      ..cubicTo(7.31 * s, 0 * s, 3.26 * s, 2.7 * s, 1.29 * s, 6.63 * s)
      ..lineTo(5.28 * s, 9.76 * s)
      ..cubicTo(6.23 * s, 6.91 * s, 8.88 * s, 4.75 * s, 12 * s, 4.75 * s)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // 2. Yellow Path (Left Arc)
    final Path yellowPath = Path()
      ..moveTo(5.28 * s, 14.24 * s)
      ..cubicTo(5.03 * s, 13.52 * s, 4.9 * s, 12.75 * s, 4.9 * s, 12 * s)
      ..cubicTo(4.9 * s, 11.25 * s, 5.03 * s, 10.48 * s, 5.28 * s, 9.76 * s)
      ..lineTo(1.29 * s, 6.63 * s)
      ..cubicTo(0.47 * s, 8.24 * s, 0 * s, 10.06 * s, 0 * s, 12 * s)
      ..cubicTo(0 * s, 13.94 * s, 0.47 * s, 15.76 * s, 1.29 * s, 17.37 * s)
      ..lineTo(5.28 * s, 14.24 * s)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 3. Green Path (Bottom Arc)
    final Path greenPath = Path()
      ..moveTo(12 * s, 24 * s)
      ..cubicTo(15.24 * s, 24 * s, 17.95 * s, 22.92 * s, 19.93 * s, 21.09 * s)
      ..lineTo(16.05 * s, 18.04 * s)
      ..cubicTo(14.97 * s, 18.76 * s, 13.6 * s, 19.2 * s, 12 * s, 19.2 * s)
      ..cubicTo(8.88 * s, 19.2 * s, 6.23 * s, 17.09 * s, 5.28 * s, 14.24 * s)
      ..lineTo(1.29 * s, 17.37 * s)
      ..cubicTo(3.26 * s, 21.3 * s, 7.31 * s, 24 * s, 12 * s, 24 * s)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // 4. Blue Path (Right Arc & Center Bar)
    final Path bluePath = Path()
      ..moveTo(23.74 * s, 12.27 * s)
      ..cubicTo(23.74 * s, 11.57 * s, 23.68 * s, 10.87 * s, 23.55 * s, 10.2 * s)
      ..lineTo(12 * s, 10.2 * s)
      ..lineTo(12 * s, 14.71 * s)
      ..lineTo(18.6 * s, 14.71 * s)
      ..cubicTo(18.31 * s, 16.23 * s, 17.46 * s, 17.53 * s, 16.2 * s, 18.39 * s)
      ..lineTo(20.08 * s, 21.44 * s)
      ..cubicTo(22.35 * s, 19.35 * s, 23.74 * s, 16.27 * s, 23.74 * s, 12.27 * s)
      ..close();
    canvas.drawPath(bluePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
