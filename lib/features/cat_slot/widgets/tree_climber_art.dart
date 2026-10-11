import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/tree_climber_system.dart';

enum TreeCatPose { idle, ready, jump, climb, land, slip, celebrate }

class TreeClimberSymbol extends StatelessWidget {
  final double size;

  const TreeClimberSymbol({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tree Climber Bonus',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const _TreeSymbolPainter()),
    ),
  );
}

class _TreeSymbolPainter extends CustomPainter {
  const _TreeSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      s * .47,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8F0CD), Color(0xFF30795D)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      center,
      s * .45,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .035
        ..color = const Color(0xFFFFE5A0),
    );
    final trunk = Paint()
      ..color = const Color(0xFF75432C)
      ..strokeWidth = s * .16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * .54, s * .76), Offset(s * .54, s * .25), trunk);
    canvas.drawLine(
      Offset(s * .52, s * .48),
      Offset(s * .25, s * .39),
      trunk..strokeWidth = s * .075,
    );
    canvas.drawLine(Offset(s * .54, s * .33), Offset(s * .76, s * .25), trunk);
    final leaf = Paint()..color = const Color(0xFF4FAF70);
    for (final p in const [
      Offset(.28, .28),
      Offset(.47, .18),
      Offset(.68, .22),
      Offset(.78, .39),
    ]) {
      canvas.drawCircle(Offset(s * p.dx, s * p.dy), s * .16, leaf);
    }
    _paintCat(canvas, Offset(s * .35, s * .42), s * .22, TreeCatPose.climb, 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TreeClimberScene extends StatelessWidget {
  final double worldSeconds;
  final int sectionsReached;
  final double catX;
  final TreeClimberSection section;
  final TreeJumpTrajectory? trajectory;
  final bool showPreview;
  final double jumpProgress;
  final double cameraProgress;
  final double cameraStartY;
  final bool jumpSuccess;
  final TreeCatPose pose;
  final bool reduceMotion;

  const TreeClimberScene({
    super.key,
    required this.worldSeconds,
    required this.sectionsReached,
    required this.catX,
    required this.section,
    required this.trajectory,
    required this.showPreview,
    required this.jumpProgress,
    this.cameraProgress = 1,
    this.cameraStartY = TreeClimberPhysics.startY,
    required this.jumpSuccess,
    required this.pose,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _TreeScenePainter(
        worldSeconds: worldSeconds,
        sectionsReached: sectionsReached,
        catX: catX,
        section: section,
        trajectory: trajectory,
        showPreview: showPreview,
        jumpProgress: jumpProgress,
        cameraProgress: cameraProgress,
        cameraStartY: cameraStartY,
        jumpSuccess: jumpSuccess,
        pose: pose,
        reduceMotion: reduceMotion,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _TreeScenePainter extends CustomPainter {
  final double worldSeconds;
  final int sectionsReached;
  final double catX;
  final TreeClimberSection section;
  final TreeJumpTrajectory? trajectory;
  final bool showPreview;
  final double jumpProgress;
  final double cameraProgress;
  final double cameraStartY;
  final bool jumpSuccess;
  final TreeCatPose pose;
  final bool reduceMotion;

  const _TreeScenePainter({
    required this.worldSeconds,
    required this.sectionsReached,
    required this.catX,
    required this.section,
    required this.trajectory,
    required this.showPreview,
    required this.jumpProgress,
    required this.cameraProgress,
    required this.cameraStartY,
    required this.jumpSuccess,
    required this.pose,
    required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9BD6D0), Color(0xFFF6D6A2), Color(0xFF294F43)],
          stops: [0, .58, 1],
        ).createShader(rect),
    );
    _paintSunlight(canvas, size);
    _paintHills(canvas, size);
    _paintTree(canvas, size);
    _paintAmbientLife(canvas, size);
    _paintBranches(canvas, size);
    if (showPreview && trajectory != null) {
      _paintTrajectoryPreview(canvas, size, trajectory!);
    }
    _paintHero(canvas, size);
    if (sectionsReached >= 9) _paintSummitFriend(canvas, size);
  }

  void _paintSunlight(Canvas canvas, Size size) {
    final sun = Offset(size.width * .78, size.height * .12);
    canvas.drawCircle(
      sun,
      size.shortestSide * .12,
      Paint()
        ..shader = ui.Gradient.radial(sun, size.shortestSide * .18, const [
          Color(0xCCFFF4B8),
          Color(0x00FFF4B8),
        ]),
    );
    final ray = Paint()..color = const Color(0x16FFF7C7);
    for (var i = 0; i < 4; i++) {
      final path = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(size.width * (.15 + i * .23), size.height)
        ..lineTo(size.width * (.27 + i * .23), size.height)
        ..close();
      canvas.drawPath(path, ray);
    }
  }

  void _paintHills(Canvas canvas, Size size) {
    final far = Path()
      ..moveTo(0, size.height * .56)
      ..quadraticBezierTo(
        size.width * .25,
        size.height * .44,
        size.width * .48,
        size.height * .57,
      )
      ..quadraticBezierTo(
        size.width * .75,
        size.height * .40,
        size.width,
        size.height * .56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0x55477B68));
  }

  void _paintTree(Canvas canvas, Size size) {
    final trunk = Path()
      ..moveTo(size.width * .34, size.height)
      ..cubicTo(
        size.width * .38,
        size.height * .72,
        size.width * .40,
        size.height * .34,
        size.width * .46,
        -.05 * size.height,
      )
      ..lineTo(size.width * .68, -.05 * size.height)
      ..cubicTo(
        size.width * .64,
        size.height * .38,
        size.width * .70,
        size.height * .74,
        size.width * .72,
        size.height,
      )
      ..close();
    canvas.drawPath(
      trunk,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF57382D), Color(0xFF96603B), Color(0xFF4A3028)],
        ).createShader(Offset.zero & size),
    );
    final bark = Paint()
      ..color = const Color(0x55412B23)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (.10 + i * .12);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * (.52 + (i.isEven ? .03 : 0)), y),
          width: size.width * .17,
          height: 18,
        ),
        .15,
        2.4,
        false,
        bark,
      );
    }
  }

  void _paintBranches(Canvas canvas, Size size) {
    final currentY = ui.lerpDouble(
      cameraStartY,
      TreeClimberPhysics.startY,
      cameraProgress,
    )!;
    final targetY = currentY - section.heightGain;
    _branch(canvas, size, catX, currentY, width: .34, current: true);
    _branch(
      canvas,
      size,
      section.targetX,
      targetY,
      width: section.branchWidth,
      target: true,
    );
    _branch(
      canvas,
      size,
      .24 + (sectionsReached % 3) * .17,
      targetY - .28,
      width: .18,
    );
    _branch(
      canvas,
      size,
      .78 - (sectionsReached % 2) * .44,
      targetY - .52,
      width: .16,
    );
  }

  void _branch(
    Canvas canvas,
    Size size,
    double x,
    double y, {
    required double width,
    bool current = false,
    bool target = false,
  }) {
    if (y < -.05 || y > 1.05) return;
    final center = Offset(size.width * x, size.height * y);
    final halfWidth = size.width * width / 2;
    final start = center.translate(-halfWidth, 0);
    final end = center.translate(halfWidth, 0);
    final nearestEnd = x < .55 ? end : start;
    final trunk = Offset(size.width * .55, center.dy + 8);
    final branch = Paint()
      ..color = current ? const Color(0xFF8A5938) : const Color(0xFF6F472F)
      ..strokeWidth = current ? 18 : 15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(trunk, nearestEnd, branch..strokeWidth = 10);
    canvas.drawLine(start, end, branch..strokeWidth = current ? 18 : 15);
    canvas.drawLine(
      start.translate(2, -3),
      end.translate(-2, -3),
      Paint()
        ..color = const Color(0x55F5D49C)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (target) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: halfWidth * 2 + 8, height: 28),
          const Radius.circular(16),
        ),
        Paint()
          ..color = const Color(0x55FFF0A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final leafPaint = Paint()..color = const Color(0xFF69A75C);
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(x < .55 ? -halfWidth : halfWidth, -14),
          width: 25,
          height: 13,
        ),
        leafPaint,
      );
    }
  }

  void _paintTrajectoryPreview(
    Canvas canvas,
    Size size,
    TreeJumpTrajectory preview,
  ) {
    final points = preview.previewPoints(
      27,
      TreeClimberPhysics.previewFractionForSection(section.number),
    );
    final glowColor = preview.landsOnBranch
        ? const Color(0xFFFFE08A)
        : const Color(0xFFBDEDE0);
    for (var index = 0; index < points.length; index += 2) {
      final point = points[index];
      if (point.dx < -.05 ||
          point.dx > 1.05 ||
          point.dy < -.08 ||
          point.dy > 1.08) {
        continue;
      }
      final center = Offset(point.dx * size.width, point.dy * size.height);
      final radius = index == points.length - 1 ? 4.0 : 2.5;
      canvas.drawCircle(
        center,
        radius + 4,
        Paint()..color = glowColor.withValues(alpha: .12),
      );
      canvas.drawCircle(center, radius, Paint()..color = glowColor);
    }
  }

  void _paintAmbientLife(Canvas canvas, Size size) {
    final breeze = reduceMotion ? 0.0 : sin(worldSeconds * .7) * 4;
    final leafColors = [
      const Color(0xFF447A4D),
      const Color(0xFF5B9658),
      const Color(0xFF86B968),
    ];
    for (var i = 0; i < 18; i++) {
      final x =
          ((i * 47) % 101) / 100 * size.width + breeze * (i.isEven ? 1 : -1);
      final y = ((i * 83 + sectionsReached * 19) % 100) / 100 * size.height;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 15, height: 8),
        Paint()
          ..color = leafColors[i % leafColors.length].withValues(alpha: .7),
      );
    }
    final butterfly = Offset(
      size.width * (.18 + .03 * sin(worldSeconds)),
      size.height * .25,
    );
    final wing = Paint()..color = const Color(0xFFD9A5E8);
    canvas.drawOval(
      Rect.fromCenter(center: butterfly.translate(-5, 0), width: 10, height: 7),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(center: butterfly.translate(5, 0), width: 10, height: 7),
      wing,
    );
  }

  void _paintHero(Canvas canvas, Size size) {
    var x = catX;
    var branchY = ui.lerpDouble(
      cameraStartY,
      TreeClimberPhysics.startY,
      cameraProgress,
    )!;
    var y = branchY - .055;
    var currentPose = pose;
    if ((pose == TreeCatPose.jump || pose == TreeCatPose.climb) &&
        trajectory != null) {
      const crouchShare = .10;
      if (jumpProgress <= crouchShare) {
        currentPose = TreeCatPose.ready;
      } else {
        final physicsProgress =
            ((jumpProgress - crouchShare) / (1 - crouchShare)).clamp(0.0, 1.0);
        final point = trajectory!.positionAtProgress(physicsProgress);
        x = point.dx;
        y = point.dy - .055;
        currentPose = physicsProgress > .78 && jumpSuccess
            ? TreeCatPose.climb
            : TreeCatPose.jump;
      }
    } else if (pose == TreeCatPose.slip) {
      y += sin(pi * jumpProgress.clamp(0, 1)) * .09;
    }
    _paintCat(
      canvas,
      Offset(size.width * x, size.height * y),
      size.shortestSide * .16,
      currentPose,
      worldSeconds,
    );
  }

  void _paintSummitFriend(Canvas canvas, Size size) {
    _paintCat(
      canvas,
      Offset(size.width * .76, size.height * .20),
      size.shortestSide * .12,
      sectionsReached >= 10 ? TreeCatPose.celebrate : TreeCatPose.idle,
      worldSeconds + 1.7,
      cream: true,
    );
    if (sectionsReached >= 10) {
      final heart = Path()
        ..moveTo(size.width * .63, size.height * .12)
        ..cubicTo(
          size.width * .60,
          size.height * .08,
          size.width * .54,
          size.height * .12,
          size.width * .63,
          size.height * .19,
        )
        ..cubicTo(
          size.width * .72,
          size.height * .12,
          size.width * .66,
          size.height * .08,
          size.width * .63,
          size.height * .12,
        );
      canvas.drawPath(heart, Paint()..color = const Color(0xFFE97986));
    }
  }

  @override
  bool shouldRepaint(covariant _TreeScenePainter old) =>
      old.worldSeconds != worldSeconds ||
      old.sectionsReached != sectionsReached ||
      old.catX != catX ||
      old.section != section ||
      old.trajectory != trajectory ||
      old.showPreview != showPreview ||
      old.jumpProgress != jumpProgress ||
      old.cameraProgress != cameraProgress ||
      old.cameraStartY != cameraStartY ||
      old.pose != pose;
}

