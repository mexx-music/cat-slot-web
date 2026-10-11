import 'dart:math';

import 'package:flutter/material.dart';

import '../cat_slot_styles.dart';

/// Lightweight, purely visual transfer of an already credited reward.
/// One controller and one painter animate the complete stream.
class CoinFlyOverlay extends StatefulWidget {
  final Offset startCenter;
  final Offset targetCenter;
  final VoidCallback onDone;
  final void Function(int coinIndex)? onCoinArrived;
  final bool reduceMotion;

  const CoinFlyOverlay({
    super.key,
    required this.startCenter,
    required this.targetCenter,
    required this.onDone,
    this.onCoinArrived,
    this.reduceMotion = false,
  });

  @override
  State<CoinFlyOverlay> createState() => _CoinFlyOverlayState();
}

class _CoinFlyOverlayState extends State<CoinFlyOverlay>
    with SingleTickerProviderStateMixin {
  static const int _count = CatSlotStyles.coinCount;
  static const double _segment =
      1 - CatSlotStyles.coinStaggerFraction * (_count - 1);

  late final AnimationController _controller;
  final List<bool> _arrived = List.filled(_count, false);
  bool _doneFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CatSlotStyles.coinFlyDuration,
    )..addListener(_notifyArrivals);

    if (widget.reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishImmediately());
    } else {
      _controller.forward().whenComplete(_finish);
    }
  }

  void _notifyArrivals() {
    final progress = _controller.value;
    for (var i = 0; i < _count; i++) {
      final arrival = i * CatSlotStyles.coinStaggerFraction + _segment;
      if (!_arrived[i] && progress >= arrival) {
        _arrived[i] = true;
        widget.onCoinArrived?.call(i);
      }
    }
  }

  void _finishImmediately() {
    if (!mounted || _doneFired) return;
    for (var i = 0; i < _count; i++) {
      if (!_arrived[i]) widget.onCoinArrived?.call(i);
      _arrived[i] = true;
    }
    _finish();
  }

  void _finish() {
    if (!mounted || _doneFired) return;
    _doneFired = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_notifyArrivals)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return const SizedBox.expand();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _CoinFlightPainter(
              progress: _controller.value,
              start: widget.startCenter,
              target: widget.targetCenter,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _CoinFlightPainter extends CustomPainter {
  static const List<double> _arcHeights = [82, 112, 94, 126, 76];
  static const List<double> _sideDrift = [-24, 17, -9, 27, 4];

  final double progress;
  final Offset start;
  final Offset target;

  const _CoinFlightPainter({
    required this.progress,
    required this.start,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const count = CatSlotStyles.coinCount;
    const stagger = CatSlotStyles.coinStaggerFraction;
    const segment = 1 - stagger * (count - 1);

    for (var i = 0; i < count; i++) {
      final raw = ((progress - i * stagger) / segment).clamp(0.0, 1.0);
      if (raw <= 0) continue;

      final t = Curves.easeInOutCubic.transform(raw);
      final arc = sin(t * pi);
      final position = Offset(
        _lerp(start.dx, target.dx, t) + arc * _sideDrift[i],
        _lerp(start.dy, target.dy, t) - arc * _arcHeights[i],
      );
      final enter = (raw / 0.14).clamp(0.0, 1.0);
      final exit = raw < 0.84 ? 1.0 : ((1 - raw) / 0.16).clamp(0.0, 1.0);
      final radius = CatSlotStyles.coinSize * 0.5 * enter * (1 - t * 0.28);

      if (raw > 0.08 && raw < 0.82) {
        _drawPaw(
          canvas,
          Offset(position.dx - 11, position.dy + 14),
          2.5 + arc * 2,
          0.18 + arc * 0.28,
        );
      }
      _drawCoin(canvas, position, radius, exit, t + i * 0.13);

      final arrivalAge = ((progress - (i * stagger + segment)) / 0.12).clamp(
        0.0,
        1.0,
      );
      if (arrivalAge > 0 && arrivalAge < 1) {
        final ring = Paint()
          ..color = CatSlotStyles.winGoldLight.withValues(
            alpha: (1 - arrivalAge) * 0.5,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(target, 10 + arrivalAge * 25, ring);
      }
    }
  }

  void _drawCoin(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
    double phase,
  ) {
    if (radius <= 0 || opacity <= 0) return;
    final squash = 0.76 + sin(phase * pi * 4).abs() * 0.24;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(squash, 1);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: [
          CatSlotStyles.winGoldLight.withValues(alpha: opacity),
          CatSlotStyles.winLineColor.withValues(alpha: opacity),
          CatSlotStyles.winGoldDeep.withValues(alpha: opacity),
        ],
      ).createShader(rect);
    canvas.drawCircle(Offset.zero, radius, fill);
    canvas.drawCircle(
      Offset.zero,
      radius * 0.76,
      Paint()
        ..color = const Color(0xFF8A5A12).withValues(alpha: opacity * 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _drawPaw(canvas, Offset.zero, radius * 0.32, opacity * 0.76);
    canvas.restore();
  }

  void _drawPaw(Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = const Color(0xFF6C4310).withValues(alpha: opacity);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.35),
        width: radius * 1.55,
        height: radius * 1.25,
      ),
      paint,
    );
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * radius * 0.62;
      canvas.drawCircle(
        Offset(center.dx + dx, center.dy - radius * 0.72),
        radius * 0.34,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CoinFlightPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.start != start ||
      oldDelegate.target != target;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
