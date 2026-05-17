import 'package:flutter/material.dart';
import 'cat_slot_controller.dart';
import 'cat_slot_styles.dart';
import 'data/slot_symbol_sets.dart';
import 'models/symbol_set.dart';
import 'services/audio_service.dart';
import 'widgets/balance_label.dart';
import 'widgets/coin_fly_overlay.dart';
import 'widgets/reel_box.dart';
import 'widgets/reset_button.dart';
import 'widgets/spin_button.dart';
import 'widgets/result_label.dart';
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

  // Aktives Symbol-Set
  SymbolSet _activeSet = kActiveSymbolSet;

  // GlobalKeys zum Ermitteln der Screen-Positionen
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _reelStackKey = GlobalKey();

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
  void _onSetChanged(SymbolSet set) {
    if (_controller.isSpinning) return; // kein Wechsel während Spin
    setState(() {
      kActiveSymbolSet = set;
      _activeSet = set;
      _controller.refreshReels();
      // Gewinn-Zustand zurücksetzen damit kein veraltetes Highlighting bleibt
      _winCollected = true;
      _showWinOverlay = false;
    });
  }

  Future<void> _onSpin() async {
    await _audio.ensureUnlockedAndPreload(); // iOS: Preload beim ersten Tap
    _audio.playSpinSound(); // startet Purr-Loop
    setState(() => _winCollected = true);
    await _controller.spin(
      () => setState(() {}),
      onReelStop: (i) => _audio.playReelStopSound(i),
    );
    _audio.stopPurrLoop(); // Purr immer stoppen nach Spin-Ende
    if (_controller.result == 'You win!') {
      _audio.playWinSound();
      setState(() {
        _showWinOverlay = true;
        _winCollected = false;
      });
    }
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Hintergrundbild (Vegas) ──────────────────────────────────
        Positioned.fill(
          child: Image.asset(
            'assets/cat_slot/ui/vegascat.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: CatSlotStyles.scaffoldBackground),
          ),
        ),
        // Leichtes dunkles Overlay für Lesbarkeit
        Positioned.fill(child: ColoredBox(color: Color(0x44000000))),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CatSlotStyles.pagePadding,
                    vertical: CatSlotStyles.pagePadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Info-Panel (Titel, Set, Balance) ────────────────
                      Container(
                        width: CatSlotStyles.reelRowWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: CatSlotStyles.panelBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0x88D4AF37),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Cat Slot',
                              style: TextStyle(
                                fontSize: CatSlotStyles.titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: CatSlotStyles.darkBgTextColor,
                                shadows: CatSlotStyles.darkBgTextShadows,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SymbolSetSelector(
                              activeSet: _activeSet,
                              onChanged: _onSetChanged,
                            ),
                            const SizedBox(height: 6),
                            KeyedSubtree(
                              key: _balanceKey,
                              child: BalanceLabel(
                                coins: _showCoinFly
                                    ? _displayCoins
                                    : _controller.coins,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Stack(
                        key: _reelStackKey,
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: CatSlotStyles.reelRowWidth,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ReelBox(
                                  key: const ValueKey(0),
                                  targetSymbol: _controller.slots[0],
                                  spinning: _controller.reelSpinning[0],
                                  highlightCenter: !_winCollected,
                                ),
                                ReelBox(
                                  key: const ValueKey(1),
                                  targetSymbol: _controller.slots[1],
                                  spinning: _controller.reelSpinning[1],
                                  highlightCenter: !_winCollected,
                                ),
                                ReelBox(
                                  key: const ValueKey(2),
                                  targetSymbol: _controller.slots[2],
                                  spinning: _controller.reelSpinning[2],
                                  highlightCenter: !_winCollected,
                                ),
                              ],
                            ),
                          ),
                          // ── Gewinnlinie-Overlay ──────────────────────────────
                          _WinLineOverlay(
                            visible: _controller.result == 'You win!',
                          ),
                          // ── Phase 1: Reveal-Burst über der Mittelreihe ──────
                          WinRevealBurst(visible: !_winCollected),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (_controller.coins > 0 ||
                          _controller.isSpinning ||
                          _showWinOverlay ||
                          _showCoinFly)
                        SpinButton(
                          isSpinning: _controller.isSpinning,
                          onPressed:
                              _controller.isSpinning || _controller.coins <= 0
                              ? null
                              : _onSpin,
                        )
                      else
                        ResetButton(onPressed: _onReset),
                      const SizedBox(height: 12),
                      ResultLabel(text: _controller.result),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Win-Overlay (Phase 2 – Luxus-Panel) ─────────────────────
        Positioned.fill(
          child: WinPanel(
            visible: _showWinOverlay,
            coinsWon: _controller.pendingWin,
            onCollect: _onCollect,
          ),
        ),
        // ── Coin-Fly-Animation ───────────────────────────────────────
        if (_showCoinFly)
          Positioned.fill(
            child: CoinFlyOverlay(
              key: _coinFlyKey,
              startCenter: _coinStart,
              targetCenter: _coinTarget,
              onDone: _onCoinsDone,
              onCoinArrived: _onCoinArrived,
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

