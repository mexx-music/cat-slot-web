import '../data/slot_symbols.dart';
import '../models/spin_result.dart';

/// Kapselt die Gewinnprüfung für Cat Slot.
class PayoutService {
  const PayoutService();

  SpinResult evaluate(List<String> symbolIds) {
    final isWin =
        symbolIds.length == 3 &&
        symbolIds[0] == symbolIds[1] &&
        symbolIds[1] == symbolIds[2];

    if (!isWin) {
      return const SpinResult(isWin: false, message: 'Try again', coinsWon: 0);
    }

    // Stable IDs keep payout and bonus recognition independent from artwork.
    final symbol = kSlotSymbols.firstWhere(
      (candidate) => candidate.id == symbolIds[0],
      orElse: () => kSlotSymbols.first,
    );

    if (symbol.isBonus) {
      return const SpinResult(isWin: false, message: 'Bonus game', coinsWon: 0);
    }

    return SpinResult(
      isWin: true,
      message: 'You win!',
      coinsWon: symbol.payout,
    );
  }
}
