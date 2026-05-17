import 'dart:math';
import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Öffentliches Widget
// ─────────────────────────────────────────────────────────────────────────────

/// 3-Phasen Coin-Collect-Animation:
///   1. Hero-Coin erscheint groß und schön (coinHeroDuration)
///   2. Kurze Hold-Pause (coinHoldDuration)
///   3. Kleine Coins fliegen zeitversetzt von startCenter → targetCenter,
///      mit echter 3D-Y-Rotation und Impact-Burst am Ziel.
class CoinFlyOverlay extends StatefulWidget {
  final Offset startCenter;
  final Offset targetCenter;
  final VoidCallback onDone;

  /// Called each time one flying coin reaches the target.
  /// [coinIndex] is 0-based; last coin has index coinCount-1.
  final void Function(int coinIndex)? onCoinArrived;

  const CoinFlyOverlay({
    super.key,
    required this.startCenter,
    required this.targetCenter,
    required this.onDone,
    this.onCoinArrived,
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
  late final Animation<double> _heroScale;
  late final Animation<double> _heroOpacity;
  // Puls nach dem Einblenden
  late final AnimationController _heroPulseCtrl;
  late final Animation<double> _heroPulse;

  // ── Fly-Coins ────────────────────────────────────────────────
  final List<AnimationController> _flyCtrl = [];
  final List<Animation<double>> _flyAnim = [];
  final List<Offset> _scatter = [];
  final List<double> _arcHeight = []; // px, varies per coin
  final List<double> _arcBias = []; // lateral drift px
  final List<double> _spinTurns = []; // anzahl ganzer Y-Drehungen
  final List<double> _spinPhase = []; // Start-Phasenversatz
  bool _doneFired = false;
  final _rng = Random();

  // ── Impact-Burst am Ziel ─────────────────────────────────────
  /// Bei jedem ankommenden Coin um 1 hochgezählt – triggert _ImpactBurst.
  int _impactTrigger = 0;

  @override
  void initState() {
    super.initState();

    // Hero einblenden
    _heroCtrl = AnimationController(
      vsync: this,
      duration: CatSlotStyles.coinHeroDuration,
    );
    _heroScale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut));
    _heroOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    // Puls während Hold
    _heroPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _heroPulse = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _heroPulseCtrl, curve: Curves.easeInOut));

    // Fly-Coins vorbereiten
    for (int i = 0; i < _count; i++) {
      // Sehr enger Start-Cluster – Münzen scheinen aus EINEM Punkt zu emergieren.
      _scatter.add(
        Offset((_rng.nextDouble() - 0.5) * 22, (_rng.nextDouble() - 0.5) * 18),
      );
      _arcHeight.add(70.0 + _rng.nextDouble() * 80.0); // 70..150 px Bogenhöhe
      _arcBias.add((_rng.nextDouble() - 0.5) * 60.0); // ±30 px lateral
      _spinTurns.add(1.4 + _rng.nextDouble() * 1.4); // 1.4..2.8 Umdrehungen
      _spinPhase.add(_rng.nextDouble() * 2 * pi);

      final c = AnimationController(
        vsync: this,
        duration: CatSlotStyles.coinFlyDuration,
      );
      // Status listener: notify caller + fire onDone for last coin
      final idx = i;
      c.addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        if (!mounted) return; // widget may already be disposed
        widget.onCoinArrived?.call(idx);
        setState(() => _impactTrigger++);
        if (idx == _count - 1 && !_doneFired) {
          _doneFired = true;
          widget.onDone();
        }
      });
      _flyCtrl.add(c);
      // Sanftes, hochwertiges Easing für alle Coins (kein hektisches Bouncen)
      _flyAnim.add(CurvedAnimation(parent: c, curve: Curves.easeInOutCubic));
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
    // Failsafe: falls der letzte Status-Listener nie feuert, onDone spätestens
    // nach voller Laufzeit aufrufen.
    final safeguard =
        CatSlotStyles.coinFlyDuration +
        Duration(milliseconds: (_count - 1) * CatSlotStyles.coinStaggerMs) +
        const Duration(milliseconds: 300);
    Future.delayed(safeguard, () {
      if (mounted && !_doneFired) {
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
                  left: widget.startCenter.dx - CatSlotStyles.heroCoinSize / 2,
                  top: widget.startCenter.dy - CatSlotStyles.heroCoinSize / 2,
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
              final end = widget.targetCenter;
              final arcH = _arcHeight[i];
              final arcB = _arcBias[i];
              final turns = _spinTurns[i];
              final phase = _spinPhase[i];
              return AnimatedBuilder(
                animation: _flyAnim[i],
                builder: (_, __) {
                  // Coin is invisible until its controller is actually started.
                  if (_flyCtrl[i].status == AnimationStatus.dismissed) {
                    return const SizedBox.shrink();
                  }
                  final t = _flyAnim[i].value;
                  // Sanfter Bogen via Sinus
                  final sinT = sin(t * pi);
                  final pos = Offset(
                    _lerp(start.dx, end.dx, t) + sinT * arcB,
                    _lerp(start.dy, end.dy, t) - sinT * arcH,
                  );
                  // "Burst-out" am Start: Münze ploppt aus dem Hero-Punkt heraus
                  final emerge = t < 0.10 ? (t / 0.10) : 1.0;
                  // Sanft schrumpfen Richtung Ziel
                  final shrink = (1.0 - t * 0.55).clamp(0.45, 1.0);
                  final scale = emerge * shrink;
                  final opacity = t < 0.85
                      ? 1.0
                      : ((1.0 - t) / 0.15).clamp(0.0, 1.0);

                  // Echte 3D-Y-Rotation (flippende Casino-Münze)
                  final spinAngle = (t * 2 * pi * turns) + phase;
                  final showBack = cos(spinAngle) < 0;
                  final perspective = Matrix4.identity()
                    ..setEntry(3, 2, 0.0009)
                    ..rotateY(spinAngle);

                  Widget coin = const _FlyCoin();
                  // Auf der Rückseite spiegelt rotateY die Inhalte – Pfote
                  // soll trotzdem korrekt orientiert bleiben.
                  if (showBack) {
                    coin = Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(-1, 1, 1),
                      child: coin,
                    );
                  }

                  return Positioned(
                    left: pos.dx - CatSlotStyles.coinSize / 2,
                    top: pos.dy - CatSlotStyles.coinSize / 2,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: perspective,
                          child: coin,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // ── Impact-Burst am Credits-Ziel ─────────────────────
          if (_phase == _Phase.fly)
            Positioned(
              left: widget.targetCenter.dx -
                  CatSlotStyles.coinImpactBurstSize / 2,
              top: widget.targetCenter.dy -
                  CatSlotStyles.coinImpactBurstSize / 2,
              width: CatSlotStyles.coinImpactBurstSize,
              height: CatSlotStyles.coinImpactBurstSize,
              child: _ImpactBurst(triggerId: _impactTrigger),
            ),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

// ─────────────────────────────────────────────────────────────────────────────
// Große Hero-Coin (CustomPainter) – unverändert, bewusst bewahrt
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
              Text('🐾', style: TextStyle(fontSize: s * 0.28, height: 1.0)),
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
    final r = size.width / 2;

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
// Kleine Flug-Münze – veredelte PurrCoin
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
  // Pfoten-Stempel via TextPainter (einmal pro Frame, akzeptabel für 5 Coins)
  static final TextPainter _pawPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // ── Äußerer warmer Glow ──────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.55),
    );

    // ── Dunkler äußerer Rand (Tiefen-Kontur) ─────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.96,
      Paint()..color = const Color(0xFF6B4A00),
    );

    // ── Haupt-Disc: radialer Gold-Verlauf ────────────────────
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: const [
          Color(0xFFFFF1A8), // hell oben-links
          Color(0xFFFFD700), // Gold Mitte
          Color(0xFFB8860B), // dunkles Gold unten
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.88, bodyPaint);

    // ── Heller innerer Rand (Doppel-Ring-Look) ───────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = const Color(0xFFFFE680).withValues(alpha: 0.85),
    );

    // ── Pfoten-Stempel in der Mitte ──────────────────────────
    // Natives Emoji – plattformkonsistente Darstellung, mit dezentem
    // dunklem Schatten direkt darunter für leichten Tiefen-Look.
    _pawPainter
      ..text = TextSpan(
        text: '🐾',
        style: TextStyle(
          fontSize: size.width * 0.42,
          height: 1.0,
          shadows: [
            Shadow(
              color: const Color(0xFF3A2400).withValues(alpha: 0.55),
              blurRadius: 1.6,
              offset: Offset(0, size.width * 0.025),
            ),
          ],
        ),
      )
      ..layout();
    _pawPainter.paint(
      canvas,
      Offset(cx - _pawPainter.width / 2, cy - _pawPainter.height / 2),
    );

    // ── Specular-Highlight oben-links (Glanz) ────────────────
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.55, -0.65),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.88, highlightPaint);

    // ── Unterer Schatten für Tiefenwirkung ───────────────────
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, 0.65),
        radius: 0.6,
        colors: [
          const Color(0xFF5A3A00).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.88, shadowPaint);
  }

  @override
  bool shouldRepaint(_FlyCoinPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Impact-Burst – wird bei jedem ankommenden Coin am Ziel ausgelöst.
// Restartet bei jedem triggerId-Wechsel; bestehende Animation wird abgebrochen.
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactBurst extends StatefulWidget {
  final int triggerId;
  const _ImpactBurst({required this.triggerId});

  @override
  State<_ImpactBurst> createState() => _ImpactBurstState();
}

class _ImpactBurstState extends State<_ImpactBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(_ImpactBurst old) {
    super.didUpdateWidget(old);
    if (widget.triggerId != old.triggerId && widget.triggerId > 0) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final t = _t.value;
        if (t == 0.0) return const SizedBox.shrink();
        // Ring wächst und verblasst, kompakter Glow-Kern darunter
        return CustomPaint(
          painter: _ImpactBurstPainter(progress: t),
        );
      },
    );
  }
}

class _ImpactBurstPainter extends CustomPainter {
  final double progress; // 0..1
  _ImpactBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.shortestSide / 2;
    final t = progress;
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    // ── Soft-Glow-Kern (kurzer, satter Impact) ───────────────
    final coreR = maxR * (0.18 + t * 0.45);
    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.55 * opacity),
    );

    // ── Expandierender Gold-Ring ──────────────────────────────
    final ringR = maxR * (0.25 + t * 0.85);
    final ringWidth = (3.0 * (1.0 - t * 0.7)).clamp(0.6, 3.0);
    canvas.drawCircle(
      Offset(cx, cy),
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = const Color(0xFFFFF1A8).withValues(alpha: 0.9 * opacity),
    );

    // ── Zweiter, weiterer Ring für Tiefe ──────────────────────
    final ring2R = maxR * (0.15 + t * 0.6);
    canvas.drawCircle(
      Offset(cx, cy),
      ring2R,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.55 * opacity),
    );
  }

  @override
  bool shouldRepaint(_ImpactBurstPainter old) => old.progress != progress;
}
