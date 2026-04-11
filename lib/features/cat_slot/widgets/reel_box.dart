import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';
import '../data/slot_symbols.dart';
import '../models/slot_symbol.dart';
import 'symbol_display.dart';

/// Zeigt eine einzelne Slot-Rolle mit 3 sichtbaren Symbolen.
///
/// - [spinning]       : true → Band scrollt kontinuierlich
/// - [targetSymbol]   : das mittlere Symbol, das nach dem Stopp sichtbar sein soll
/// - [highlightCenter]: true → mittleres Symbol pulsiert (Gewinn-Hervorhebung)
class ReelBox extends StatefulWidget {
  final bool spinning;
  final String targetSymbol;
  final bool highlightCenter;

  const ReelBox({
    super.key,
    required this.spinning,
    required this.targetSymbol,
    this.highlightCenter = false,
  });

  @override
  State<ReelBox> createState() => _ReelBoxState();
}

class _ReelBoxState extends State<ReelBox>
    with TickerProviderStateMixin {
  static const double _s = CatSlotStyles.reelSymbolSize;
  static const int _bandSize = 32;

  late AnimationController _scrollCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late List<SlotSymbol> _band;
  Timer? _stopTimer;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _band = _buildBand(null);

    _scrollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (widget.spinning) _startSpinning();
    if (widget.highlightCenter && !widget.spinning) _startPulse();
  }

  @override
  void didUpdateWidget(ReelBox old) {
    super.didUpdateWidget(old);

    // Scroll-Logik
    if (widget.spinning && !old.spinning) {
      _stopTimer?.cancel();
      _startSpinning();
    } else if (!widget.spinning && old.spinning) {
      _scheduleStop();
    }

    // Pulse-Logik
    if (widget.highlightCenter && !widget.spinning) {
      if (!_pulseCtrl.isAnimating) _startPulse();
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  // ── Band aufbauen ─────────────────────────────────────────────
  List<SlotSymbol> _buildBand(String? targetEmoji) {
    final rng = Random();
    final all = kSlotSymbols;
    final band = List.generate(_bandSize, (_) => all[rng.nextInt(all.length)]);
    if (targetEmoji != null) {
      // Ziel-Symbol per Emoji suchen, Fallback: erstes Symbol
      final target = all.firstWhere(
        (s) => s.emoji == targetEmoji,
        orElse: () => all.first,
      );
      band[1] = target;
    }
    return band;
  }

  // ── Endlos-Scroll ────────────────────────────────────────────
  void _startSpinning() {
    _scrollCtrl.addListener(_onTick);
    _scrollCtrl.repeat();
  }

  void _onTick() {
    setState(() {
      _offset += _s * _scrollCtrl.velocity * 0.016;
    });
  }

  void _scheduleStop() {
    _stopTimer?.cancel();
    _stopTimer = Timer(Duration.zero, _snapToTarget);
  }

  void _snapToTarget() {
    if (!mounted) return;
    _scrollCtrl.removeListener(_onTick);
    _scrollCtrl.stop();
    final newBand = _buildBand(widget.targetSymbol);
    setState(() {
      _band = newBand;
      _offset = 0.0;
    });
  }

  // ── Puls-Animation ───────────────────────────────────────────
  void _startPulse() {
    _pulseCtrl.repeat(reverse: true);
  }

  double get _displayOffset {
    if (_band.isEmpty) return 0;
    return _offset % (_band.length * _s);
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _scrollCtrl.removeListener(_onTick);
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double w = CatSlotStyles.reelWidth;
    const double h = CatSlotStyles.reelWindowHeight;

    final double dy = _displayOffset;
    final double totalH = _band.length * _s;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: CatSlotStyles.reelBackground,
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        border: Border.all(color: CatSlotStyles.reelBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 4),
            color: CatSlotStyles.reelShadow,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Scrollendes Band ──────────────────────────────────────
            AnimatedBuilder(
              animation: _scrollCtrl,
              builder: (_, __) {
                return Stack(
                  children: [
                    Positioned(
                      top: dy - totalH,
                      left: 0,
                      width: w,
                      height: totalH,
                      child: _buildBandColumn(w),
                    ),
                    Positioned(
                      top: dy,
                      left: 0,
                      width: w,
                      height: totalH,
                      child: _buildBandColumn(w),
                    ),
                  ],
                );
              },
            ),

            // ── Puls-Glow über dem mittleren Symbol ──────────────────
            if (widget.highlightCenter && !widget.spinning)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) {
                  final glow = _pulseAnim.value;
                  return Positioned(
                    top: _s,
                    left: 0,
                    right: 0,
                    height: _s,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            CatSlotStyles.winPulseColor
                                .withValues(alpha: 0.18 + glow * 0.30),
                            CatSlotStyles.winPulseColor
                                .withValues(alpha: 0.0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CatSlotStyles.winPulseColor
                                .withValues(alpha: 0.25 + glow * 0.35),
                            blurRadius: 12 + glow * 16,
                            spreadRadius: glow * 4,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // ── Trennlinien ───────────────────────────────────────────
            Positioned(
              top: _s - 1,
              left: 0,
              right: 0,
              child: Container(height: 2, color: const Color(0x33000000)),
            ),
            Positioned(
              top: _s * 2 - 1,
              left: 0,
              right: 0,
              child: Container(height: 2, color: const Color(0x33000000)),
            ),

            // ── Gradient-Overlay ──────────────────────────────────────
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x55F8F4FF), // oben leicht abdunkeln
                      Color(0x00F8F4FF),
                      Color(0x00F8F4FF),
                      Color(0x55F8F4FF), // unten leicht abdunkeln
                    ],
                    stops: [0.0, 0.22, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandColumn(double w) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _band
          .map(
            (symbol) => SizedBox(
              width: w,
              height: _s,
              child: Center(
                child: SymbolDisplay(symbol: symbol),
              ),
            ),
          )
          .toList(),
    );
  }
}

