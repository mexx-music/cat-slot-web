import 'dart:async';
import 'dart:math';
import 'data/slot_symbols.dart';
import 'services/payout_service.dart';

class CatSlotController {
  static const int _startCoins = 10;
  static const int _spinCost = 1;

  final Random _random;
  final PayoutService _payout;
  final Duration spinLeadIn;
  final Duration reelStopGap;

  CatSlotController({
    Random? random,
    PayoutService payout = const PayoutService(),
    this.spinLeadIn = const Duration(milliseconds: 760),
    this.reelStopGap = const Duration(milliseconds: 190),
  }) : _random = random ?? Random(),
       _payout = payout;

  List<List<String>> reels = [
    _initialStrip(0),
    _initialStrip(1),
    _initialStrip(2),
  ];

  List<bool> reelSpinning = [false, false, false];

  String result = '';
  bool isSpinning = false;
  int coins = _startCoins;

  /// Gewinn des zuletzt abgeschlossenen Spins. Er ist bereits in [coins]
  /// enthalten und dient ausschließlich der visuellen Präsentation.
  int latestWin = 0;

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

  List<String> randomStrip(String centerEmoji) => [
    randomCat(),
    centerEmoji,
    randomCat(),
  ];

  List<String> randomSlots() => List.generate(3, (_) => randomCat());

  Future<void> spin(
    void Function() onUpdate, {
    void Function(int reelIndex)? onReelStop,
    void Function(int coinsWon)? onWinSettled,
  }) async {
    if (isSpinning) return;

    if (coins < _spinCost) {
      result = 'No coins left';
      onUpdate();
      return;
    }

    isSpinning = true;
    latestWin = 0;
    reelSpinning = [true, true, true];
    coins -= _spinCost;
    result = 'Spinning...';
    onUpdate();

    // Die sichtbaren Rollen animieren sich selbst. Der Controller wartet nur
    // auf die dramaturgische Spin-Dauer und liefert anschließend nacheinander
    // die drei unveränderten, zufällig bestimmten Ergebnisse. Dadurch wird
    // nicht mehr die komplette Seite mehrfach pro Sekunde neu aufgebaut.
    final finalCenters = randomSlots();
    await Future.delayed(spinLeadIn);

    for (int i = 0; i < 3; i++) {
      reels[i] = randomStrip(finalCenters[i]);
      reelSpinning[i] = false;
      onReelStop?.call(i); // ← Sound-Callback pro Rolle
      onUpdate();
      if (i < 2) await Future.delayed(reelStopGap);
    }

    isSpinning = false;
    final spinResult = _payout.evaluate(slots);

    // Der Gewinn wird genau einmal und sofort mit der Ergebnisfeststellung
    // verbucht. Alle nachfolgenden Coin-/Counter-Effekte sind rein visuell.
    if (spinResult.isWin) {
      latestWin = spinResult.coinsWon;
      coins += latestWin;
      onWinSettled?.call(latestWin);
    }

    result = spinResult.message;
    onUpdate();
  }

  void resetGame() {
    coins = _startCoins;
    latestWin = 0;
    result = '';
    isSpinning = false;
    reelSpinning = [false, false, false];
    reels = [_initialStrip(0), _initialStrip(1), _initialStrip(2)];
  }

  /// Baut die sichtbaren Rollen neu auf Basis des aktuell aktiven Sets auf.
  /// Wird nach einem Set-Wechsel aufgerufen.
  void refreshReels() {
    reels = [_initialStrip(0), _initialStrip(1), _initialStrip(2)];
  }
}
