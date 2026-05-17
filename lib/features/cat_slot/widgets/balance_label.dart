import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

/// Casino-Credits-Anzeige: Coin-Icon + Zahl + CREDITS-Label.
/// Rein visuell – keine Logik.
class BalanceLabel extends StatelessWidget {
  final int coins;

  const BalanceLabel({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xDD0A0318),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: CatSlotStyles.goldAccent, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x66D4AF37), blurRadius: 12, spreadRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            '$coins',
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
    );
  }
}
