import 'dart:math';
import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Öffentliches Widget
// ─────────────────────────────────────────────────────────────────────────────

/// 3-Phasen Coin-Collect-Animation:
///   1. Hero-Coin erscheint groß und schön (coinHeroDuration)
///   2. Kurze Hold-Pause (coinHoldDuration)
///   3. Kleine Coins fliegen zeitversetzt von startCenter → targetCenter
class CoinFlyOverlay extends StatefulWidget {
  final Offset startCenter;
  final Offset targetCenter;
  final VoidCallback onDone;

  const CoinFlyOverlay({
    super.key,
    required this.startCenter,
    required this.targetCenter,
    required this.onDone,
  });

  @override
  State<CoinFlyOverlay> createState() => _CoinFlyOverlayState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State – Phasen-Management
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { hero, hold, fly }

class _CoinFlyOverlayState extends State<CoinFlyOverlay>
    with TickerProviderStateMixin {
  static const int _count = CatSlotStyles.coinCount;

  _Phase _phase = _Phase.hero;

  // ── Hero-Coin Animationen ────────────────────────────────────
  late final AnimationController _heroCtrl;
  late final Animation<double>   _heroScale;
  late final Animation<double>   _heroOpacity;
  // Puls nach dem Einblenden
  late final AnimationController _heroPulseCtrl;
  late final Animation<double>   _heroPulse;

  // ── Fly-Coins ────────────────────────────────────────────────
  final List<AnimationController> _flyCtrl  = [];
  final List<Animation<double>>   _flyAnim  = [];
  final List<Offset>              _scatter  = [];
  bool _doneFired = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    // Hero einblenden
    _heroCtrl = AnimationController(
      vsync: this,
      duration: CatSlotStyles.coinHeroDuration,
    );
    _heroScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut),
    );
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut),
    );

    // Puls während Hold
    _heroPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _heroPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _heroPulseCtrl, curve: Curves.easeInOut),
    );

    // Fly-Coins vorbereiten
    for (int i = 0; i < _count; i++) {
      _scatter.add(Offset(
        (_rng.nextDouble() - 0.5) * 90,
        (_rng.nextDouble() - 0.5) * 70,
      ));
      final c = AnimationController(
        vsync: this,
        duration: CatSlotStyles.coinFlyDuration,
      );
      _flyCtrl.add(c);
      _flyAnim.add(CurvedAnimation(parent: c, curve: Curves.easeInCubic));
    }

    _startHeroPhase();
  }

  // ── Phase 1: Hero einblenden ─────────────────────────────────
  void _startHeroPhase() {
    setState(() => _phase = _Phase.hero);
    _heroCtrl.forward().then((_) {
      if (!mounted) return;
      _heroPulseCtrl.repeat(reverse: true);
      _startHoldPhase();
    });
  }

  // ── Phase 2: Hold ────────────────────────────────────────────
  void _startHoldPhase() {
    setState(() => _phase = _Phase.hold);
    Future.delayed(CatSlotStyles.coinHoldDuration, () {
      if (!mounted) return;
      _heroPulseCtrl.stop();
      // Hero ausblenden
      _heroCtrl.reverse().then((_) {
        if (mounted) _startFlyPhase();
      });
    });
  }

  // ── Phase 3: Coins fliegen ───────────────────────────────────
  void _startFlyPhase() {
    setState(() => _phase = _Phase.fly);
    for (int i = 0; i < _count; i++) {
      Future.delayed(
        Duration(milliseconds: i * CatSlotStyles.coinStaggerMs),
        () {
          if (mounted) _flyCtrl[i].forward();
        },
      );
    }
    // onDone nach letzter Münze
    _flyCtrl.last.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_doneFired) {
        _doneFired = true;
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _heroPulseCtrl.dispose();
    for (final c in _flyCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // ── Hero-Coin (Phasen hero + hold) ───────────────────
          if (_phase == _Phase.hero || _phase == _Phase.hold)
            AnimatedBuilder(
              animation: Listenable.merge([_heroCtrl, _heroPulseCtrl]),
              builder: (_, __) {
                return Positioned(
                  left: widget.startCenter.dx -
                      CatSlotStyles.heroCoinSize / 2,
                  top: widget.startCenter.dy -
                      CatSlotStyles.heroCoinSize / 2,
                  child: Opacity(
                    opacity: _heroOpacity.value,
                    child: Transform.scale(
                      scale: _heroScale.value * _heroPulse.value,
                      child: const _HeroCoin(),
                    ),
                  ),
                );
              },
            ),

          // ── Fly-Coins (Phase fly) ─────────────────────────────
          if (_phase == _Phase.fly)
            ...List.generate(_count, (i) {
              final start = widget.startCenter + _scatter[i];
              final end   = widget.targetCenter;
              return AnimatedBuilder(
                animation: _flyAnim[i],
                builder: (_, __) {
                  final t = _flyAnim[i].value;
                  final pos = Offset(
                    _lerp(start.dx, end.dx, t),
                    _lerp(start.dy, end.dy, t) - sin(t * pi) * 48,
                  );
                  final scale   = (1.0 - t * 0.6).clamp(0.1, 1.0);
                  final opacity = t < 0.72
                      ? 1.0
                      : ((1.0 - t) / 0.28).clamp(0.0, 1.0);
                  return Positioned(
                    left: pos.dx - CatSlotStyles.coinSize / 2,
                    top:  pos.dy - CatSlotStyles.coinSize / 2,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: const _FlyCoin(),
                      ),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

// ─────────────────────────────────────────────────────────────────────────────
// Große Hero-Coin (CustomPainter)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCoin extends StatelessWidget {
  const _HeroCoin();

  @override
  Widget build(BuildContext context) {
    const s = CatSlotStyles.heroCoinSize;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _HeroCoinPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pfoten-Symbol
              Text(
                '🐾',
                style: TextStyle(
                  fontSize: s * 0.28,
                  height: 1.0,
                ),
              ),
              Text(
                'PURR',
                style: TextStyle(
                  fontSize: s * 0.13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7A4A00),
                  letterSpacing: 2.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // ── Äußerer Glow ─────────────────────────────────────────
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.55);
    canvas.drawCircle(Offset(cx, cy), r, glowPaint);

    // ── Haupt-Coin: radialer Verlauf ─────────────────────────
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.85,
        colors: const [
          Color(0xFFFFF176), // helles Gelb oben-links
          Color(0xFFFFD700), // Gold Mitte
          Color(0xFFB8860B), // dunkles Gold unten
          Color(0xFF8B6914), // tiefstes Gold
        ],
        stops: const [0.0, 0.38, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.95, bodyPaint);

    // ── Äußerer Rand ─────────────────────────────────────────
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..color = const Color(0xFF8B6914);
    canvas.drawCircle(Offset(cx, cy), r * 0.92, rimPaint);

    // ── Innerer Rand ─────────────────────────────────────────
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.025
      ..color = const Color(0xFFFFE566).withValues(alpha: 0.7);
    canvas.drawCircle(Offset(cx, cy), r * 0.78, innerRimPaint);

    // ── Glanz-Highlight (oben-links) ─────────────────────────
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.6),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.95, highlightPaint);

    // ── Unterer Schatten (Tiefenwirkung) ─────────────────────
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, 0.6),
        radius: 0.6,
        colors: [
          const Color(0xFF5A3A00).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.95, shadowPaint);
  }

  @override
  bool shouldRepaint(_HeroCoinPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Kleine Flug-Münze
// ─────────────────────────────────────────────────────────────────────────────

class _FlyCoin extends StatelessWidget {
  const _FlyCoin();

  @override
  Widget build(BuildContext context) {
    const s = CatSlotStyles.coinSize;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: _FlyCoinPainter()),
    );
  }
}

class _FlyCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Glow
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.5),
    );

    // Haupt-Kreis
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.9,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: const [
            Color(0xFFFFF176),
            Color(0xFFFFD700),
            Color(0xFFB8860B),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // Rand
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0xFF8B6914),
    );

    // Highlight
    canvas.drawCircle(
      Offset(cx * 0.7, cy * 0.7),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_FlyCoinPainter old) => false;
}
