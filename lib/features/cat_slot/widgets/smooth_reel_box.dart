import 'dart:math';

import 'package:flutter/material.dart';

import '../cat_slot_styles.dart';
import '../data/slot_symbols.dart';
import '../models/slot_symbol.dart';
import 'symbol_display.dart';

/// Eine performante, weich laufende Slot-Rolle.
///
/// Das Symbolband wird nur beim Start eines Spins erzeugt und anschließend als
/// fertiges Child verschoben. Das tatsächliche Ergebnis kommt weiterhin
/// ausschließlich aus dem CatSlotController.
class SmoothReelBox extends StatefulWidget {
  final bool spinning;
  final String targetSymbol;
  final bool highlightCenter;
  final int reelIndex;
  final bool reduceMotion;

  const SmoothReelBox({
    super.key,
    required this.spinning,
    required this.targetSymbol,
    required this.reelIndex,
    this.highlightCenter = false,
    this.reduceMotion = false,
  });

  @override
  State<SmoothReelBox> createState() => _SmoothReelBoxState();
}

class _SmoothReelBoxState extends State<SmoothReelBox>
    with TickerProviderStateMixin {
  static const double _symbolSize = CatSlotStyles.reelSymbolSize;
  static const int _bandSize = 14;

  final Random _random = Random();
  late final AnimationController _scrollController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late List<SlotSymbol> _band;
  int _landingId = 0;
  bool _hasSpun = false;

  @override
  void initState() {
    super.initState();
    _band = _buildBand();
    _scrollController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 620 + widget.reelIndex * 70),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    if (widget.spinning) _startSpinning();
    if (widget.highlightCenter && !widget.spinning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SmoothReelBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.spinning && !oldWidget.spinning) {
      _startSpinning();
    } else if (!widget.spinning && oldWidget.spinning) {
      _scrollController.stop();
      setState(() {
        _hasSpun = true;
        _landingId++;
      });
    }

    if (widget.highlightCenter && !widget.spinning) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  List<SlotSymbol> _buildBand() {
    final symbols = kSlotSymbols;
    return List.generate(
      _bandSize,
      (_) => symbols[_random.nextInt(symbols.length)],
      growable: false,
    );
  }

  void _startSpinning() {
    setState(() {
      _band = _buildBand();
      _hasSpun = true;
    });
    if (!widget.reduceMotion) _scrollController.repeat();
  }

  List<SlotSymbol> get _landedSymbols {
    final symbols = kSlotSymbols;
    final centerIndex = symbols.indexWhere(
      (symbol) => symbol.emoji == widget.targetSymbol,
    );
    final safeIndex = centerIndex < 0 ? 0 : centerIndex;
    return [
      symbols[(safeIndex - 1 + symbols.length) % symbols.length],
      symbols[safeIndex],
      symbols[(safeIndex + 1) % symbols.length],
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: CatSlotStyles.reelWidth,
        height: CatSlotStyles.reelWindowHeight,
        decoration: BoxDecoration(
          color: CatSlotStyles.reelBackground,
          borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 7),
              color: CatSlotStyles.reelShadow,
            ),
            BoxShadow(
              blurRadius: 14,
              spreadRadius: -2,
              color: Color(0x55D4AF37),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
          border: Border.all(color: CatSlotStyles.reelBorder, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            CatSlotStyles.reelBorderRadius - 2,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.spinning && !widget.reduceMotion
                    ? _buildSpinningBand()
                    : _buildLandedBand(),
              ),
              if (widget.highlightCenter && !widget.spinning) _buildWinGlow(),
              if (widget.spinning && !widget.reduceMotion) _buildLightSweep(),
              const _ReelGlassOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpinningBand() {
    final bandHeight = _band.length * _symbolSize;
    return OverflowBox(
      alignment: Alignment.topCenter,
      minWidth: CatSlotStyles.reelWidth,
      maxWidth: CatSlotStyles.reelWidth,
      minHeight: bandHeight * 2,
      maxHeight: bandHeight * 2,
      child: AnimatedBuilder(
        animation: _scrollController,
        child: SizedBox(
          height: bandHeight * 2,
          child: Column(
            children: [
              _SymbolBand(symbols: _band),
              _SymbolBand(symbols: _band),
            ],
          ),
        ),
        builder: (_, child) {
          return Transform.translate(
            offset: Offset(0, -_scrollController.value * bandHeight),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildLandedBand() {
    final content = _SymbolBand(symbols: _landedSymbols);
    if (!_hasSpun || widget.reduceMotion) return content;
    return TweenAnimationBuilder<double>(
      key: ValueKey('landing-${widget.reelIndex}-$_landingId'),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      tween: Tween(begin: -_symbolSize * 0.46, end: 0),
      builder: (_, value, child) =>
          Transform.translate(offset: Offset(0, value), child: child),
      child: content,
    );
  }

  Widget _buildWinGlow() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final glow = _pulse.value;
        return Positioned(
          top: _symbolSize,
          left: 3,
          right: 3,
          height: _symbolSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CatSlotStyles.winPulseColor.withValues(
                  alpha: 0.35 + glow * 0.4,
                ),
              ),
              gradient: RadialGradient(
                colors: [
                  CatSlotStyles.winPulseColor.withValues(
                    alpha: 0.15 + glow * 0.18,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLightSweep() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (_, __) => Positioned(
        top: -70 + _scrollController.value * 400,
        left: -30,
        right: -30,
        height: 54,
        child: Transform.rotate(
          angle: -0.12,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x22FFFFFF),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SymbolBand extends StatelessWidget {
  final List<SlotSymbol> symbols;

  const _SymbolBand({required this.symbols});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final symbol in symbols)
          SizedBox(
            width: CatSlotStyles.reelWidth,
            height: CatSlotStyles.reelSymbolSize,
            child: Center(child: SymbolDisplay(symbol: symbol)),
          ),
      ],
    );
  }
}

class _ReelGlassOverlay extends StatelessWidget {
  const _ReelGlassOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xAA05020D),
                Color(0x08000000),
                Color(0x08000000),
                Color(0xAA05020D),
              ],
              stops: [0, 0.22, 0.78, 1],
            ),
          ),
        ),
      ),
    );
  }
}
