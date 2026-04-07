import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

/// Zeigt eine einzelne Slot-Rolle mit 3 sichtbaren Symbolen.
///
/// - [symbols]  : die 3 aktuell sichtbaren Emojis [oben, mitte, unten]
/// - [spinning] : true  → Band scrollt nach unten
///                false → Band steht still
///
/// Das mittlere Symbol (Index 1) gilt als Ergebnis-Symbol.
class ReelBox extends StatefulWidget {
  final List<String> symbols; // genau 3 Einträge
  final bool spinning;

  const ReelBox({
    super.key,
    required this.symbols,
    required this.spinning,
  });

  @override
  State<ReelBox> createState() => _ReelBoxState();
}

class _ReelBoxState extends State<ReelBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(ReelBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.spinning && _ctrl.isAnimating) {
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
    const double s = CatSlotStyles.reelSymbolSize;
    const double w = CatSlotStyles.reelWidth;
    const double h = CatSlotStyles.reelWindowHeight; // = 3 * s

    // Band: 4 Symbole → beim Scroll von 0→s entsteht nahtloser Loop
    final List<String> band = [
      widget.symbols[2], // extra oben
      widget.symbols[0],
      widget.symbols[1],
      widget.symbols[2],
    ];

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
      // ClipRRect + Stack mit hardEdge: verhindert jeden Render-Overflow
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Scrollendes Band ──────────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                // _ctrl.value 0→1 entspricht einer Symbol-Höhe Versatz
                final dy = _ctrl.value * s - s;
                return Positioned(
                  top: dy,
                  left: 0,
                  width: w,
                  height: s * band.length,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: band
                        .map((e) => SizedBox(
                              width: w,
                              height: s,
                              child: Center(
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    fontSize: CatSlotStyles.reelEmojiFontSize,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
            ),

            // ── Trennlinien (oben/unten des mittleren Symbols) ───
            Positioned(
              top: s - 1,
              left: 0,
              right: 0,
              child: Container(height: 2, color: const Color(0x33000000)),
            ),
            Positioned(
              top: s * 2 - 1,
              left: 0,
              right: 0,
              child: Container(height: 2, color: const Color(0x33000000)),
            ),

            // ── Gradient-Overlay (oben/unten abdunkeln) ──────────
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
}
