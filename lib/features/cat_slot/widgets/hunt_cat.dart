import 'dart:math';

import 'package:flutter/material.dart';

enum HuntCatState { idle, alert, pounce, catching, miss, celebrate }

enum HuntCatAccessory { none, santaHat, hardHat, sunglasses, driverVest }

/// Visual configuration kept independent from the hunt logic so a future
/// symbol set can supply its own hunter without changing Mouse Hunt.
class HunterCatAppearance {
  final String sourceSetId;
  final Color fur;
  final Color markings;
  final Color accent;
  final HuntCatAccessory accessory;

  const HunterCatAppearance({
    required this.sourceSetId,
    required this.fur,
    required this.markings,
    required this.accent,
    this.accessory = HuntCatAccessory.none,
  });

  static const standard = HunterCatAppearance(
    sourceSetId: 'standard',
    fur: Color(0xFFF2B85B),
    markings: Color(0xFF8D572F),
    accent: Color(0xFF8CE4DC),
  );

  factory HunterCatAppearance.forSymbolSetId(String setId) {
    return switch (setId) {
      'santa_cats' => const HunterCatAppearance(
        sourceSetId: 'santa_cats',
        fur: Color(0xFFF2B85B),
        markings: Color(0xFF8D572F),
        accent: Color(0xFFE75252),
        accessory: HuntCatAccessory.santaHat,
      ),
      'construction_cats' => const HunterCatAppearance(
        sourceSetId: 'construction_cats',
        fur: Color(0xFFD99A52),
        markings: Color(0xFF75462C),
        accent: Color(0xFFFFD04D),
        accessory: HuntCatAccessory.hardHat,
      ),
      'beach_cats' => const HunterCatAppearance(
        sourceSetId: 'beach_cats',
        fur: Color(0xFFF1C37B),
        markings: Color(0xFF9A6338),
        accent: Color(0xFF55D4E8),
        accessory: HuntCatAccessory.sunglasses,
      ),
      'trucker_cats' => const HunterCatAppearance(
        sourceSetId: 'trucker_cats',
        fur: Color(0xFFC88B54),
        markings: Color(0xFF68402D),
        accent: Color(0xFF5B83C6),
        accessory: HuntCatAccessory.driverVest,
      ),
      _ => HunterCatAppearance.standard,
    };
  }
}

class HuntCat extends StatelessWidget {
  final HuntCatState state;
  final HunterCatAppearance appearance;
  final double phase;
  final double idlePhase;
  final bool facingRight;
  final double size;

  const HuntCat({
    super.key,
    required this.state,
    required this.appearance,
    required this.phase,
    required this.idlePhase,
    required this.facingRight,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      HuntCatState.idle => 'wartet',
      HuntCatState.alert => 'aufmerksam',
      HuntCatState.pounce => 'springt',
      HuntCatState.catching => 'fängt',
      HuntCatState.miss => 'verfehlt',
      HuntCatState.celebrate => 'feiert',
    };
    return Semantics(
      label: 'Katzenstatus: $label',
      child: SizedBox(
        key: const ValueKey('hunter-cat'),
        width: size,
        height: size * 0.88,
        child: CustomPaint(
          key: ValueKey('hunter-cat-${state.name}'),
          painter: _HuntCatPainter(
            state: state,
            appearance: appearance,
            phase: phase,
            idlePhase: idlePhase,
            facingRight: facingRight,
          ),
        ),
      ),
    );
  }
}

class _HuntCatPainter extends CustomPainter {
  final HuntCatState state;
  final HunterCatAppearance appearance;
  final double phase;
  final double idlePhase;
  final bool facingRight;

