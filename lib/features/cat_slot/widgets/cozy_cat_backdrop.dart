import 'package:flutter/material.dart';

/// Ruhiger, rein codebasierter Hintergrund-Look über dem vorhandenen Katzenbild.
/// Die Dekoration ist statisch und liegt in einem RepaintBoundary, damit sie
/// während der Rollenanimation keine zusätzliche Arbeit verursacht.
class CozyCatBackdrop extends StatelessWidget {
  const CozyCatBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF100A22)),
          Opacity(
            opacity: 0.58,
            child: Image.asset(
              'assets/cat_slot/ui/vegascat.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x77201438),
                  Color(0xAA120B25),
                  Color(0xF20B0717),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          const CustomPaint(painter: _CozyLightPainter()),
        ],
      ),
    );
  }
}

class _CozyLightPainter extends CustomPainter {
  const _CozyLightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    const lights = <(double, double, double, Color)>[
      (0.09, 0.16, 17, Color(0x55F6D78B)),
      (0.86, 0.12, 23, Color(0x445ED7D0)),
      (0.78, 0.40, 12, Color(0x44F4B8D4)),
      (0.18, 0.52, 14, Color(0x33D7B7FF)),
      (0.91, 0.72, 18, Color(0x33F6D78B)),
    ];
    for (final light in lights) {
      glowPaint.color = light.$4;
      canvas.drawCircle(
        Offset(size.width * light.$1, size.height * light.$2),
        light.$3,
        glowPaint,
      );
    }

    final pawPaint = Paint()..color = const Color(0x18FFF1C1);
    const paws = <(double, double, double)>[
      (0.08, 0.74, -0.28),
      (0.17, 0.84, 0.18),
      (0.83, 0.81, -0.14),
      (0.92, 0.91, 0.24),
    ];
    for (final paw in paws) {
      canvas.save();
      canvas.translate(size.width * paw.$1, size.height * paw.$2);
      canvas.rotate(paw.$3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 16, height: 13),
        pawPaint,
      );
      for (final toe in const [
        Offset(-8, -9),
        Offset(-2.5, -13),
        Offset(3.5, -13),
        Offset(9, -8),
      ]) {
        canvas.drawCircle(toe, 3.5, pawPaint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CozyLightPainter oldDelegate) => false;
}
