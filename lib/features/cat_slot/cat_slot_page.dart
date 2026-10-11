import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bonus/golden_cat_challenge.dart';
import 'bonus/fishing_cat_game.dart';
import 'bonus/mouse_hunt_game.dart';
import 'cat_slot_controller.dart';
import 'cat_slot_styles.dart';
import 'data/slot_symbol_sets.dart';
import 'data/bonus_games.dart';
import 'models/bonus_game.dart';
import 'models/symbol_set.dart';
import 'services/audio_service.dart';
import 'services/golden_cat_system.dart';
import 'services/fishing_cat_system.dart';
import 'widgets/balance_label.dart';
import 'widgets/cat_mood_chip.dart';
import 'widgets/coin_fly_overlay.dart';
import 'widgets/cozy_cat_backdrop.dart';
import 'widgets/reset_button.dart';
import 'widgets/spin_button.dart';
import 'widgets/result_label.dart';
import 'widgets/smooth_reel_box.dart';
import 'widgets/symbol_set_selector.dart';
import 'widgets/win_effect_overlay.dart';

class CatSlotPage extends StatefulWidget {
  final CatSlotController? controller;

  const CatSlotPage({super.key, this.controller});

  @override
  State<CatSlotPage> createState() => _CatSlotPageState();
}

class _CatSlotPageState extends State<CatSlotPage> with WidgetsBindingObserver {
  late final CatSlotController _controller;
  final AudioService _audio = AudioService();

  bool _showBigWinPanel = false;
  bool _showSmallWinChip = false;
  bool _showWinHighlight = false;
  bool _showCoinFly = false;
  bool _visualBalanceActive = false;
  bool _spinRequestActive = false;
  bool _bonusRevealed = false;
  bool _bonusTransitioning = false;
  bool _showBonusGame = false;
  bool _bonusLaunchPending = false;
  BonusGameSession? _activeBonusSession;

  // Visual counter only. The controller balance is already settled.
  int _displayCoins = 0;
  int _presentedWin = 0;
  int _quipIndex = 0;
  String _catMessage = 'Die Katzen machen sich bereit.';
  bool _catExcited = false;

  // Aktives Symbol-Set
  SymbolSet _activeSet = kActiveSymbolSet;

  // GlobalKeys zum Ermitteln der Screen-Positionen
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _reelKey = GlobalKey();

  // Ermittelte Positionen für die Coin-Animation
  Offset _coinStart = Offset.zero;
  Offset _coinTarget = Offset.zero;

  // Stable for one transfer so counter rebuilds do not restart the flight.
  Key _coinFlyKey = const ValueKey('coin-fly-initial');
  Timer? _smallWinTimer;
  Timer? _bonusTransitionTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _isBigWin => _presentedWin >= CatSlotStyles.winTierBig;

