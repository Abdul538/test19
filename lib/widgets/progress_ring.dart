import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

class ProgressRing extends StatelessWidget {
  final double fraction; // 0..1
  final Color color;
  final String centerText;
  final String centerLabel;
  final double size;
  final bool glow;

  const ProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.centerText,
    required this.centerLabel,
    this.size = 132,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(fraction: value, color: color, glow: glow),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Opacity(
                  opacity: v,
                  child: Text(
                    centerText,
                    style: AppFonts.stat(
                      size: 26,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerLabel,
                style: AppFonts.label(size: 9.5, letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final bool glow;
  _RingPainter({required this.fraction, required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);

    final bgPaint = Paint()
      ..color = color.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, bgPaint);

    final sweep = 2 * pi * fraction.clamp(0, 1);

    if (glow) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, -pi / 2, sweep, false, glowPaint);
    }

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [color.withOpacity(0.6), color],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, sweep, false, fgPaint);

    // titik terang di ujung progress, meniru highlight kecil pada ring asli
    if (sweep > 0.05) {
      final endAngle = -pi / 2 + sweep;
      final center = Offset(size.width / 2, size.height / 2);
      final r = rect.width / 2;
      final dotCenter = center + Offset(cos(endAngle), sin(endAngle)) * r;
      final dotPaint = Paint()..color = Colors.white.withOpacity(0.9);
      canvas.drawCircle(dotCenter, stroke * 0.22, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color || oldDelegate.glow != glow;
}
