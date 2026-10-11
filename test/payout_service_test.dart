import 'package:catslot/features/cat_slot/data/slot_symbol_sets.dart';
import 'package:catslot/features/cat_slot/services/payout_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payout = PayoutService();

  group('PayoutService', () {
    test('keeps every configured three-of-a-kind payout unchanged', () {
      for (final symbol in kStandardSet.symbols) {
        final result = payout.evaluate([
          symbol.emoji,
          symbol.emoji,
          symbol.emoji,
        ]);

        expect(result.isWin, isTrue, reason: symbol.id);
        expect(result.coinsWon, symbol.payout, reason: symbol.id);
        expect(result.message, 'You win!');
      }
    });

    test('does not reward mixed symbols', () {
      final symbols = kStandardSet.symbols;
      final result = payout.evaluate([
        symbols[0].emoji,
        symbols[0].emoji,
        symbols[1].emoji,
      ]);

      expect(result.isWin, isFalse);
      expect(result.coinsWon, 0);
      expect(result.message, 'Try again');
    });

    test('requires exactly three symbols', () {
      expect(payout.evaluate(const []).isWin, isFalse);
      expect(payout.evaluate(const ['🐱', '🐱']).isWin, isFalse);
      expect(payout.evaluate(const ['🐱', '🐱', '🐱', '🐱']).isWin, isFalse);
    });
  });
}
