import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

/// Casino-Credits-Anzeige: Coin-Icon + Zahl + CREDITS-Label.
/// Animiert (Pulse + Glow) wenn sich der Coin-Wert ändert.
class BalanceLabel extends StatefulWidget {
  final int coins;

  const BalanceLabel({super.key, required this.coins});

  @override
  State<BalanceLabel> createState() => _BalanceLabelState();
}

class _BalanceLabelState extends State<BalanceLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _glowT;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 72,
      ),
    ]).animate(_pulseCtrl);
    _glowT = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(BalanceLabel old) {
    super.didUpdateWidget(old);
    if (old.coins != widget.coins) {
      _pulseCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xDD0A0318),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: CatSlotStyles.goldAccent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(
                    212,
                    175,
                    55,
                    0.4 + _glowT.value * 0.55,
                  ),
                  blurRadius: 12 + _glowT.value * 24,
                  spreadRadius: _glowT.value * 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(
                  '${widget.coins}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CatSlotStyles.goldAccent,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CREDITS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xAAD4AF37),
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
