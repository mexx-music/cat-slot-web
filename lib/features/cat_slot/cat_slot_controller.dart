import 'dart:async';
import 'dart:math';

import 'data/bonus_games.dart';
import 'data/slot_symbols.dart';
import 'models/bonus_game.dart';
import 'services/bonus_trigger_policy.dart';
import 'services/golden_cat_system.dart';
import 'services/fishing_cat_system.dart';
import 'services/payout_service.dart';
import 'services/tree_climber_system.dart';

class CatSlotController {
  static const int _startCoins = 10;
  static const int _spinCost = 1;

  final Random _random;
  final PayoutService _payout;
  final BonusTriggerPolicy _bonusTriggerPolicy;
  final GoldenCatSymbolPolicy _goldenCatPolicy;
  final FishingCatSymbolPolicy _fishingCatPolicy;
  final TreeClimberSymbolPolicy _treeClimberPolicy;
  final BonusProgressStore _progressStore;
  final WalletStore _walletStore;
  final Duration spinLeadIn;
  final Duration reelStopGap;

  CatSlotController({
    Random? random,
    PayoutService payout = const PayoutService(),
    BonusTriggerPolicy? bonusTriggerPolicy,
    GoldenCatSymbolPolicy? goldenCatPolicy,
    FishingCatSymbolPolicy? fishingCatPolicy,
    TreeClimberSymbolPolicy? treeClimberPolicy,
    BonusProgressStore? progressStore,
    WalletStore? walletStore,
    this.spinLeadIn = const Duration(milliseconds: 760),
    this.reelStopGap = const Duration(milliseconds: 190),
  }) : _random = random ?? Random(),
       _payout = payout,
       _bonusTriggerPolicy = bonusTriggerPolicy ?? BonusTriggerPolicy(),
       _goldenCatPolicy = goldenCatPolicy ?? GoldenCatSymbolPolicy.fixed(0),
       _fishingCatPolicy = fishingCatPolicy ?? FishingCatSymbolPolicy.fixed(0),
       _treeClimberPolicy =
           treeClimberPolicy ?? TreeClimberSymbolPolicy.fixed(0),
       _progressStore = progressStore ?? MemoryBonusProgressStore(),
       _walletStore = walletStore ?? MemoryWalletStore();

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
  int goldenCatProgress = 0;
  int fishingCatProgress = 0;
  int treeClimberProgress = 0;

  int _bonusSessionSerial = 0;
  final Set<String> _creditedBonusTransactions = {};

  List<String> get slots => reels.map((r) => r[1]).toList();
  BonusGameDefinition? get pendingBonusGame =>
      _pendingBonusGames.isEmpty ? null : _pendingBonusGames.first;
  bool get isBonusSpin => _pendingBonusGames.isNotEmpty;
  int get goldenCatVisibleCount =>
      VisibleBonusCounter.count(reels, kGoldenCatBonusSymbolId);
  int get fishingCatVisibleCount =>
      VisibleBonusCounter.count(reels, kFishingCatBonusSymbolId);
  int get treeClimberVisibleCount =>
      VisibleBonusCounter.count(reels, kTreeClimberBonusSymbolId);

  Future<void> initialize() => _initializing ??= _loadPersistentState();

  Future<void> _loadPersistentState() async {
    final values = await Future.wait([
      _progressStore.loadGoldenCatProgress(),
      _progressStore.loadFishingCatProgress(),
      _progressStore.loadTreeClimberProgress(),
      _walletStore.load(),
    ]);
    goldenCatProgress = values[0] as int;
    fishingCatProgress = values[1] as int;
    treeClimberProgress = values[2] as int;
    final wallet = values[3] as WalletSnapshot?;
    if (wallet != null) {
      coins = max(0, wallet.coins);
      _creditedBonusTransactions.addAll(wallet.creditedTransactions);
    }
    _initialized = true;
  }

