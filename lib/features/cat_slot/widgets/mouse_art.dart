import 'package:flutter/material.dart';

class CozyMouse extends StatelessWidget {
  final bool golden;
  final double size;
  final bool bonusBadge;

  const CozyMouse({
    super.key,
    this.golden = false,
    this.size = 64,
    this.bonusBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: golden ? 'Goldene Maus' : 'Maus',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _MousePainter(golden: golden, bonusBadge: bonusBadge),
          ),
        ),
      ),
    );
  }
}

class _MousePainter extends CustomPainter {
  final bool golden;
  final bool bonusBadge;

  const _MousePainter({required this.golden, required this.bonusBadge});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 72;
    canvas.save();
    canvas.scale(scale);

    if (bonusBadge) {
      final badgeRect = Rect.fromCircle(
        center: const Offset(36, 36),
        radius: 34,
      );
      canvas.drawCircle(
        const Offset(36, 36),
        33,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x554FE4DA), Color(0x3323163B), Color(0x00130C22)],
          ).createShader(badgeRect),
      );
      canvas.drawCircle(
        const Offset(36, 36),
        31,
        Paint()
          ..color = const Color(0xAA8CE4DC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    final bodyColor = golden
        ? const Color(0xFFF1C95C)
        : const Color(0xFFB7A8BE);
    final lightColor = golden
        ? const Color(0xFFFFF0A7)
        : const Color(0xFFE8DFEA);
    final earColor = golden ? const Color(0xFFFFD77A) : const Color(0xFFD99BB5);

    final tail = Path()
      ..moveTo(21, 47)
      ..cubicTo(5, 51, 7, 64, 20, 61);
    canvas.drawPath(
      tail,
      Paint()
        ..color = earColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3,
    );

    canvas.drawOval(
      const Rect.fromLTWH(17, 29, 40, 27),
      Paint()..color = bodyColor,
    );
    canvas.drawCircle(const Offset(50, 30), 14, Paint()..color = lightColor);
    canvas.drawCircle(const Offset(43, 18), 8, Paint()..color = bodyColor);
    canvas.drawCircle(const Offset(56, 17), 8, Paint()..color = bodyColor);
    canvas.drawCircle(const Offset(43, 18), 4.7, Paint()..color = earColor);
    canvas.drawCircle(const Offset(56, 17), 4.7, Paint()..color = earColor);
    canvas.drawCircle(
      const Offset(54, 28),
      1.8,
      Paint()..color = const Color(0xFF24182E),
    );
    canvas.drawCircle(
      const Offset(64, 34),
      2.4,
      Paint()..color = const Color(0xFF6E405A),
    );

    final whisker = Paint()
      ..color = lightColor.withValues(alpha: 0.9)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(59, 36), const Offset(70, 32), whisker);
    canvas.drawLine(const Offset(59, 38), const Offset(70, 39), whisker);
    canvas.drawLine(const Offset(58, 40), const Offset(67, 45), whisker);

    if (golden) {
      final sparkle = Paint()..color = const Color(0xFFFFF5B5);
      canvas.drawCircle(const Offset(24, 31), 2.2, sparkle);
      canvas.drawCircle(const Offset(33, 46), 1.5, sparkle);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MousePainter oldDelegate) =>
      oldDelegate.golden != golden || oldDelegate.bonusBadge != bonusBadge;
}