  const _HuntCatPainter({
    required this.state,
    required this.appearance,
    required this.phase,
    required this.idlePhase,
    required this.facingRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final direction = facingRight ? 1.0 : -1.0;
    final tailWave = sin(idlePhase * pi * 2) * 0.08;

    canvas.save();
    if (!facingRight) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }

    if (state == HuntCatState.alert) {
      canvas.translate(0, h * 0.035);
      canvas.scale(1.02, 0.96);
    } else if (state == HuntCatState.pounce) {
      canvas.translate(w * 0.5, h * 0.5);
      canvas.rotate(direction * -0.07 * sin(phase * pi));
      canvas.scale(1.10, 0.88);
      canvas.translate(-w * 0.5, -h * 0.5);
    } else if (state == HuntCatState.miss) {
      canvas.translate(w * 0.5, h * 0.55);
      canvas.rotate(sin(phase * pi * 3) * 0.07);
      canvas.translate(-w * 0.5, -h * 0.55);
    } else if (state == HuntCatState.celebrate) {
      canvas.translate(0, -sin(phase * pi) * h * 0.045);
    }

    final shadow = Paint()..color = const Color(0x55000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.88),
        width: w * 0.68,
        height: h * 0.13,
      ),
      shadow,
    );

    final outline = Paint()
      ..color = const Color(0xFF39233B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fur = Paint()..color = appearance.fur;
    final markings = Paint()..color = appearance.markings;
    final cream = Paint()..color = const Color(0xFFFFE6B0);

    final tail = Path()
      ..moveTo(w * 0.28, h * 0.70)
      ..cubicTo(
        w * (0.06 - tailWave),
        h * 0.71,
        w * (0.08 + tailWave),
        h * 0.40,
        w * 0.22,
        h * 0.46,
      );
    canvas.drawPath(tail, outline..strokeWidth = w * 0.13);
    canvas.drawPath(
      tail,
      Paint()
        ..color = appearance.fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round,
    );

    final bodyRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.66),
      width: w * 0.54,
      height: h * 0.48,
    );
    canvas.drawOval(bodyRect, outline..strokeWidth = w * 0.035);
    canvas.drawOval(bodyRect, fur);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.53, h * 0.70),
        width: w * 0.26,
        height: h * 0.30,
      ),
      cream,
    );

    final headCenter = Offset(w * 0.53, h * 0.35);
    final earLeft = Path()
      ..moveTo(w * 0.31, h * 0.29)
      ..lineTo(w * 0.33, h * 0.04)
      ..lineTo(w * 0.48, h * 0.20)
      ..close();
    final earRight = Path()
      ..moveTo(w * 0.59, h * 0.18)
      ..lineTo(w * 0.73, h * 0.04)
      ..lineTo(w * 0.75, h * 0.31)
      ..close();
    canvas.drawPath(earLeft, outline);
    canvas.drawPath(earRight, outline);
    canvas.drawPath(earLeft, fur);
    canvas.drawPath(earRight, fur);
    canvas.drawCircle(headCenter, w * 0.245, outline);
    canvas.drawCircle(headCenter, w * 0.225, fur);

    for (final x in [0.43, 0.53, 0.63]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * x, h * 0.18),
            width: w * 0.045,
            height: h * 0.12,
          ),
          Radius.circular(w * 0.02),
        ),
        markings,
      );
    }

    _drawFace(canvas, size, cream, markings);
    _drawPaws(canvas, size, fur, outline);
    _drawAccessory(canvas, size);
    canvas.restore();
  }

  void _drawFace(Canvas canvas, Size size, Paint cream, Paint markings) {
    final w = size.width;
    final h = size.height;
    final face = Paint()
      ..color = const Color(0xFF2B2030)
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final blink = state == HuntCatState.celebrate;

    if (state == HuntCatState.miss) {
      for (final x in [0.45, 0.61]) {
        canvas.drawLine(
          Offset(w * (x - 0.025), h * 0.32),
          Offset(w * (x + 0.025), h * 0.37),
          face,
        );
        canvas.drawLine(
          Offset(w * (x + 0.025), h * 0.32),
          Offset(w * (x - 0.025), h * 0.37),
          face,
        );
      }
    } else if (blink) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.45, h * 0.35),
          width: w * 0.08,
          height: h * 0.05,
        ),
        0,
        pi,
        false,
        face,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.61, h * 0.35),
          width: w * 0.08,
          height: h * 0.05,
        ),
        0,
        pi,
        false,
        face,
      );
    } else {
      final eyeRadius = state == HuntCatState.alert ? w * 0.037 : w * 0.027;
      canvas.drawCircle(
        Offset(w * 0.45, h * 0.35),
        eyeRadius,
        face..style = PaintingStyle.fill,
      );
      canvas.drawCircle(Offset(w * 0.61, h * 0.35), eyeRadius, face);
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.53, h * 0.44),
        width: w * 0.27,
        height: h * 0.19,
      ),
      cream,
    );
    final nose = Path()
      ..moveTo(w * 0.49, h * 0.41)
      ..lineTo(w * 0.57, h * 0.41)
      ..lineTo(w * 0.53, h * 0.46)
      ..close();
    canvas.drawPath(nose, markings);
    face.style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.47, h * 0.42, w * 0.06, h * 0.08),
      0,
      pi * 0.8,
      false,
      face,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.53, h * 0.42, w * 0.06, h * 0.08),
      pi * 0.2,
      pi * 0.8,
      false,
      face,
    );

    for (final y in [0.42, 0.47]) {
      canvas.drawLine(
        Offset(w * 0.39, h * y),
        Offset(w * 0.18, h * (y - 0.02)),
        face,
      );
      canvas.drawLine(
        Offset(w * 0.67, h * y),
        Offset(w * 0.88, h * (y - 0.02)),
        face,
      );
    }
  }

  void _drawPaws(Canvas canvas, Size size, Paint fur, Paint outline) {
    final w = size.width;
    final h = size.height;
    final reaching = state == HuntCatState.catching;
    final pawY = reaching ? h * 0.53 : h * 0.79;
    final rightX = reaching ? w * 0.88 : w * 0.63;
    for (final center in [Offset(w * 0.41, h * 0.79), Offset(rightX, pawY)]) {
      canvas.drawCircle(center, w * 0.105, outline..strokeWidth = w * 0.03);
      canvas.drawCircle(center, w * 0.09, fur);
    }
    if (reaching) {
      final claws = Paint()
        ..color = const Color(0xFFFFE6B0)
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(w * (0.91 + i * 0.025), h * 0.49),
          Offset(w * (0.95 + i * 0.025), h * 0.45),
          claws,
        );
      }
    }
  }

  void _drawAccessory(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = Paint()..color = appearance.accent;
    switch (appearance.accessory) {
      case HuntCatAccessory.none:
        break;
      case HuntCatAccessory.santaHat:
        final hat = Path()
          ..moveTo(w * 0.35, h * 0.18)
          ..lineTo(w * 0.53, -h * 0.05)
          ..lineTo(w * 0.69, h * 0.18)
          ..close();
        canvas.drawPath(hat, accent);
        canvas.drawCircle(
          Offset(w * 0.55, 0),
          w * 0.055,
          Paint()..color = Colors.white,
        );
      case HuntCatAccessory.hardHat:
        canvas.drawArc(
          Rect.fromLTWH(w * 0.34, h * 0.04, w * 0.38, h * 0.28),
          pi,
          pi,
          true,
          accent,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.31, h * 0.17, w * 0.45, h * 0.05),
          accent,
        );
      case HuntCatAccessory.sunglasses:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.38, h * 0.29, w * 0.13, h * 0.11),
            Radius.circular(w * 0.03),
          ),
          accent,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.55, h * 0.29, w * 0.13, h * 0.11),
            Radius.circular(w * 0.03),
          ),
          accent,
        );
      case HuntCatAccessory.driverVest:
        canvas.drawArc(
          Rect.fromLTWH(w * 0.34, h * 0.55, w * 0.38, h * 0.34),
          0,
          pi,
          true,
          accent,
        );
    }
  }

  @override
  bool shouldRepaint(_HuntCatPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.phase != phase ||
      oldDelegate.idlePhase != idlePhase ||
      oldDelegate.facingRight != facingRight ||
      oldDelegate.appearance != appearance;
}
