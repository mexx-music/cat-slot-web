import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';
import '../data/slot_symbols.dart';

/// Zeigt eine einzelne Slot-Rolle mit 3 sichtbaren Symbolen.
///
/// - [spinning]     : true → Band scrollt kontinuierlich
/// - [targetSymbol] : das mittlere Symbol, das nach dem Stopp sichtbar sein soll
///
/// Das mittlere Symbol gilt als Ergebnis-Symbol.
class ReelBox extends StatefulWidget {
  final bool spinning;
  final String targetSymbol;

  const ReelBox({
    super.key,
    required this.spinning,
    required this.targetSymbol,
  });

  @override
  State<ReelBox> createState() => _ReelBoxState();
}

class _ReelBoxState extends State<ReelBox>
    with SingleTickerProviderStateMixin {
  static const double _s = CatSlotStyles.reelSymbolSize;
  static const int _bandSize = 32; // Anzahl Symbole im Band

  late AnimationController _ctrl;
  late List<String> _band;  // langes Band aus Emojis
  Timer? _stopTimer;

  // Aktueller Pixel-Offset (absolut, nach unten positiv)
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _band = _buildBand(null);
    _ctrl = AnimationController(
      vsync: this,
      // Eine "Umdrehung" = ein Symbol-Slot (_s Pixel)
      duration: const Duration(milliseconds: 120),
    );
    if (widget.spinning) _startSpinning();
  }

  @override
  void didUpdateWidget(ReelBox old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) {
      _stopTimer?.cancel();
      _startSpinning();
    } else if (!widget.spinning && old.spinning) {
      _scheduleStop();
    }
  }

  // ── Band aufbauen ─────────────────────────────────────────────
  List<String> _buildBand(String? ensureAtCenter) {
    final rng = Random();
    final all = kSlotSymbols.map((s) => s.emoji).toList();
    final band = List.generate(
      _bandSize,
      (_) => all[rng.nextInt(all.length)],
    );
    // Ziel-Symbol an eine feste Position setzen (Index 1 = Mitte des
    // ersten sichtbaren Fensters im oberen Teil des Bandes)
    if (ensureAtCenter != null) {
      band[1] = ensureAtCenter;
    }
    return band;
  }

  // ── Endlos-Scroll starten ────────────────────────────────────
  void _startSpinning() {
    _ctrl.addListener(_onTick);
    _ctrl.repeat();
  }

  void _onTick() {
    setState(() {
      _offset += _s * _ctrl.velocity * 0.016; // ~px pro Frame
    });
  }

  // ── Sanft auf Ziel-Position einrasten ───────────────────────
  void _scheduleStop() {
    _stopTimer?.cancel();
    _stopTimer = Timer(Duration.zero, _snapToTarget);
  }

  void _snapToTarget() {
    if (!mounted) return;
    _ctrl.removeListener(_onTick);
    _ctrl.stop();

    // Ziel-Symbol ins neue Band einbauen
    final newBand = _buildBand(widget.targetSymbol);

    // Wir wollen, dass nach dem Einrasten `_offset` so steht, dass
    // `newBand[1]` in der Mitte des Fensters zu sehen ist.
    // Fenster-Mitte = Symbol-Index 1 → top-offset = -_s * 1 + _s  (= 0-Linie)
    // Wir scrollen den aktuellen Offset auf die nächste "saubere" Ziel-Position.
    const double targetOffset = 0.0; // Band[1] landet genau in Fenster-Mitte

    setState(() {
      _band = newBand;
      _offset = targetOffset;
    });
  }

  // ── Normierter Offset fürs Rendering ────────────────────────
  double get _displayOffset {
    if (_band.isEmpty) return 0;
    final totalHeight = _band.length * _s;
    // Offset nach unten scrollen → Modulo für nahtlosen Loop
    return _offset % totalHeight;
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double w = CatSlotStyles.reelWidth;
    const double h = CatSlotStyles.reelWindowHeight; // = 3 * _s

    final double dy = _displayOffset;
    final double totalH = _band.length * _s;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: CatSlotStyles.reelBackground,
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        border: Border.all(color: CatSlotStyles.reelBorder),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: CatSlotStyles.reelShadow,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Scrollendes Band (doppelt gerendert für nahtlosen Loop) ──
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Stack(
                  children: [
                    // Erste Kopie
                    Positioned(
                      top: dy - totalH,
                      left: 0,
                      width: w,
                      height: totalH,
                      child: _buildBandColumn(w),
                    ),
                    // Zweite Kopie (direkt dahinter)
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

            // ── Trennlinien ──────────────────────────────────────────────
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

            // ── Gradient-Overlay ─────────────────────────────────────────
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99F8F4FF),
                      Color(0x00F8F4FF),
                      Color(0x00F8F4FF),
                      Color(0x99F8F4FF),
                    ],
                    stops: [0.0, 0.25, 0.75, 1.0],
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
            (e) => SizedBox(
              width: w,
              height: _s,
              child: Center(
                child: Text(
                  e,
                  style: const TextStyle(
                    fontSize: CatSlotStyles.reelEmojiFontSize,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