  Future<void> _persistWallet() => _walletStore.save(
    WalletSnapshot(
      coins: max(0, coins),
      creditedTransactions: Set.of(_creditedBonusTransactions),
    ),
  );

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
    await _persistWallet();
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
    final requestedGoldenCatSymbols = _goldenCatPolicy.visibleCount();
    _injectBonusSymbols(
      finalReels,
      requestedGoldenCatSymbols,
      symbolId: kGoldenCatBonusSymbolId,
      protectCenterLine: mouseHuntTriggered,
    );
    final requestedFishingCatSymbols = _fishingCatPolicy.visibleCount();
    _injectBonusSymbols(
      finalReels,
      requestedFishingCatSymbols,
      symbolId: kFishingCatBonusSymbolId,
      protectCenterLine: mouseHuntTriggered,
    );
    final requestedTreeClimberSymbols = _treeClimberPolicy.visibleCount();
    _injectBonusSymbols(
      finalReels,
      requestedTreeClimberSymbols,
      symbolId: kTreeClimberBonusSymbolId,
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
    final visibleGoldenCats = goldenCatVisibleCount;
    final visibleFishingCats = fishingCatVisibleCount;
    final visibleTreeClimbers = treeClimberVisibleCount;
    await _applyGoldenCatProgress(visibleGoldenCats);
    await _applyFishingCatProgress(visibleFishingCats);
    await _applyTreeClimberProgress(visibleTreeClimbers);
    if (!mouseHuntTriggered &&
        visibleGoldenCats < 3 &&
        visibleFishingCats < 3 &&
        visibleTreeClimbers < 3) {
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
    await _persistWallet();
    onUpdate();
  }

  void _injectBonusSymbols(
    List<List<String>> targetReels,
    int count, {
    required String symbolId,
    required bool protectCenterLine,
  }) {
    final positions = <(int, int)>[
      for (var reel = 0; reel < 3; reel++)
        for (var row = 0; row < 3; row++)
          if ((!protectCenterLine || row != 1) &&
              bonusGameForSymbolId(targetReels[reel][row]) == null)
            (reel, row),
    ]..shuffle(_random);
    for (final position in positions.take(min(count, positions.length))) {
      targetReels[position.$1][position.$2] = symbolId;
    }
  }

  Future<void> _applyFishingCatProgress(int visibleCount) async {
    if (visibleCount >= 3) {
      _enqueueBonus(kFishingCatDefinition);
      return;
    }
    if (visibleCount <= 0) return;
    final total = fishingCatProgress + visibleCount;
    if (total >= 3) _enqueueBonus(kFishingCatDefinition);
    fishingCatProgress = total % 3;
    await _progressStore.saveFishingCatProgress(fishingCatProgress);
  }

  Future<void> _applyGoldenCatProgress(int visibleCount) async {
    if (visibleCount >= 3) {
      _enqueueBonus(kGoldenCatDefinition);
      return;
    }
    if (visibleCount <= 0) return;
    final total = goldenCatProgress + visibleCount;
    if (total >= 3) _enqueueBonus(kGoldenCatDefinition);
    goldenCatProgress = total % 3;
    await _progressStore.saveGoldenCatProgress(goldenCatProgress);
  }

  Future<void> _applyTreeClimberProgress(int visibleCount) async {
    if (visibleCount >= 3) {
      _enqueueBonus(kTreeClimberDefinition);
      return;
    }
    if (visibleCount <= 0) return;
    final total = treeClimberProgress + visibleCount;
    if (total >= 3) _enqueueBonus(kTreeClimberDefinition);
    treeClimberProgress = total % 3;
    await _progressStore.saveTreeClimberProgress(treeClimberProgress);
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
  Future<bool> creditBonusOnce(
    BonusGameSession session,
    BonusGameResult bonusResult,
  ) async {
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
    await _persistWallet();
    return true;
  }

  Future<bool> creditGoldenCatOnce(
    BonusGameSession session,
    GoldenCatResult goldenResult,
  ) async {
    if (session.game.id != kGoldenCatGameId ||
        goldenResult.stageReached < 1 ||
        goldenResult.stageReached > GoldenCatEconomy.stages ||
        (goldenResult.missed && goldenResult.cashedOut)) {
      throw ArgumentError('Invalid Golden Cat result');
    }
    final expectedCoins = goldenResult.missed
        ? 0
        : GoldenCatEconomy.payoutForStage(goldenResult.stageReached);
    if (goldenResult.coinsWon != expectedCoins ||
        (!goldenResult.missed && !goldenResult.cashedOut)) {
      throw ArgumentError('Golden Cat reward does not match configuration');
    }
    if (!_creditedBonusTransactions.add(session.transactionId)) return false;
    coins += expectedCoins;
    latestWin = expectedCoins;
    result = goldenResult.missed
        ? 'Golden Cat: Bonus nicht gesichert'
        : 'Golden Cat: +$expectedCoins PurrCoins';
    await _persistWallet();
    return true;
  }

  Future<bool> creditFishingCatOnce(
    BonusGameSession session,
    FishingCatResult fishingResult,
  ) async {
    final validNames = FishingCatchKind.values.map((kind) => kind.name).toSet();
    if (fishingResult.catches.keys.any((name) => !validNames.contains(name)) ||
        fishingResult.catches.values.any((count) => count < 0)) {
      throw ArgumentError('Fishing Cat contains invalid catch data');
    }
    final caughtCount = fishingResult.catches.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    final expectedPoints = fishingResult.catches.entries.fold<int>(0, (
      sum,
      entry,
    ) {
      final kind = FishingCatchKind.values.byName(entry.key);
      return sum + FishingCatEconomy.pointsFor(kind) * entry.value;
    });
    if (session.game.id != kFishingCatGameId ||
        fishingResult.attemptsCompleted < 0 ||
        fishingResult.attemptsCompleted > FishingCatEconomy.attempts ||
        (!fishingResult.skipped &&
            fishingResult.attemptsCompleted != FishingCatEconomy.attempts) ||
        caughtCount > fishingResult.attemptsCompleted ||
        fishingResult.pointsWon != expectedPoints ||
        fishingResult.coinsWon !=
            FishingCatEconomy.coinsForPoints(expectedPoints)) {
      throw ArgumentError('Fishing Cat reward does not match configuration');
    }
    if (!_creditedBonusTransactions.add(session.transactionId)) return false;
    coins += fishingResult.coinsWon;
    latestWin = fishingResult.coinsWon;
    result = 'Fishing Cat: +${fishingResult.coinsWon} PurrCoins';
    await _persistWallet();
    return true;
  }

  Future<bool> creditTreeClimberOnce(
    BonusGameSession session,
    TreeClimberResult treeResult,
  ) async {
    final expectedPoints = TreeClimberEconomy.pointsForSection(
      treeResult.sectionsReached,
    );
    final expectedCoins = TreeClimberEconomy.coinsFor(
      points: expectedPoints,
      reachedSummit: treeResult.reachedSummit,
    );
    if (session.game.id != kTreeClimberGameId ||
        treeResult.sectionsReached < 0 ||
        treeResult.sectionsReached > TreeClimberEconomy.sectionCount ||
        treeResult.pointsWon != expectedPoints ||
        treeResult.coinsWon != expectedCoins ||
        treeResult.reachedSummit !=
            (treeResult.sectionsReached == TreeClimberEconomy.sectionCount) ||
        (!treeResult.reachedSummit && !treeResult.cashedOut)) {
      throw ArgumentError('Tree Climber reward does not match configuration');
    }
    if (!_creditedBonusTransactions.add(session.transactionId)) return false;
    coins += expectedCoins;
    latestWin = expectedCoins;
    result = treeResult.reachedSummit
        ? 'Tree Climber: Baumspitze! +$expectedCoins PurrCoins'
        : 'Tree Climber: +$expectedCoins PurrCoins';
    await _persistWallet();
    return true;
  }

  Future<void> resetGame() async {
    coins = _startCoins;
    latestWin = 0;
    _pendingBonusGames.clear();
    result = '';
    isSpinning = false;
    reelSpinning = [false, false, false];
    reels = [_initialStrip(0), _initialStrip(1), _initialStrip(2)];
    _creditedBonusTransactions.clear();
    await _persistWallet();
  }

  /// Baut die sichtbaren Rollen neu auf Basis des aktuell aktiven Sets auf.
  /// Wird nach einem Set-Wechsel aufgerufen.
  void refreshReels() {
    reels = [_initialStrip(0), _initialStrip(1), _initialStrip(2)];
  }
}
