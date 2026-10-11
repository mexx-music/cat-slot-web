import 'dart:async';
import 'dart:math';

import 'data/bonus_games.dart';
import 'data/slot_symbols.dart';
import 'models/bonus_game.dart';
import 'services/bonus_trigger_policy.dart';
import 'services/payout_service.dart';

class CatSlotController {
  static const int _startCoins = 10;
  static const int _spinCost = 1;

  final Random _random;
  final PayoutService _payout;
  final BonusTriggerPolicy _bonusTriggerPolicy;
  final Duration spinLeadIn;
  final Duration reelStopGap;

  CatSlotController({
    Random? random,
    PayoutService payout = const PayoutService(),
    BonusTriggerPolicy? bonusTriggerPolicy,
    this.spinLeadIn = const Duration(milliseconds: 760),
    this.reelStopGap = const Duration(milliseconds: 190),
  }) : _random = random ?? Random(),
       _payout = payout,
       _bonusTriggerPolicy = bonusTriggerPolicy ?? BonusTriggerPolicy();

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
  BonusGameDefinition? pendingBonusGame;

  int _bonusSessionSerial = 0;
  final Set<String> _creditedBonusTransactions = {};

  List<String> get slots => reels.map((r) => r[1]).toList();
  bool get isBonusSpin => pendingBonusGame != null;

  static List<String> _initialStrip(int offset) {
    final symbols = kRegularSlotSymbols;
    final n = symbols.length;
    return [
      symbols[(offset + n - 1) % n].id,
      symbols[offset % n].id,
      symbols[(offset + 1) % n].id,
    ];
  }

  String randomCatId() =>
      kRegularSlotSymbols[_random.nextInt(kRegularSlotSymbols.length)].id;

  String randomVisualSymbolId() =>
      kSlotSymbols[_random.nextInt(kSlotSymbols.length)].id;

  List<String> randomStrip(String centerSymbolId) => [
    randomVisualSymbolId(),
    centerSymbolId,
    randomVisualSymbolId(),
  ];

  List<String> randomSlots() => List.generate(3, (_) => randomCatId());

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
    pendingBonusGame = _bonusTriggerPolicy.shouldTrigger()
        ? kMouseHuntDefinition
        : null;
    reelSpinning = [true, true, true];
    coins -= _spinCost;
    result = 'Spinning...';
    onUpdate();

    // Die sichtbaren Rollen animieren sich selbst. Der Controller wartet nur
    // auf die dramaturgische Spin-Dauer und liefert anschließend nacheinander
    // die drei unveränderten, zufällig bestimmten Ergebnisse. Dadurch wird
    // nicht mehr die komplette Seite mehrfach pro Sekunde neu aufgebaut.
    final finalCenters = pendingBonusGame == null
        ? randomSlots()
        : List.filled(3, pendingBonusGame!.symbolId);
    await Future.delayed(spinLeadIn);

    for (int i = 0; i < 3; i++) {
      reels[i] = randomStrip(finalCenters[i]);
      reelSpinning[i] = false;
      onReelStop?.call(i); // ← Sound-Callback pro Rolle
      onUpdate();
      if (i < 2) await Future.delayed(reelStopGap);
    }

    isSpinning = false;
    if (pendingBonusGame != null) {
      result = '${pendingBonusGame!.label} bonus!';
      onUpdate();
      return;
    }
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

  BonusGameSession? beginPendingBonus() {
    final game = pendingBonusGame;
    if (game == null) return null;
    pendingBonusGame = null;
    _bonusSessionSerial++;
    return BonusGameSession(
      transactionId:
          '${game.id}-${DateTime.now().microsecondsSinceEpoch}-$_bonusSessionSerial',
      game: game,
    );
  }

  /// Credits a completed bonus session at most once, even if lifecycle or UI
  /// callbacks deliver the same result again.
  bool creditBonusOnce(BonusGameSession session, BonusGameResult bonusResult) {
    if (bonusResult.normalCaught < 0 ||
        bonusResult.normalCaught >= BonusEconomy.mouseCount ||
        bonusResult.goldenCaught < 0 ||
        bonusResult.goldenCaught > 1) {
      throw ArgumentError('Invalid Mouse Hunt catch counts');
    }
    final earnedCoins = BonusEconomy.rewardFor(
      normalCaught: bonusResult.normalCaught,
      goldenCaught: bonusResult.goldenCaught,
    );
    if (bonusResult.coinsWon != earnedCoins) {
      throw ArgumentError.value(
        bonusResult.coinsWon,
        'coinsWon',
        'Does not match the centrally configured Mouse Hunt reward',
      );
    }
    if (!_creditedBonusTransactions.add(session.transactionId)) return false;
    coins += earnedCoins;
    latestWin = earnedCoins;
    result = 'Mouse Hunt: +$earnedCoins PurrCoins';
    return true;
  }

  void resetGame() {
    coins = _startCoins;
    latestWin = 0;
    pendingBonusGame = null;
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
