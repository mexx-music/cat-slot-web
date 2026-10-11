import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cat_slot_controller.dart';
import 'cat_slot_styles.dart';
import 'data/slot_symbol_sets.dart';
import 'models/symbol_set.dart';
import 'services/audio_service.dart';
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
  const CatSlotPage({super.key});

  @override
  State<CatSlotPage> createState() => _CatSlotPageState();
}

class _CatSlotPageState extends State<CatSlotPage> {
  final CatSlotController _controller = CatSlotController();
  final AudioService _audio = AudioService();

  bool _showWinOverlay = false;
  bool _winCollected = true;
  bool _showCoinFly = false;

  // Visual coin counter: increments per arriving coin during fly animation
  int _displayCoins = 0;
  int _coinFlyPendingWin = 0;
  int _quipIndex = 0;
  String _catMessage = 'Die Katzen machen sich bereit.';
  bool _catExcited = false;

  // Aktives Symbol-Set
  SymbolSet _activeSet = kActiveSymbolSet;

  // GlobalKeys zum Ermitteln der Screen-Positionen
  final GlobalKey _balanceKey = GlobalKey();

  // Ermittelte Positionen für die Coin-Animation
  Offset _coinStart = Offset.zero;
  Offset _coinTarget = Offset.zero;

  // Stabiler Key für CoinFlyOverlay – wird einmalig in _onCollect() gesetzt,
  // damit Page-Rebuilds (z. B. aus _onCoinArrived) den Key NICHT erneut
  // erzeugen und das laufende Overlay nicht zerstören.
  Key _coinFlyKey = const ValueKey('coin-fly-initial');

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  /// Wechselt das aktive Symbol-Set und baut die Rollen neu auf.
  Future<void> _onSetChanged(SymbolSet set) async {
    if (_controller.isSpinning) return; // kein Wechsel während Spin
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
      // Gewinn-Zustand zurücksetzen damit kein veraltetes Highlighting bleibt
      _winCollected = true;
      _showWinOverlay = false;
      _catMessage = '${set.label}: neue Katzen, gleiches Glück.';
      _catExcited = false;
    });
  }

  Future<void> _onSpin() async {
    HapticFeedback.lightImpact();
    await _audio.ensureUnlockedAndPreload(); // iOS: Preload beim ersten Tap
    _audio.playSpinSound(); // startet Purr-Loop
    setState(() {
      _winCollected = true;
      _catExcited = false;
      _catMessage = 'Pfoten weg vom Hebel … jetzt wird geschnurrt!';
    });
    await _controller.spin(
      _refresh,
      onReelStop: (i) {
        _audio.playReelStopSound(i);
        HapticFeedback.selectionClick();
      },
    );
    _audio.stopPurrLoop(); // Purr immer stoppen nach Spin-Ende
    if (!mounted) return;
    if (_controller.pendingWin > 0) {
      HapticFeedback.mediumImpact();
      _audio.playWinSound();
      setState(() {
        _showWinOverlay = true;
        _winCollected = false;
        _catExcited = true;
        _catMessage = 'Miau-nificent! Drei Katzen sind sich endlich einig.';
      });
    } else {
      setState(() {
        _catExcited = false;
        _catMessage = _nextConsolationMessage();
      });
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

  /// Wird beim Klick auf COLLECT aufgerufen:
  /// 1. Win-Overlay schließen
  /// 2. Positionen ermitteln
  /// 3. Coin-Fly-Animation starten
  void _onCollect() {
    // Positionen jetzt ermitteln (Widgets sind noch im Tree)
    final balanceBox =
        _balanceKey.currentContext?.findRenderObject() as RenderBox?;

    // Start = Bildschirmmitte – exakt dort, wo der Win-Betrag im Panel stand.
    // So wirkt es, als würde der Betrag sich in Münzen auflösen.
    final screen = MediaQuery.of(context).size;
    _coinStart = Offset(screen.width / 2, screen.height / 2);

    if (balanceBox != null) {
      final balanceSize = balanceBox.size;
      _coinTarget = balanceBox.localToGlobal(
        Offset(balanceSize.width / 2, balanceSize.height / 2),
      );
    }

    _coinFlyPendingWin = _controller.pendingWin;
    _displayCoins = _controller.coins;
    // Neuen stabilen Key erzeugen BEVOR setState – bleibt in allen
    // Folge-Rebuilds dieser Collect-Session konstant.
    _coinFlyKey = UniqueKey();
    setState(() {
      _showWinOverlay = false;
      _winCollected = true;
      _showCoinFly = true;
    });
    _audio.playCollectSound();
  }

  /// Called once for each coin that arrives at the credits bar.
  void _onCoinArrived(int coinIndex) {
    final total = _coinFlyPendingWin;
    const count = CatSlotStyles.coinCount;
    final base = total ~/ count;
    final extra = total % count;
    // Distribute remainder across first `extra` coins
    final increment = base + (coinIndex < extra ? 1 : 0);
    if (increment > 0) setState(() => _displayCoins += increment);
  }

  /// Wird aufgerufen wenn alle Münzen angekommen sind.
  void _onCoinsDone() {
    _controller.collectWin();
    setState(() {
      _showCoinFly = false;
      _displayCoins = _controller.coins;
    });
  }

  void _onReset() {
    setState(() {
      _showWinOverlay = false;
      _winCollected = true;
      _showCoinFly = false;
      _controller.resetGame();
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
              coins: _showCoinFly ? _displayCoins : _controller.coins,
            ),
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
                            targetSymbol: _controller.slots[i],
                            spinning: _controller.reelSpinning[i],
                            highlightCenter: !_winCollected,
                            reduceMotion: reduceMotion,
                          ),
                        ],
                      ],
                    ),
                    _WinLineOverlay(visible: _controller.pendingWin > 0),
                    WinRevealBurst(visible: !_winCollected),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_controller.coins > 0 ||
              _controller.isSpinning ||
              _showWinOverlay ||
              _showCoinFly)
            SpinButton(
              isSpinning: _controller.isSpinning,
              onPressed: _controller.isSpinning || _controller.coins <= 0
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
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: WinPanel(
              visible: _showWinOverlay,
              coinsWon: _controller.pendingWin,
              onCollect: _onCollect,
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
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pulsierende Gewinnlinie ───────────────────────────────────────────────────

class _WinLineOverlay extends StatefulWidget {
  final bool visible;
  const _WinLineOverlay({required this.visible});

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
    if (widget.visible) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_WinLineOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
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
      duration: const Duration(milliseconds: 300),
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
