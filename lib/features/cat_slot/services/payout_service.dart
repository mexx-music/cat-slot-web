import '../models/spin_result.dart';

/// Kapselt die Gewinnprüfung für Cat Slot.
///
/// Aktuelle Regel: alle 3 Symbole gleich → Gewinn.
/// Neue Regeln können hier später ergänzt werden,
/// ohne Controller oder UI anzufassen.
class PayoutService {
  const PayoutService();

  SpinResult evaluate(List<String> slots) {
    final isWin = slots.length == 3 &&
        slots[0] == slots[1] &&
        slots[1] == slots[2];

    return SpinResult(
      isWin: isWin,
      message: isWin ? 'You win!' : 'Try again',
    );
  }
}
