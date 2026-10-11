import 'dart:math';

import 'package:flutter/material.dart';

import '../cat_slot_styles.dart';

/// A short light sweep with tiny paw glints over the winning row.
class WinRevealBurst extends StatefulWidget {
  final bool visible;
  final bool reduceMotion;
  final bool bigWin;

  const WinRevealBurst({
    super.key,
    required this.visible,
    this.reduceMotion = false,
    this.bigWin = false,
  });

  @override
  State<WinRevealBurst> createState() => _WinRevealBurstState();
}

class _WinRevealBurstState extends State<WinRevealBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CatSlotStyles.winRevealDuration,
    );
    if (widget.visible && !widget.reduceMotion) _controller.forward();
  }

  @override
  void didUpdateWidget(WinRevealBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _controller
        ..stop()
        ..value = widget.visible ? 1 : 0;
    } else if (widget.visible && !oldWidget.visible) {
      _controller.forward(from: 0);
    } else if (!widget.visible && oldWidget.visible) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || widget.reduceMotion) {
      return const SizedBox.expand();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _WinRevealPainter(
              progress: _controller.value,
              bigWin: widget.bigWin,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _WinRevealPainter extends CustomPainter {
  final double progress;
  final bool bigWin;

  const _WinRevealPainter({required this.progress, required this.bigWin});

  @override
  void paint(Canvas canvas, Size size) {
    final row = Rect.fromLTWH(
      0,
      CatSlotStyles.reelSymbolSize,
      size.width,
      CatSlotStyles.reelSymbolSize,
    );
    final fade = sin(progress * pi).clamp(0.0, 1.0);
    final bandWidth = size.width * 0.26;
    final x = -bandWidth + (size.width + bandWidth * 2) * progress;
    final sweep = Rect.fromLTWH(
      x - bandWidth / 2,
      row.top,
      bandWidth,
      row.height,
    );
    canvas.save();
    canvas.clipRect(row);
    canvas.drawRect(
      sweep,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            CatSlotStyles.winGoldLight.withValues(alpha: fade * 0.42),
            Colors.transparent,
          ],
        ).createShader(sweep),
    );
    canvas.restore();

    const pawFractions = [0.22, 0.5, 0.78];
    for (var i = 0; i < pawFractions.length; i++) {
      final local = ((progress - i * 0.08) / 0.78).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final alpha = sin(local * pi) * (bigWin ? 0.62 : 0.42);
      final center = Offset(
        size.width * pawFractions[i],
        row.center.dy - sin(local * pi) * (10 + i * 3),
      );
      _drawPaw(canvas, center, 4.2 + (bigWin ? 1.4 : 0), alpha);
    }
  }

  void _drawPaw(Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = CatSlotStyles.winGoldLight.withValues(alpha: opacity);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.25),
        width: radius * 1.6,
        height: radius * 1.25,
      ),
      paint,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(center.dx + (i - 1) * radius * 0.7, center.dy - radius * 0.75),
        radius * 0.34,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WinRevealPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.bigWin != bigWin;
}

/// Inline feedback for the common 3/4 coin wins. It never blocks another spin.
class SmallWinChip extends StatelessWidget {
  final bool visible;
  final int coinsWon;
  final bool reduceMotion;

  const SmallWinChip({
    super.key,
    required this.visible,
    required this.coinsWon,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: visible
          ? Semantics(
              key: const ValueKey('small-win-chip'),
              liveRegion: true,
              label: '$coinsWon PurrCoins gewonnen',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD923183A),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0x99F4D77C)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x332FD1C6), blurRadius: 18),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🐾', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Text(
                        '+$coinsWon PURRCOINS',
                        style: const TextStyle(
                          color: CatSlotStyles.winGoldLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Schnurr!',
                        style: TextStyle(
                          color: Color(0xFF9FE7E0),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(key: ValueKey('small-win-chip-hidden'), height: 0),
    );
  }
}

/// Compact reward panel reserved for 5+ coin wins.
/// The button is available immediately and therefore also acts as skip.
class WinPanel extends StatefulWidget {
  final bool visible;
  final int coinsWon;
  final VoidCallback onCollect;
  final bool reduceMotion;

  const WinPanel({
    super.key,
    required this.visible,
    required this.coinsWon,
    required this.onCollect,
    this.reduceMotion = false,
  });

  @override
  State<WinPanel> createState() => _WinPanelState();
}

class _WinPanelState extends State<WinPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduceMotion
          ? Duration.zero
          : CatSlotStyles.winPanelDuration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    if (widget.visible) _controller.forward();
  }

  @override
  void didUpdateWidget(WinPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.reduceMotion
        ? Duration.zero
        : CatSlotStyles.winPanelDuration;
    if (widget.visible && !oldWidget.visible) {
      _controller.forward(from: 0);
    } else if (!widget.visible && oldWidget.visible) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => widget.coinsWon >= CatSlotStyles.winTierMega
      ? 'CAT-TASTIC!'
      : 'PURRFECT!';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: FadeTransition(
        opacity: _fade,
        child: ColoredBox(
          color: const Color(0x99080516),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ScaleTransition(
                scale: _scale,
                child: RepaintBoundary(child: _buildCard()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Semantics(
      key: const ValueKey('big-win-panel'),
      liveRegion: true,
      label: '${widget.coinsWon} PurrCoins gewonnen',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 370),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF342052), Color(0xFF17102B)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xBFF4D77C), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6643D6CB),
                blurRadius: 42,
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x332FD1C6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x667ADDD5)),
                  ),
                  child: Text(
                    widget.coinsWon >= CatSlotStyles.winTierMega ? '😻' : '😸',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: const TextStyle(
                    color: CatSlotStyles.winGoldLight,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Die Katzen feiern ganz leise.',
                  style: TextStyle(color: Color(0xFFB8DDD9), fontSize: 13),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final counterProgress = widget.reduceMotion
                        ? 1.0
                        : const Interval(
                            0.18,
                            1,
                            curve: Curves.easeOutCubic,
                          ).transform(_controller.value);
                    return Text(
                      '+${(widget.coinsWon * counterProgress).round()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Color(0x99F4D77C), blurRadius: 22),
                        ],
                      ),
                    );
                  },
                ),
                const Text(
                  'PURRCOINS',
                  style: TextStyle(
                    color: Color(0xFFD9C475),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onCollect,
                    icon: const Text('🐾', style: TextStyle(fontSize: 16)),
                    label: const Text('WEITER'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF1D77A),
                      foregroundColor: const Color(0xFF211333),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gewinn bereits gutgeschrieben',
                  style: TextStyle(color: Color(0x88FFFFFF), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
