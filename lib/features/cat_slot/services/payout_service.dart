import '../data/slot_symbols.dart';
import '../models/spin_result.dart';

/// Kapselt die Gewinnprüfung für Cat Slot.
class PayoutService {
  const PayoutService();

  SpinResult evaluate(List<String> slots) {
    final isWin = slots.length == 3 &&
        slots[0] == slots[1] &&
        slots[1] == slots[2];

    if (!isWin) {
      return const SpinResult(isWin: false, message: 'Try again', coinsWon: 0);
    }

    // Payout anhand des Gewinn-Symbols aus der zentralen Symbol-Liste lesen
    final winEmoji = slots[0];
    final symbol = kSlotSymbols.firstWhere(
      (s) => s.emoji == winEmoji,
      orElse: () => kSlotSymbols.first,
    );

    return SpinResult(
      isWin: true,
      message: 'You win!',
      coinsWon: symbol.payout,
    );
  }
}