  List<String?> get _goldenCatAssets => _activeSet.symbols
      .where((symbol) => !symbol.isBonus)
      .map((symbol) => symbol.assetPath)
      .take(2)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        CatSlotController(
          goldenCatPolicy: GoldenCatSymbolPolicy(),
          fishingCatPolicy: FishingCatSymbolPolicy(),
          progressStore: SharedPreferencesBonusProgressStore(),
          walletStore: SharedPreferencesWalletStore(),
        );
    _displayCoins = _controller.coins;
    WidgetsBinding.instance.addObserver(this);
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smallWinTimer?.cancel();
    _bonusTransitionTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed) _audio.stopPurrLoop();
    if (state != AppLifecycleState.resumed &&
        (_showBigWinPanel || _showSmallWinChip || _showCoinFly)) {
      _finishWinPresentation();
    }
    if (state != AppLifecycleState.resumed &&
        _activeBonusSession != null &&
        !_showBonusGame) {
      _bonusTransitionTimer?.cancel();
      _bonusLaunchPending = true;
    } else if (state == AppLifecycleState.resumed && _bonusLaunchPending) {
      _showPendingBonus();
    }
  }

  /// Wechselt das aktive Symbol-Set und baut die Rollen neu auf.
  Future<void> _onSetChanged(SymbolSet set) async {
    if (_controller.isSpinning || _activeBonusSession != null) return;
    await Future.wait([
      for (final symbol in set.symbols)
        if (symbol.assetPath != null)
          precacheImage(AssetImage(symbol.assetPath!), context),
    ]);
    if (!mounted) return;
    setState(() {
      kActiveSymbolSet = set;
      _activeSet = set;
      _controller.refreshReels();
      _finishWinPresentation(notify: false);
      _catMessage = '${set.label}: neue Katzen, gleiches Glück.';
      _catExcited = false;
    });
  }

  Future<void> _onSpin() async {
    if (_spinRequestActive ||
        _controller.isSpinning ||
        _activeBonusSession != null) {
      return;
    }
    setState(() => _spinRequestActive = true);
    // A new spin is an intentional skip for any remaining visual-only reward
    // transfer. The already settled balance cannot be credited twice.
    _finishWinPresentation();
    HapticFeedback.lightImpact();
    try {
      await _audio.ensureUnlockedAndPreload(); // iOS: preload on first tap
      if (!mounted) return;
      _audio.playSpinSound();
      setState(() {
        _showWinHighlight = false;
        _bonusRevealed = false;
        _catExcited = false;
        _catMessage = 'Pfoten weg vom Hebel … jetzt wird geschnurrt!';
      });
      await _controller.spin(
        _refresh,
        onReelStop: (i) {
          _audio.playReelStopSound(i);
          if (i == 2 &&
              (_controller.isBonusSpin ||
                  _controller.goldenCatVisibleCount >= 3 ||
                  _controller.fishingCatVisibleCount >= 3)) {
            HapticFeedback.heavyImpact();
            if (mounted) setState(() => _bonusRevealed = true);
          } else {
            HapticFeedback.selectionClick();
          }
        },
        onWinSettled: (win) {
          _presentedWin = win;
          _displayCoins = _controller.coins - win;
          _visualBalanceActive = true;
        },
      );
      _audio.stopPurrLoop();
      if (!mounted) return;
      if (_controller.pendingBonusGame != null) {
        _beginBonusTransition();
        return;
      }
      if (_lifecycleState != AppLifecycleState.resumed) {
        _finishWinPresentation();
        return;
      }
      if (_controller.latestWin > 0) {
        final bigWin = _isBigWin;
        if (_presentedWin >= CatSlotStyles.winTierMega) {
          HapticFeedback.heavyImpact();
        } else if (bigWin) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
        _audio.playWinSound(big: bigWin);
        setState(() {
          _showWinHighlight = true;
          _showBigWinPanel = bigWin;
          _showSmallWinChip = !bigWin;
          _catExcited = true;
          _catMessage = bigWin
              ? 'Miau-nificent! Die Pfotenjury ist begeistert.'
              : 'Schnurr! Ein kleiner Glücksmoment.';
        });
        if (!bigWin) _scheduleSmallWinTransfer();
      } else {
        setState(() {
          _catExcited = false;
          _catMessage = _nextConsolationMessage();
        });
      }
    } finally {
      _spinRequestActive = false;
      if (mounted) setState(() {});
    }
  }

  void _beginBonusTransition() {
    final session = _controller.beginPendingBonus();
    if (session == null) return;
    _activeBonusSession = session;
    _audio.playWinSound(big: true);
    setState(() {
      _bonusTransitioning = true;
      _catExcited = true;
      _catMessage = switch (session.game.id) {
        kMouseHuntGameId => 'Drei Mäuse! Die geheime Katzenklappe öffnet sich.',
        kGoldenCatGameId =>
          'Drei Goldkatzen! Die Golden Cat Challenge beginnt.',
        _ => 'Drei Angelkatzen! Am stillen Teich bewegt sich etwas.',
      };
    });
    if (_lifecycleState != AppLifecycleState.resumed) {
      _bonusLaunchPending = true;
      return;
    }
    if (_reduceMotion) {
      _showPendingBonus();
      return;
    }
    _bonusTransitionTimer?.cancel();
    _bonusTransitionTimer = Timer(
      const Duration(milliseconds: 520),
      _showPendingBonus,
    );
  }

  void _showPendingBonus() {
    if (!mounted || _activeBonusSession == null) return;
    if (_lifecycleState != AppLifecycleState.resumed) {
      _bonusLaunchPending = true;
      return;
    }
    setState(() {
      _bonusLaunchPending = false;
      _bonusTransitioning = false;
      _showBonusGame = true;
    });
  }

  Future<void> _onBonusCompleted(BonusGameResult result) async {
    final session = _activeBonusSession;
    if (session == null) return;
    final credited = await _controller.creditBonusOnce(session, result);
    if (!credited || !mounted) return;
    _audio.playCollectSound();
    HapticFeedback.mediumImpact();
    setState(() {
      _displayCoins = _controller.coins;
      _catMessage =
          'Mouse Hunt bringt ${result.coinsWon} PurrCoins ins Körbchen.';
    });
  }

  Future<void> _onGoldenCatCompleted(GoldenCatResult result) async {
    final session = _activeBonusSession;
    if (session == null) return;
    final credited = await _controller.creditGoldenCatOnce(session, result);
    if (!credited || !mounted) return;
    if (result.coinsWon > 0) {
      _audio.playCollectSound();
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _displayCoins = _controller.coins;
      _catMessage = result.coinsWon > 0
          ? 'Golden Cat bringt ${result.coinsWon} PurrCoins ins Körbchen.'
          : 'Die Goldkatze war schneller – dein Guthaben bleibt sicher.';
    });
  }

  Future<void> _onFishingCatCompleted(FishingCatResult result) async {
    final session = _activeBonusSession;
    if (session == null) return;
    final credited = await _controller.creditFishingCatOnce(session, result);
    if (!credited || !mounted) return;
    if (result.coinsWon > 0) {
      _audio.playCollectSound();
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _displayCoins = _controller.coins;
      _catMessage =
          'Fishing Cat tauscht ${result.pointsWon} Punkte in ${result.coinsWon} PurrCoins.';
    });
  }

  void _exitBonusGame() {
    if (!mounted) return;
    setState(() {
      _showBonusGame = false;
      _bonusTransitioning = false;
      _bonusLaunchPending = false;
      _bonusRevealed = false;
      _activeBonusSession = null;
      _catExcited = false;
      _catMessage = 'Zurück am Automaten. Die Bonuskatzen schnurren.';
    });
    if (_controller.pendingBonusGame != null) {
      Future.microtask(_beginBonusTransition);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _nextConsolationMessage() {
    final counts = <String, int>{};
    for (final symbol in _controller.slots) {
      counts[symbol] = (counts[symbol] ?? 0) + 1;
    }
    if (counts.values.any((count) => count == 2)) {
      return 'Fast! Die dritte Katze sitzt vermutlich im Karton.';
    }
    const messages = [
      'Katzenkonferenz ohne Einigung. Noch eine Runde?',
      'Kein Gewinn – aber drei ausgesprochen gute Katzen.',
      'Die Pfotenjury verlangt eine Wiederholung.',
      'Knapp daneben. Die Katzen tun ganz unschuldig.',
    ];
    final message = messages[_quipIndex % messages.length];
    _quipIndex++;
    return message;
  }

  void _scheduleSmallWinTransfer() {
    _smallWinTimer?.cancel();
    _smallWinTimer = Timer(CatSlotStyles.smallWinAutoCollectDelay, () {
      if (!mounted || _presentedWin <= 0) return;
      _startCoinTransfer(fromReels: true);
    });
  }

  /// Starts a visual transfer only. The controller balance was settled at the
  /// same moment as the spin result and is never changed from this callback.
  void _startCoinTransfer({required bool fromReels}) {
    if (_presentedWin <= 0) return;
    _smallWinTimer?.cancel();
    final balanceBox =
        _balanceKey.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.of(context).size;
    final reelBox = _reelKey.currentContext?.findRenderObject() as RenderBox?;
    _coinStart = fromReels && reelBox != null
        ? reelBox.localToGlobal(reelBox.size.center(Offset.zero))
        : Offset(screen.width / 2, screen.height / 2);

    if (balanceBox != null) {
      _coinTarget = balanceBox.localToGlobal(
        balanceBox.size.center(Offset.zero),
      );
    } else {
      _coinTarget = Offset(screen.width * 0.5, 72);
    }

    if (_reduceMotion) {
      _audio.playCollectSound();
      _finishWinPresentation();
      return;
    }

    _coinFlyKey = UniqueKey();
    setState(() {
      _showBigWinPanel = false;
      _showSmallWinChip = false;
      _showCoinFly = true;
    });
    _audio.playCollectSound();
  }

  void _onCoinArrived(int coinIndex) {
    const count = CatSlotStyles.coinCount;
    final base = _presentedWin ~/ count;
    final extra = _presentedWin % count;
    final increment = base + (coinIndex < extra ? 1 : 0);
    if (increment > 0 && mounted) {
      setState(() => _displayCoins += increment);
    }
  }

  void _onCoinsDone() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _showCoinFly = false;
      _showWinHighlight = false;
      _visualBalanceActive = false;
      _displayCoins = _controller.coins;
      _presentedWin = 0;
    });
  }

  void _finishWinPresentation({bool notify = true}) {
    _smallWinTimer?.cancel();
    final changed =
        _showBigWinPanel ||
        _showSmallWinChip ||
        _showWinHighlight ||
        _showCoinFly ||
        _visualBalanceActive;
    void finish() {
      _showBigWinPanel = false;
      _showSmallWinChip = false;
      _showWinHighlight = false;
      _showCoinFly = false;
      _visualBalanceActive = false;
      _displayCoins = _controller.coins;
      _presentedWin = 0;
    }

    if (notify && mounted && changed) {
      setState(finish);
    } else {
      finish();
    }
  }

  Future<void> _onReset() async {
    _smallWinTimer?.cancel();
    _bonusTransitionTimer?.cancel();
    _finishWinPresentation();
    await _controller.resetGame();
    if (!mounted) return;
    setState(() {
      _activeBonusSession = null;
      _showBonusGame = false;
      _bonusTransitioning = false;
      _bonusLaunchPending = false;
      _bonusRevealed = false;
      _displayCoins = _controller.coins;
      _catMessage = 'Neun Leben, neue Runde.';
      _catExcited = false;
    });
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE62D1B49), Color(0xE616102B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x667ADDD5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x332FD1C6),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x667ADDD5)),
                ),
                child: const Text('🐱', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAT SLOT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      'COZY CAT ARCADE',
                      style: TextStyle(
                        color: Color(0xFF9FE7E0),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _balanceKey,
            child: BalanceLabel(
              coins: _visualBalanceActive ? _displayCoins : _controller.coins,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 6,
            children: [
              _bonusProgressChip(
                key: const ValueKey('cat-switch-progress'),
                label: 'GOLDKATZE',
                value: _controller.goldenCatProgress,
              ),
              _bonusProgressChip(
                key: const ValueKey('fishing-cat-progress'),
                label: 'ANGELKATZE',
                value: _controller.fishingCatProgress,
              ),
            ],
          ),
          const SizedBox(height: 13),
          SymbolSetSelector(activeSet: _activeSet, onChanged: _onSetChanged),
          const SizedBox(height: 14),
          CatMoodChip(message: _catMessage, excited: _catExcited),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD91F1635), Color(0xF20D091B)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x668F78B7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 34,
            offset: Offset(0, 15),
          ),
          BoxShadow(color: Color(0x225ED7D0), blurRadius: 24, spreadRadius: -5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✦', style: TextStyle(color: Color(0xFFFFDF79))),
                SizedBox(width: 8),
                Text(
                  'THREE CATS · ONE PURRFECT MATCH',
                  style: TextStyle(
                    color: Color(0xBFF8F2FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  ),
                ),
                SizedBox(width: 8),
                Text('✦', style: TextStyle(color: Color(0xFFFFDF79))),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            key: _reelKey,
            height: CatSlotStyles.reelWindowHeight,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: CatSlotStyles.reelRowWidth,
                height: CatSlotStyles.reelWindowHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          if (i > 0)
                            const SizedBox(width: CatSlotStyles.reelSpacing),
                          SmoothReelBox(
                            key: ValueKey('${_activeSet.id}-$i'),
                            reelIndex: i,
                            targetSymbolId: _controller.slots[i],
                            spinning: _controller.reelSpinning[i],
                            highlightCenter: _showWinHighlight,
                            emphasizeBonusLanding: _bonusRevealed && i == 2,
                            reduceMotion: reduceMotion,
                          ),
                        ],
                      ],
                    ),
                    _WinLineOverlay(
                      visible: _showWinHighlight,
                      reduceMotion: reduceMotion,
                    ),
                    WinRevealBurst(
                      visible: _showWinHighlight,
                      reduceMotion: reduceMotion,
                      bigWin: _isBigWin,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SmallWinChip(
            visible: _showSmallWinChip,
            coinsWon: _presentedWin,
            reduceMotion: reduceMotion,
          ),
          SizedBox(height: _showSmallWinChip ? 12 : 4),
          if (_controller.coins > 0 ||
              _controller.isSpinning ||
              _showBigWinPanel ||
              _bonusTransitioning ||
              _showCoinFly)
            SpinButton(
              isSpinning: _controller.isSpinning || _spinRequestActive,
              onPressed:
                  _spinRequestActive ||
                      _controller.isSpinning ||
                      _controller.coins <= 0 ||
                      _showBigWinPanel ||
                      _bonusTransitioning ||
                      _activeBonusSession != null
                  ? null
                  : _onSpin,
            )
          else
            ResetButton(onPressed: _onReset),
          const SizedBox(height: 10),
          ResultLabel(text: _controller.result),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CozyCatBackdrop()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final pagePadding = constraints.maxWidth < 390 ? 12.0 : 20.0;
                final content = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 292, child: _buildInfoCard()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildGameCard(context)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 16),
                          _buildGameCard(context),
                        ],
                      );
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: pagePadding,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: wide
                          ? (constraints.maxHeight - 36).clamp(
                              0,
                              double.infinity,
                            )
                          : 0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: content,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_showBigWinPanel)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: WinPanel(
                visible: true,
                coinsWon: _presentedWin,
                onCollect: () => _startCoinTransfer(fromReels: false),
                reduceMotion: _reduceMotion,
              ),
            ),
          ),
        if (_showCoinFly)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: CoinFlyOverlay(
                key: _coinFlyKey,
                startCenter: _coinStart,
                targetCenter: _coinTarget,
                onDone: _onCoinsDone,
                onCoinArrived: _onCoinArrived,
                reduceMotion: _reduceMotion,
              ),
            ),
          ),
        if (_showBonusGame && _activeBonusSession?.game.id == kMouseHuntGameId)
          Positioned.fill(
            child: MouseHuntGame(
              session: _activeBonusSession!,
              onRoundCompleted: _onBonusCompleted,
              onExit: _exitBonusGame,
              reduceMotion: _reduceMotion,
              hunterSetId: _activeSet.id,
            ),
          ),
        if (_showBonusGame && _activeBonusSession?.game.id == kGoldenCatGameId)
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final assets = _goldenCatAssets;
                return GoldenCatChallenge(
                  session: _activeBonusSession!,
                  onRoundCompleted: _onGoldenCatCompleted,
                  onExit: _exitBonusGame,
                  reduceMotion: _reduceMotion,
                  catAssetPath: assets.isNotEmpty ? assets[0] : null,
                );
              },
            ),
          ),
        if (_showBonusGame && _activeBonusSession?.game.id == kFishingCatGameId)
          Positioned.fill(
            child: FishingCatGame(
              session: _activeBonusSession!,
              onRoundCompleted: _onFishingCatCompleted,
              onExit: _exitBonusGame,
              reduceMotion: _reduceMotion,
            ),
          ),
      ],
    );
  }

  Widget _bonusProgressChip({
    required Key key,
    required String label,
    required int value,
  }) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x552E4456),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x668CE4DC)),
    ),
    child: Text(
      '$label  $value/3',
      style: const TextStyle(
        color: Color(0xFFBFEDE8),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

// ── Pulsierende Gewinnlinie ───────────────────────────────────────────────────

class _WinLineOverlay extends StatefulWidget {
  final bool visible;
  final bool reduceMotion;

  const _WinLineOverlay({required this.visible, required this.reduceMotion});

  @override
  State<_WinLineOverlay> createState() => _WinLineOverlayState();
}

class _WinLineOverlayState extends State<_WinLineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulse = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.visible && !widget.reduceMotion) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_WinLineOverlay old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion) {
      _ctrl
        ..stop()
        ..reset();
    } else if (widget.visible && (!old.visible || old.reduceMotion)) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.visible && old.visible) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      child: IgnorePointer(
        child: SizedBox(
          width: CatSlotStyles.reelRowWidth,
          height: CatSlotStyles.reelWindowHeight,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = _pulse.value;
              // Linienstärke und Glow pulsieren
              final lineAlpha = 0.75 + t * 0.25; // 0.75 → 1.0
              final glowBlur = 6.0 + t * 18.0; // 6 → 24
              final glowSpread = 0.0 + t * 3.0; // 0 → 3
              final glowAlpha = 0.3 + t * 0.5; // 0.3 → 0.8
              // Sehr schmaler, kaum deckender Hintergrund-Glow
              final bgAlpha = 0.03 + t * 0.05; // 0.03 → 0.08

              Widget line(double top) => Positioned(
                top: top,
                left: 0,
                right: 0,
                height: CatSlotStyles.winLineThickness,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CatSlotStyles.winLineColor.withValues(
                      alpha: lineAlpha,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CatSlotStyles.winLineColor.withValues(
                          alpha: glowAlpha,
                        ),
                        blurRadius: glowBlur,
                        spreadRadius: glowSpread,
                      ),
                      // zweiter, weiterer Glow-Ring
                      BoxShadow(
                        color: CatSlotStyles.winLineColor.withValues(
                          alpha: glowAlpha * 0.4,
                        ),
                        blurRadius: glowBlur * 2.5,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              );

              return Stack(
                children: [
                  // Minimaler Hintergrund-Glow zwischen den Linien
                  Positioned(
                    top: CatSlotStyles.reelSymbolSize,
                    left: 0,
                    right: 0,
                    height: CatSlotStyles.reelSymbolSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CatSlotStyles.winLineColor.withValues(
                          alpha: bgAlpha,
                        ),
                      ),
                    ),
                  ),
                  // Obere Linie
                  line(
                    CatSlotStyles.reelSymbolSize -
                        CatSlotStyles.winLineThickness / 2,
                  ),
                  // Untere Linie
                  line(
                    CatSlotStyles.reelSymbolSize * 2 -
                        CatSlotStyles.winLineThickness / 2,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
