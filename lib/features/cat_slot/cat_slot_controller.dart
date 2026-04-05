import 'dart:async';
import 'dart:math';
import 'data/slot_symbols.dart';
import 'services/payout_service.dart';

class CatSlotController {
  static const int _startCoins  = 10;
  static const int _spinCost    = 1;
  static const int _winPayout   = 3;

  final Random _random = Random();
  final PayoutService _payout = const PayoutService();

  List<String> slots = [
    kSlotSymbols[0].emoji,
    kSlotSymbols[1].emoji,
    kSlotSymbols[2].emoji,
  ];
  String result    = '';
  bool isSpinning  = false;
  int spinTick     = 0;
  int coins        = _startCoins;

  String randomCat() =>
      kSlotSymbols[_random.nextInt(kSlotSymbols.length)].emoji;

  List<String> randomSlots() => List.generate(3, (_) => randomCat());


  /// Führt einen vollständigen Spin-Ablauf aus.
  /// [onUpdate] wird nach jeder Zustandsänderung aufgerufen, damit die UI setState() auslösen kann.
  Future<void> spin(void Function() onUpdate) async {
    if (isSpinning) return;

    if (coins < _spinCost) {
      result = 'No coins left';
      onUpdate();
      return;
    }

    isSpinning = true;
    coins -= _spinCost;
    result = 'Spinning...';
    onUpdate();

    // Alle Rollen gemeinsam schnell drehen
    for (int i = 0; i < 8; i++) {
      slots = randomSlots();
      spinTick++;
      onUpdate();
      await Future.delayed(const Duration(milliseconds: 90));
    }

    // Nacheinander stoppen für echtes Slot-Gefühl
    final finalSlots = randomSlots();

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 4; j++) {
        slots[i] = randomCat();
        spinTick++;
        onUpdate();
        await Future.delayed(const Duration(milliseconds: 85));
      }

      slots[i] = finalSlots[i];
      spinTick++;
      onUpdate();
      await Future.delayed(const Duration(milliseconds: 140));
    }

    isSpinning = false;
    final spinResult = _payout.evaluate(slots);
    if (spinResult.isWin) coins += _winPayout;
    result = spinResult.message;
    onUpdate();
  }

  /// Setzt das Spiel auf den Ausgangszustand zurück.
  void resetGame() {
    coins      = _startCoins;
    result     = '';
    isSpinning = false;
    slots      = [
      kSlotSymbols[0].emoji,
      kSlotSymbols[1].emoji,
      kSlotSymbols[2].emoji,
    ];
  }
}