void _paintCat(
  Canvas canvas,
  Offset center,
  double size,
  TreeCatPose pose,
  double time, {
  bool cream = false,
}) {
  final fur = Paint()
    ..color = cream ? const Color(0xFFF4D6A0) : const Color(0xFFE8974F);
  final dark = Paint()..color = const Color(0xFF56352D);
  final white = Paint()..color = const Color(0xFFFFF4DF);
  final crouch = pose == TreeCatPose.ready ? size * .10 : 0.0;
  final bodyCenter = center.translate(0, size * .12 + crouch);
  canvas.save();
  if (pose == TreeCatPose.jump) canvas.rotateAt(center, -.16);
  canvas.drawOval(
    Rect.fromCenter(center: bodyCenter, width: size * .78, height: size * .84),
    fur,
  );
  final tailPath = Path()
    ..moveTo(bodyCenter.dx + size * .30, bodyCenter.dy + size * .15)
    ..cubicTo(
      bodyCenter.dx + size * .72,
      bodyCenter.dy + size * (.12 + .08 * sin(time * 2)),
      bodyCenter.dx + size * .66,
      bodyCenter.dy - size * .34,
      bodyCenter.dx + size * .48,
      bodyCenter.dy - size * .28,
    );
  canvas.drawPath(
    tailPath,
    Paint()
      ..color = fur.color
      ..strokeWidth = size * .16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
  final head = center.translate(0, -size * .22 + crouch);
  canvas.drawCircle(head, size * .35, fur);
  final leftEar = Path()
    ..moveTo(head.dx - size * .30, head.dy - size * .15)
    ..lineTo(head.dx - size * .20, head.dy - size * .50)
    ..lineTo(head.dx - size * .02, head.dy - size * .28)
    ..close();
  final rightEar = Path()
    ..moveTo(head.dx + size * .30, head.dy - size * .15)
    ..lineTo(head.dx + size * .20, head.dy - size * .50)
    ..lineTo(head.dx + size * .02, head.dy - size * .28)
    ..close();
  canvas.drawPath(leftEar, fur);
  canvas.drawPath(rightEar, fur);
  final blink = pose == TreeCatPose.land || (time % 4.2) > 4.0;
  if (blink) {
    final eye = Paint()
      ..color = dark.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: head.translate(-size * .13, 0),
        width: 8,
        height: 5,
      ),
      0,
      pi,
      false,
      eye,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: head.translate(size * .13, 0),
        width: 8,
        height: 5,
      ),
      0,
      pi,
      false,
      eye,
    );
  } else {
    canvas.drawCircle(head.translate(-size * .13, 0), size * .045, dark);
    canvas.drawCircle(head.translate(size * .13, 0), size * .045, dark);
  }
  canvas.drawCircle(head.translate(0, size * .10), size * .04, dark);
  canvas.drawOval(
    Rect.fromCenter(
      center: bodyCenter.translate(-size * .21, size * .35),
      width: size * .25,
      height: size * .14,
    ),
    white,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: bodyCenter.translate(size * .21, size * .35),
      width: size * .25,
      height: size * .14,
    ),
    white,
  );
  if (pose == TreeCatPose.slip) {
    canvas.drawLine(
      bodyCenter.translate(-size * .20, size * .03),
      bodyCenter.translate(-size * .48, -size * .22),
      Paint()
        ..color = fur.color
        ..strokeWidth = size * .15
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.restore();
}

extension on Canvas {
  void rotateAt(Offset center, double radians) {
    translate(center.dx, center.dy);
    rotate(radians);
    translate(-center.dx, -center.dy);
  }
}
