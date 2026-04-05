import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

/// Zeigt den aktuellen Coin-Stand an, z. B. "Coins: 10".
/// Rein visuell – keine Logik.
class BalanceLabel extends StatelessWidget {
  final int coins;

  const BalanceLabel({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Coins: $coins',
      style: const TextStyle(
        fontSize: CatSlotStyles.balanceFontSize,
        fontWeight: FontWeight.w600,
        color: CatSlotStyles.balanceColor,
      ),
    );
  }
}
