import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/fishing_cat_system.dart';

class FishingCatSymbol extends StatelessWidget {
  final double size;

  const FishingCatSymbol({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: const _FishingSymbolPainter()),
  );
}

class FishingScene extends StatelessWidget {
  final List<FishingTarget> targets;
  final double worldTime;
  final double castValue;
  final FishingTarget? caught;
  final FishingCatPose pose;
  final bool reduceMotion;

  const FishingScene({
    super.key,
    required this.targets,
    required this.worldTime,
    required this.castValue,
    required this.caught,
    required this.pose,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _FishingScenePainter(
        targets: targets,
        worldTime: worldTime,
        castValue: castValue,
        caught: caught,
        pose: pose,
        reduceMotion: reduceMotion,
      ),
      size: Size.infinite,
    ),
  );
}

class _FishingSymbolPainter extends CustomPainter {
  const _FishingSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.width * .46,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFB8F3EA), Color(0xFF277F8C)],
        ).createShader(Offset.zero & size),
    );
    final cat = Paint()..color = const Color(0xFFF5B56D);
    final head = Offset(size.width * .36, size.height * .43);
    canvas.drawCircle(head, size.width * .19, cat);
    final ears = Path()
      ..moveTo(size.width * .22, size.height * .32)
      ..lineTo(size.width * .24, size.height * .10)
      ..lineTo(size.width * .36, size.height * .27)
      ..moveTo(size.width * .40, size.height * .27)
      ..lineTo(size.width * .52, size.height * .10)
      ..lineTo(size.width * .54, size.height * .34);
    canvas.drawPath(ears, cat..style = PaintingStyle.fill);
    final ink = Paint()
      ..color = const Color(0xFF30223D)
      ..strokeWidth = size.width * .035
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(size.width * .31, size.height * .42), 2, ink);
    canvas.drawCircle(Offset(size.width * .43, size.height * .42), 2, ink);
    canvas.drawLine(
      Offset(size.width * .48, size.height * .52),
      Offset(size.width * .82, size.height * .19),
      ink,
    );
    canvas.drawLine(
      Offset(size.width * .82, size.height * .19),
      Offset(size.width * .82, size.height * .66),
      ink..strokeWidth = 1.4,
    );
    _drawFish(
      canvas,
      Offset(size.width * .74, size.height * .72),
      size.width * .1,
      const Color(0xFFFFD76B),
      true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FishingScenePainter extends CustomPainter {
  final List<FishingTarget> targets;
  final double worldTime;
  final double castValue;
  final FishingTarget? caught;
  final FishingCatPose pose;
  final bool reduceMotion;

  const _FishingScenePainter({
    required this.targets,
    required this.worldTime,
    required this.castValue,
    required this.caught,
    required this.pose,
    required this.reduceMotion,
  });

  Offset _p(Size size, Offset normalized) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF183D54), Color(0xFF176A70), Color(0xFF0B4656)],
          stops: [0, .27, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .12),
      size.shortestSide * .055,
      Paint()..color = const Color(0xFFFFEDB0),
    );
    final waterTop = size.height * .29;
    final wave = Paint()
      ..color = const Color(0x5579E4DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var row = 0; row < 5; row++) {
      final y = waterTop + row * size.height * .13;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 18) {
        final phase = reduceMotion ? 0 : worldTime * .7;
        path.lineTo(x, y + math.sin(x / 26 + phase + row) * 2.5);
      }
      canvas.drawPath(path, wave);
    }

    final dock = Paint()..color = const Color(0xFF85553E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, waterTop - 13, size.width * .30, 27),
        const Radius.circular(5),
      ),
      dock,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .08, waterTop, 14, size.height * .32),
      dock..color = const Color(0xFF68402F),
    );

    for (final target in targets) {
      if (caught?.id == target.id) continue;
      if (!target.visibleAt(worldTime)) continue;
      final position = _p(size, target.positionAt(worldTime));
      _drawTarget(canvas, position, target, size);
    }

    final catBob = reduceMotion ? 0.0 : math.sin(worldTime * 2) * 2;
    _drawCat(
      canvas,
      Offset(size.width * .13, waterTop - 42 + catBob),
      size,
      pose,
    );

    final rodStart = Offset(size.width * .22, waterTop - 49 + catBob);
    final rodEnd = Offset(size.width * .68, waterTop - 64);
    final rod = Paint()
      ..color = const Color(0xFFFFD384)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(rodStart, rodEnd, rod);
    final hookY = .18 + math.sin(math.pi * castValue) * .70;
    final hook = _p(size, Offset(.68, hookY));
    canvas.drawLine(
      rodEnd,
      hook,
      Paint()
        ..color = const Color(0xFFD7F8F4)
        ..strokeWidth = 1.4,
    );
    canvas.drawArc(
      Rect.fromCircle(center: hook + const Offset(4, 0), radius: 6),
      .2,
      math.pi * 1.25,
      false,
      Paint()
        ..color = const Color(0xFFEAFDFA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (caught case final target?) {
      _drawTarget(canvas, hook + const Offset(0, 10), target, size);
    }
  }

  void _drawCat(Canvas canvas, Offset c, Size size, FishingCatPose pose) {
    final scale = size.shortestSide / 360;
    final body = Paint()..color = const Color(0xFFF0A762);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, 16 * scale),
        width: 57 * scale,
        height: 49 * scale,
      ),
      body,
    );
    canvas.drawCircle(c, 28 * scale, body);
    final ears = Path()
      ..moveTo(c.dx - 21 * scale, c.dy - 15 * scale)
      ..lineTo(c.dx - 17 * scale, c.dy - 39 * scale)
      ..lineTo(c.dx - 4 * scale, c.dy - 22 * scale)
      ..moveTo(c.dx + 5 * scale, c.dy - 22 * scale)
      ..lineTo(c.dx + 19 * scale, c.dy - 39 * scale)
      ..lineTo(c.dx + 22 * scale, c.dy - 14 * scale);
    canvas.drawPath(ears, body);
    final eye = Paint()..color = const Color(0xFF35243A);
    final surprised = pose == FishingCatPose.surprise;
    canvas.drawCircle(
      c + Offset(-9 * scale, -2 * scale),
      surprised ? 3.4 : 2.3,
      eye,
    );
    canvas.drawCircle(
      c + Offset(9 * scale, -2 * scale),
      surprised ? 3.4 : 2.3,
      eye,
    );
    canvas.drawCircle(
      c + Offset(0, 8 * scale),
      pose == FishingCatPose.success ? 4 : 2.4,
      eye,
    );
  }

  void _drawTarget(Canvas canvas, Offset p, FishingTarget target, Size size) {
    final radius = target.size * size.shortestSide;
    if (target.kind == FishingCatchKind.boot) {
      final paint = Paint()..color = const Color(0xFF704B43);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: radius, height: radius * 1.5),
          Radius.circular(radius * .25),
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: p + Offset(radius * .42, radius * .55),
          width: radius * 1.3,
          height: radius * .55,
        ),
        paint,
      );
      return;
    }
    if (target.kind == FishingCatchKind.treasure) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: p,
            width: radius * 1.8,
            height: radius * 1.25,
          ),
          Radius.circular(radius * .25),
        ),
        Paint()..color = const Color(0xFFB8783D),
      );
      canvas.drawRect(
        Rect.fromCenter(center: p, width: radius * .3, height: radius * 1.25),
        Paint()..color = const Color(0xFFFFD76B),
      );
      return;
    }
    if (target.kind == FishingCatchKind.duck) {
      canvas.drawCircle(
        p,
        radius * .65,
        Paint()..color = const Color(0xFFFFDB57),
      );
      canvas.drawCircle(
        p + Offset(radius * .55, -radius * .35),
        radius * .38,
        Paint()..color = const Color(0xFFFFDB57),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: p + Offset(radius, -radius * .28),
          width: radius * .7,
          height: radius * .3,
        ),
        Paint()..color = const Color(0xFFFF8E4A),
      );
      return;
    }
    final color = switch (target.kind) {
      FishingCatchKind.small => const Color(0xFF8AE0D7),
      FishingCatchKind.colorful => const Color(0xFFFF7FA4),
      FishingCatchKind.big => const Color(0xFF6EA9DD),
      FishingCatchKind.swift => const Color(0xFFB58CFF),
      FishingCatchKind.golden => const Color(0xFFFFD255),
      _ => const Color(0xFF8AE0D7),
    };
    _drawFish(canvas, p, radius, color, target.movesRightAt(worldTime));
  }

  @override
  bool shouldRepaint(_FishingScenePainter oldDelegate) =>
      oldDelegate.worldTime != worldTime ||
      oldDelegate.castValue != castValue ||
      oldDelegate.caught?.id != caught?.id ||
      oldDelegate.pose != pose ||
      oldDelegate.targets != targets;
}

void _drawFish(
  Canvas canvas,
  Offset p,
  double radius,
  Color color,
  bool right,
) {
  final direction = right ? 1.0 : -1.0;
  canvas.save();
  canvas.translate(p.dx, p.dy);
  canvas.scale(direction, 1);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2.4,
      height: radius * 1.25,
    ),
    Paint()..color = color,
  );
  final tail = Path()
    ..moveTo(-radius, 0)
    ..lineTo(-radius * 1.65, -radius * .72)
    ..lineTo(-radius * 1.65, radius * .72)
    ..close();
  canvas.drawPath(tail, Paint()..color = color.withValues(alpha: .86));
  canvas.drawCircle(
    Offset(radius * .56, -radius * .13),
    radius * .11,
    Paint()..color = const Color(0xFF263445),
  );
  canvas.restore();
}
