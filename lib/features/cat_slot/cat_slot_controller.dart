import 'dart:async';
import 'dart:math';
import 'data/slot_symbols.dart';
import 'services/payout_service.dart';

class CatSlotController {
  static const int _startCoins = 10;
  static const int _spinCost   = 1;

  final Random _random = Random();
  final PayoutService _payout = const PayoutService();

  List<List<String>> reels = [
    _initialStrip(0),
    _initialStrip(1),
    _initialStrip(2),
  ];

  List<bool> reelSpinning = [false, false, false];

  String result    = '';
  bool isSpinning  = false;
  int coins        = _startCoins;

  /// Ausstehender Gewinn – wird erst beim Collect gutgeschrieben.
  int pendingWin   = 0;

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

  List<String> randomStrip(String centerEmoji) =>
      [randomCat(), centerEmoji, randomCat()];

  List<String> randomSlots() =>
      List.generate(3, (_) => randomCat());

  /// Schreibt den ausstehenden Gewinn gut (Collect-Schritt).
  void collectWin() {
    coins      += pendingWin;
    pendingWin  = 0;
  }

  Future<void> spin(
    void Function() onUpdate, {
    void Function(int reelIndex)? onReelStop,
  }) async {
    if (isSpinning) return;

    if (coins < _spinCost) {
      result = 'No coins left';
      onUpdate();
      return;
    }

    isSpinning   = true;
    pendingWin   = 0;
    reelSpinning = [true, true, true];
    coins       -= _spinCost;
    result       = 'Spinning...';
    onUpdate();

    for (int i = 0; i < 8; i++) {
      reels = reels.map((r) => randomStrip(randomCat())).toList();
      onUpdate();
      await Future.delayed(const Duration(milliseconds: 90));
    }

    final finalCenters = randomSlots();

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 4; j++) {
        reels[i] = randomStrip(randomCat());
        onUpdate();
        await Future.delayed(const Duration(milliseconds: 85));
      }
      reels[i]        = randomStrip(finalCenters[i]);
      reelSpinning[i] = false;
      onReelStop?.call(i);  // ← Sound-Callback pro Rolle
      onUpdate();
      await Future.delayed(const Duration(milliseconds: 160));
    }

    isSpinning = false;
    final spinResult = _payout.evaluate(slots);

    // Gewinn nur vormerken – Gutschrift erfolgt beim Collect
    if (spinResult.isWin) pendingWin = spinResult.coinsWon;

    result = spinResult.message;
    onUpdate();
  }

  void resetGame() {
    coins        = _startCoins;
    pendingWin   = 0;
    result       = '';
    isSpinning   = false;
    reelSpinning = [false, false, false];
    reels = [
      _initialStrip(0),
      _initialStrip(1),
      _initialStrip(2),
    ];
  }

  /// Baut die sichtbaren Rollen neu auf Basis des aktuell aktiven Sets auf.
  /// Wird nach einem Set-Wechsel aufgerufen.
  void refreshReels() {
    reels = [
      _initialStrip(0),
      _initialStrip(1),
      _initialStrip(2),
    ];
  }
}
