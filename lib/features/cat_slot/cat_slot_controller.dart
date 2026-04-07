import 'dart:async';
import 'dart:math';
import 'data/slot_symbols.dart';
import 'services/payout_service.dart';

class CatSlotController {
  static const int _startCoins = 10;
  static const int _spinCost   = 1;
  static const int _winPayout  = 3;

  final Random _random = Random();
  final PayoutService _payout = const PayoutService();

  /// 3 Rollen, jede mit 3 sichtbaren Symbolen [oben, mitte, unten].
  /// Das mittlere Symbol (Index 1) jeder Rolle ist das Ergebnis-Symbol.
  List<List<String>> reels = [
    _initialStrip(0),
    _initialStrip(1),
    _initialStrip(2),
  ];

  /// Welche Rollen gerade animiert (spinning) sind.
  List<bool> reelSpinning = [false, false, false];

  String result   = '';
  bool isSpinning = false;
  int coins       = _startCoins;

  /// Bequemer Zugriff: das mittlere Symbol jeder Rolle als flache Liste.
  List<String> get slots => reels.map((r) => r[1]).toList();

  static List<String> _initialStrip(int offset) {
    final n = kSlotSymbols.length;
    return [
      kSlotSymbols[(offset + n - 1) % n].emoji,
      kSlotSymbols[offset % n].emoji,
      kSlotSymbols[(offset + 1) % n].emoji,
    ];
  }

  String randomCat() =>
      kSlotSymbols[_random.nextInt(kSlotSymbols.length)].emoji;

  /// Erzeugt einen zufälligen 3er-Strip mit gegebenem Mitte-Symbol.
  List<String> randomStrip(String centerEmoji) {
    return [randomCat(), centerEmoji, randomCat()];
  }

  List<String> randomSlots() =>
      List.generate(3, (_) => randomCat());

  /// Führt einen vollständigen Spin-Ablauf aus.
  Future<void> spin(void Function() onUpdate) async {
    if (isSpinning) return;

    if (coins < _spinCost) {
      result = 'No coins left';
      onUpdate();
      return;
    }

    isSpinning = true;
    reelSpinning = [true, true, true];
    coins -= _spinCost;
    result = 'Spinning...';
    onUpdate();

    // Alle Rollen gemeinsam schnell drehen – Symbole randomisieren
    for (int i = 0; i < 8; i++) {
      reels = reels.map((r) => randomStrip(randomCat())).toList();
      onUpdate();
      await Future.delayed(const Duration(milliseconds: 90));
    }

    // Finales Ergebnis festlegen
    final finalCenters = randomSlots();

    // Rollen nacheinander stoppen
    for (int i = 0; i < 3; i++) {
      // Noch ein paar Schritte weiterdrehen bevor stopp
      for (int j = 0; j < 4; j++) {
        reels[i] = randomStrip(randomCat());
        onUpdate();
        await Future.delayed(const Duration(milliseconds: 85));
      }

      // Finale Position setzen, Rolle stoppen
      reels[i] = randomStrip(finalCenters[i]);
      reelSpinning[i] = false;
      onUpdate();
      await Future.delayed(const Duration(milliseconds: 160));
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
    reelSpinning = [false, false, false];
    reels = [
      _initialStrip(0),
      _initialStrip(1),
      _initialStrip(2),
    ];
  }
}
