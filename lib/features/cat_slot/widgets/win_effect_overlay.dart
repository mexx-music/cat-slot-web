import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../cat_slot_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 1 – WIN REVEAL BURST
//
// Kurzer, knackiger Pop über der Gewinnreihe. Ergänzt die existierende
// per-Reel-Center-Pulse mit einem expandierenden Gold-Ring und einem
// horizontalen Shine-Sweep über die Mittelreihe.
//
// Wird positioniert direkt in den Reel-Stack, deckt die Mittelreihe ab.
// ─────────────────────────────────────────────────────────────────────────────

class WinRevealBurst extends StatefulWidget {
  /// Sichtbarkeit – steuert Start/Stop der einmaligen Reveal-Animation.
  final bool visible;

  const WinRevealBurst({super.key, required this.visible});

  @override
  State<WinRevealBurst> createState() => _WinRevealBurstState();
}

class _WinRevealBurstState extends State<WinRevealBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: CatSlotStyles.winRevealDuration,
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.visible) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(WinRevealBurst old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _ctrl.forward(from: 0);
    } else if (!widget.visible && old.visible) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Position: zentriert über der mittleren Symbol-Reihe.
    return IgnorePointer(
      child: SizedBox(
        width: CatSlotStyles.reelRowWidth,
        height: CatSlotStyles.reelWindowHeight,
        child: AnimatedBuilder(
          animation: _t,
          builder: (_, __) {
            final t = _t.value;
            if (t == 0.0 || t == 1.0 && !widget.visible) {
              return const SizedBox.shrink();
            }
            return Stack(
              children: [
                // ── Expandierender Gold-Ring ────────────────────────────
                Positioned(
                  top: CatSlotStyles.reelSymbolSize,
                  left: 0,
                  right: 0,
                  height: CatSlotStyles.reelSymbolSize,
                  child: Center(
                    child: _ExpandingRing(progress: t),
                  ),
                ),
                // ── Horizontaler Shine-Sweep über der Mittelreihe ────────
                Positioned(
                  top: CatSlotStyles.reelSymbolSize,
                  left: 0,
                  right: 0,
                  height: CatSlotStyles.reelSymbolSize,
                  child: ClipRect(
                    child: CustomPaint(
                      painter: _SweepPainter(progress: t),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExpandingRing extends StatelessWidget {
  final double progress; // 0..1

  const _ExpandingRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Ring wächst von 0 auf eine Größe ≈ Win-Reihen-Breite
    final maxSize = CatSlotStyles.reelRowWidth * 0.75;
    final size = maxSize * progress;
    // Fade-Out gegen Ende
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: CatSlotStyles.winLineColor.withValues(alpha: 0.85),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CatSlotStyles.winLineColor.withValues(alpha: 0.55),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final double progress; // 0..1
  _SweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Sweep nur in der ersten Hälfte sichtbar, dann ausgeblendet
    final localT = (progress / 0.6).clamp(0.0, 1.0);
    final fade = (1.0 - (progress - 0.4).clamp(0.0, 1.0) / 0.6).clamp(0.0, 1.0);
    if (fade <= 0.0) return;
    final bandWidth = size.width * 0.22;
    final cx = -bandWidth + (size.width + bandWidth * 2) * localT;
    final rect = Rect.fromLTWH(cx - bandWidth / 2, 0, bandWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          CatSlotStyles.winGoldLight.withValues(alpha: 0.55 * fade),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 2 – LUXUS WIN-PANEL
//
// Mehrstufiges, hochwertiges Overlay. Sequenz intern gesteuert:
//   1. Dimmer fadet ein                          (200ms)
//   2. Phase-1-Dwell: Reel-Pulse + Burst wirken  (winPhase1Dwell)
//   3. Rays + Glow starten, Panel skaliert ein   (600ms entry)
//   4. Counter tickt von 0 → coinsWon            (winCounterDuration)
//   5. COLLECT-Button bleibt am unteren Ende     (jederzeit klickbar nach Panel-Entry)
// ─────────────────────────────────────────────────────────────────────────────

class WinPanel extends StatefulWidget {
  final bool visible;
  final int coinsWon;
  final VoidCallback onCollect;

  const WinPanel({
    super.key,
    required this.visible,
    required this.coinsWon,
    required this.onCollect,
  });

  @override
  State<WinPanel> createState() => _WinPanelState();
}

class _WinPanelState extends State<WinPanel> with TickerProviderStateMixin {
  // Dimmer
  late final AnimationController _dimCtrl;
  // Panel-Entry (scale + fade)
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<double> _entryScale;
  // Endless: Rays + Glow + Sparkles
  late final AnimationController _raysCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _sparkleCtrl;
  // Counter
  late final AnimationController _counterCtrl;

  Timer? _phase2Timer;
  bool _panelEntered = false;

  @override
  void initState() {
    super.initState();

    _dimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _raysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _counterCtrl = AnimationController(
      vsync: this,
      duration: CatSlotStyles.winCounterDuration,
    );

    if (widget.visible) _startSequence();
  }

  void _startSequence() {
    _dimCtrl.forward(from: 0);
    _phase2Timer?.cancel();
    _phase2Timer = Timer(CatSlotStyles.winPhase1Dwell, () {
      if (!mounted) return;
      setState(() => _panelEntered = true);
      _entryCtrl.forward(from: 0);
      _raysCtrl.repeat();
      _glowCtrl.repeat(reverse: true);
      _sparkleCtrl.repeat();
      _counterCtrl.forward(from: 0);
    });
  }

  void _stopSequence() {
    _phase2Timer?.cancel();
    _raysCtrl.stop();
    _glowCtrl.stop();
    _sparkleCtrl.stop();
    _counterCtrl.stop();
    _entryCtrl.reverse();
    _dimCtrl.reverse();
    _panelEntered = false;
  }

  @override
  void didUpdateWidget(WinPanel old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _startSequence();
    } else if (!widget.visible && old.visible) {
      _stopSequence();
    }
  }

  @override
  void dispose() {
    _phase2Timer?.cancel();
    _dimCtrl.dispose();
    _entryCtrl.dispose();
    _raysCtrl.dispose();
    _glowCtrl.dispose();
    _sparkleCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  String _tierLabel() {
    if (widget.coinsWon >= CatSlotStyles.winTierMega) return 'MEGA WIN!';
    if (widget.coinsWon >= CatSlotStyles.winTierBig) return 'BIG WIN!';
    return 'YOU WIN!';
  }

  double _tierFontSize() {
    if (widget.coinsWon >= CatSlotStyles.winTierMega) return 56;
    if (widget.coinsWon >= CatSlotStyles.winTierBig) return 48;
    return 42;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _dimCtrl,
        builder: (_, __) {
          final dim = _dimCtrl.value;
          // Während Phase-1-Dwell ist das Panel selbst noch nicht da –
          // nur ein sanfter Dimmer liegt über dem Spiel.
          return Container(
            color: Color.fromRGBO(10, 6, 28, 0.55 * dim),
            child: !_panelEntered
                ? const SizedBox.expand()
                : Center(
                    child: FadeTransition(
                      opacity: _entryFade,
                      child: ScaleTransition(
                        scale: _entryScale,
                        child: _buildPanel(context),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Rotierende radiale Strahlen hinter dem Panel ─────────
        SizedBox(
          width: 480,
          height: 480,
          child: AnimatedBuilder(
            animation: _raysCtrl,
            builder: (_, __) => CustomPaint(
              painter: _RaysPainter(angle: _raysCtrl.value * 2 * pi),
            ),
          ),
        ),
        // ── Sparkles ──────────────────────────────────────────────
        SizedBox(
          width: 420,
          height: 420,
          child: AnimatedBuilder(
            animation: _sparkleCtrl,
            builder: (_, __) =>
                CustomPaint(painter: _SparklesPainter(t: _sparkleCtrl.value)),
          ),
        ),
        // ── Panel-Karte ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, child) {
            final g = Curves.easeInOut.transform(_glowCtrl.value);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 26,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF26104A),
                    Color(0xFF14072E),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: CatSlotStyles.winLineColor,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CatSlotStyles.winLineColor.withValues(
                      alpha: 0.55 + g * 0.30,
                    ),
                    blurRadius: 50 + g * 30,
                    spreadRadius: 6 + g * 6,
                  ),
                  BoxShadow(
                    color: CatSlotStyles.winLineColor.withValues(
                      alpha: 0.20 + g * 0.10,
                    ),
                    blurRadius: 140,
                    spreadRadius: 24,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Tier-Titel (WIN / BIG WIN / MEGA WIN) ────────────
              _TitleText(
                text: _tierLabel(),
                fontSize: _tierFontSize(),
              ),
              const SizedBox(height: 14),
              // ── Star: Counter-Betrag ─────────────────────────────
              AnimatedBuilder(
                animation: _counterCtrl,
                builder: (_, __) {
                  final eased = Curves.easeOut.transform(_counterCtrl.value);
                  final shown = (eased * widget.coinsWon).round();
                  return _AmountText(amount: shown);
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'PURRCOINS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: Color(0xFFE8D27A),
                ),
              ),
              const SizedBox(height: 22),
              // ── COLLECT-Button (mit Reward-Bezug) ────────────────
              ElevatedButton(
                onPressed: widget.onCollect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CatSlotStyles.winLineColor,
                  foregroundColor: const Color(0xFF1A0A3B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 38,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text('COLLECT +${widget.coinsWon}'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tier-Titel mit Gold-Gradient + Glow ─────────────────────────────────────

class _TitleText extends StatelessWidget {
  final String text;
  final double fontSize;

  const _TitleText({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          CatSlotStyles.winGoldLight,
          CatSlotStyles.winLineColor,
          CatSlotStyles.winGoldDeep,
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: Colors.white, // wird durch ShaderMask überlagert
          shadows: [
            Shadow(
              color: CatSlotStyles.winLineColor.withValues(alpha: 1.0),
              blurRadius: 26,
            ),
            Shadow(
              color: CatSlotStyles.winLineColor.withValues(alpha: 0.55),
              blurRadius: 60,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Großer Betrag (der eigentliche Star) ────────────────────────────────────

class _AmountText extends StatelessWidget {
  final int amount;

  const _AmountText({required this.amount});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          CatSlotStyles.winGoldLight,
          CatSlotStyles.winLineColor,
        ],
      ).createShader(rect),
      child: Text(
        '+$amount',
        style: TextStyle(
          fontSize: 76,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: Colors.white,
          height: 1.0,
          shadows: [
            Shadow(
              color: CatSlotStyles.winLineColor.withValues(alpha: 0.95),
              blurRadius: 30,
            ),
            Shadow(
              color: CatSlotStyles.winLineColor.withValues(alpha: 0.5),
              blurRadius: 70,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rotierende Strahlen hinter dem Panel ────────────────────────────────────

class _RaysPainter extends CustomPainter {
  final double angle;
  _RaysPainter({required this.angle});

  static const int _rayCount = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          CatSlotStyles.winLineColor.withValues(alpha: 0.35),
          CatSlotStyles.winLineColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));

    final step = (2 * pi) / _rayCount;
    final half = step * 0.22; // schmale Strahlen mit viel Luft dazwischen
    for (int i = 0; i < _rayCount; i++) {
      final a = i * step;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(cos(a - half) * r, sin(a - half) * r)
        ..lineTo(cos(a + half) * r, sin(a + half) * r)
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.angle != angle;
}

// ── Sparkle-Partikel rund um das Panel ──────────────────────────────────────

class _SparklesPainter extends CustomPainter {
  final double t; // 0..1 loop
  _SparklesPainter({required this.t});

  // Fixe Pseudo-Random-Sparkle-Definitionen (deterministisch, kein Jitter)
  static final List<_Sparkle> _sparkles = List.generate(14, (i) {
    final rng = Random(i * 13 + 7);
    return _Sparkle(
      angle: rng.nextDouble() * 2 * pi,
      radiusFrac: 0.55 + rng.nextDouble() * 0.45, // 0.55..1.0
      sizePx: 4.0 + rng.nextDouble() * 6.0,
      phase: rng.nextDouble(),
      speed: 0.7 + rng.nextDouble() * 0.8,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.shortestSide / 2;

    for (final s in _sparkles) {
      final localT = (t * s.speed + s.phase) % 1.0;
      // Sägezahn-artiger Sparkle: schnell auf, langsamer ab
      final opacity = localT < 0.3
          ? (localT / 0.3)
          : (1.0 - (localT - 0.3) / 0.7);
      final scale = 0.5 + (1.0 - (localT - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.6;
      final size = s.sizePx * scale;
      final r = maxR * s.radiusFrac;
      final pos = Offset(cx + cos(s.angle) * r, cy + sin(s.angle) * r);
      final paint = Paint()
        ..color = CatSlotStyles.winGoldLight
            .withValues(alpha: opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      // 4-strahliger Stern
      final path = Path()
        ..moveTo(pos.dx, pos.dy - size)
        ..lineTo(pos.dx + size * 0.25, pos.dy - size * 0.25)
        ..lineTo(pos.dx + size, pos.dy)
        ..lineTo(pos.dx + size * 0.25, pos.dy + size * 0.25)
        ..lineTo(pos.dx, pos.dy + size)
        ..lineTo(pos.dx - size * 0.25, pos.dy + size * 0.25)
        ..lineTo(pos.dx - size, pos.dy)
        ..lineTo(pos.dx - size * 0.25, pos.dy - size * 0.25)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter old) => old.t != t;
}

class _Sparkle {
  final double angle;
  final double radiusFrac;
  final double sizePx;
  final double phase;
  final double speed;

  const _Sparkle({
    required this.angle,
    required this.radiusFrac,
    required this.sizePx,
    required this.phase,
    required this.speed,
  });
}
