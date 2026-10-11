import 'dart:async';
import 'dart:math';

import 'data/bonus_games.dart';
import 'data/slot_symbols.dart';
import 'models/bonus_game.dart';
import 'services/bonus_trigger_policy.dart';
import 'services/cat_switch_system.dart';
import 'services/payout_service.dart';

class CatSlotController {
  static const int _startCoins = 10;
  static const int _spinCost = 1;

  final Random _random;
  final PayoutService _payout;
  final BonusTriggerPolicy _bonusTriggerPolicy;
  final CatSwitchSymbolPolicy _catSwitchPolicy;
  final BonusProgressStore _progressStore;
  final Duration spinLeadIn;
  final Duration reelStopGap;

  CatSlotController({
    Random? random,
    PayoutService payout = const PayoutService(),
    BonusTriggerPolicy? bonusTriggerPolicy,
    CatSwitchSymbolPolicy? catSwitchPolicy,
    BonusProgressStore? progressStore,
    this.spinLeadIn = const Duration(milliseconds: 760),
    this.reelStopGap = const Duration(milliseconds: 190),
  }) : _random = random ?? Random(),
       _payout = payout,
       _bonusTriggerPolicy = bonusTriggerPolicy ?? BonusTriggerPolicy(),
       _catSwitchPolicy = catSwitchPolicy ?? CatSwitchSymbolPolicy.fixed(0),
       _progressStore = progressStore ?? MemoryBonusProgressStore();

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
  final List<BonusGameDefinition> _pendingBonusGames = [];
  Future<void>? _initializing;
  bool _initialized = false;
  int catSwitchProgress = 0;

  int _bonusSessionSerial = 0;
  final Set<String> _creditedBonusTransactions = {};

  List<String> get slots => reels.map((r) => r[1]).toList();
  BonusGameDefinition? get pendingBonusGame =>
      _pendingBonusGames.isEmpty ? null : _pendingBonusGames.first;
  bool get isBonusSpin => _pendingBonusGames.isNotEmpty;
  int get catSwitchVisibleCount =>
      VisibleBonusCounter.count(reels, kCatSwitchBonusSymbolId);

  Future<void> initialize() => _initializing ??= _loadProgress();

  Future<void> _loadProgress() async {
    catSwitchProgress = await _progressStore.loadCatSwitchProgress();
    _initialized = true;
  }

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

  String randomVisualSymbolId() => randomCatId();

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
    if (!_initialized) await initialize();
    // Mehrere schnelle Taps können während des asynchronen Ladens denselben
    // Initialisierungs-Future abwarten. Danach darf trotzdem nur einer starten.
    if (isSpinning) return;

    if (coins < _spinCost) {
      result = 'No coins left';
      onUpdate();
      return;
    }

    isSpinning = true;
    latestWin = 0;
    final mouseHuntTriggered = _bonusTriggerPolicy.shouldTrigger();
    if (mouseHuntTriggered) _enqueueBonus(kMouseHuntDefinition);
    reelSpinning = [true, true, true];
    coins -= _spinCost;
    result = 'Spinning...';
    onUpdate();

    // Die sichtbaren Rollen animieren sich selbst. Der Controller wartet nur
    // auf die dramaturgische Spin-Dauer und liefert anschließend nacheinander
    // die drei unveränderten, zufällig bestimmten Ergebnisse. Dadurch wird
    // nicht mehr die komplette Seite mehrfach pro Sekunde neu aufgebaut.
    final finalCenters = !mouseHuntTriggered
        ? randomSlots()
        : List.filled(3, kMouseBonusSymbolId);
    final finalReels = List.generate(
      3,
      (index) => randomStrip(finalCenters[index]),
    );
    final requestedCatSwitchSymbols = _catSwitchPolicy.visibleCount();
    _injectCatSwitchSymbols(
      finalReels,
      requestedCatSwitchSymbols,
      protectCenterLine: mouseHuntTriggered,
    );
    await Future.delayed(spinLeadIn);

    for (int i = 0; i < 3; i++) {
      reels[i] = finalReels[i];
      reelSpinning[i] = false;
      onReelStop?.call(i); // ← Sound-Callback pro Rolle
      onUpdate();
      if (i < 2) await Future.delayed(reelStopGap);
    }

    isSpinning = false;
    final visibleSwitchCats = catSwitchVisibleCount;
    await _applyCatSwitchProgress(visibleSwitchCats);
    if (!mouseHuntTriggered && visibleSwitchCats < 3) {
      final spinResult = _payout.evaluate(slots);
      if (spinResult.isWin) {
        latestWin = spinResult.coinsWon;
        coins += latestWin;
        onWinSettled?.call(latestWin);
      }
      result = pendingBonusGame == null
          ? spinResult.message
          : '${pendingBonusGame!.label} bonus!';
    } else {
      result = '${pendingBonusGame!.label} bonus!';
    }
    onUpdate();
  }

  void _injectCatSwitchSymbols(
    List<List<String>> targetReels,
    int count, {
    required bool protectCenterLine,
  }) {
    final positions = <(int, int)>[
      for (var reel = 0; reel < 3; reel++)
        for (var row = 0; row < 3; row++)
          if (!protectCenterLine || row != 1) (reel, row),
    ]..shuffle(_random);
    for (final position in positions.take(min(count, positions.length))) {
      targetReels[position.$1][position.$2] = kCatSwitchBonusSymbolId;
    }
  }

  Future<void> _applyCatSwitchProgress(int visibleCount) async {
    if (visibleCount >= 3) {
      _enqueueBonus(kCatSwitchDefinition);
      return;
    }
    if (visibleCount <= 0) return;
    final total = catSwitchProgress + visibleCount;
    if (total >= 3) _enqueueBonus(kCatSwitchDefinition);
    catSwitchProgress = total % 3;
    await _progressStore.saveCatSwitchProgress(catSwitchProgress);
  }

  void _enqueueBonus(BonusGameDefinition game) {
    if (_pendingBonusGames.any((queued) => queued.id == game.id)) return;
    _pendingBonusGames.add(game);
  }

  BonusGameSession? beginPendingBonus() {
    if (_pendingBonusGames.isEmpty) return null;
    final game = _pendingBonusGames.removeAt(0);
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
    if (session.game.id != kMouseHuntGameId ||
        bonusResult.normalCaught < 0 ||
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

  bool creditCatSwitchOnce(
    BonusGameSession session,
    CatSwitchResult switchResult,
  ) {
    if (session.game.id != kCatSwitchGameId ||
        switchResult.correct < 0 ||
        switchResult.correct > CatSwitchEconomy.rounds ||
        switchResult.roundsPlayed < 0 ||
        switchResult.roundsPlayed > CatSwitchEconomy.rounds) {
      throw ArgumentError('Invalid Cat Switch result');
    }
    final earnedCoins = CatSwitchEconomy.rewardFor(switchResult.correct);
    if (switchResult.coinsWon != earnedCoins) {
      throw ArgumentError('Cat Switch reward does not match configuration');
    }
    if (!_creditedBonusTransactions.add(session.transactionId)) return false;
    coins += earnedCoins;
    latestWin = earnedCoins;
    result = 'Cat Switch: +$earnedCoins PurrCoins';
    return true;
  }

  void resetGame() {
    coins = _startCoins;
    latestWin = 0;
    _pendingBonusGames.clear();
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
