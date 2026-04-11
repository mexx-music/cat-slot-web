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

class CatSlotPage extends StatefulWidget {
  const CatSlotPage({super.key});

  @override
  State<CatSlotPage> createState() => _CatSlotPageState();
}

class _CatSlotPageState extends State<CatSlotPage> {
  final CatSlotController _controller = CatSlotController();
  final AudioService _audio = AudioService();

  bool _showWinOverlay = false;
  bool _winCollected   = true;
  bool _showCoinFly    = false;

  // Aktives Symbol-Set
  SymbolSet _activeSet = kActiveSymbolSet;

  // GlobalKeys zum Ermitteln der Screen-Positionen
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _reelStackKey = GlobalKey();

  // Ermittelte Positionen für die Coin-Animation
  Offset _coinStart  = Offset.zero;
  Offset _coinTarget = Offset.zero;

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
      _winCollected   = true;
      _showWinOverlay = false;
    });
  }

  Future<void> _onSpin() async {
    await _audio.ensureUnlockedAndPreload(); // iOS: Preload beim ersten Tap
    _audio.playSpinSound();                  // startet Purr-Loop
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
        _winCollected   = false;
      });
    }
  }

  /// Wird beim Klick auf COLLECT aufgerufen:
  /// 1. Win-Overlay schließen
  /// 2. Positionen ermitteln
  /// 3. Coin-Fly-Animation starten
  void _onCollect() {
    // Positionen jetzt ermitteln (Widgets sind noch im Tree)
    final reelBox     = _reelStackKey.currentContext?.findRenderObject() as RenderBox?;
    final balanceBox  = _balanceKey.currentContext?.findRenderObject() as RenderBox?;

    if (reelBox != null && balanceBox != null) {
      final reelSize    = reelBox.size;
      final balanceSize = balanceBox.size;
      _coinStart  = reelBox.localToGlobal(Offset(reelSize.width / 2, reelSize.height / 2));
      _coinTarget = balanceBox.localToGlobal(Offset(balanceSize.width / 2, balanceSize.height / 2));
    }

    setState(() {
      _showWinOverlay = false;
      _winCollected   = true;
      _showCoinFly    = true;
    });
    _audio.playCollectSound();
  }

  /// Wird aufgerufen wenn alle Münzen angekommen sind.
  void _onCoinsDone() {
    _controller.collectWin();
    setState(() => _showCoinFly = false);
  }

  void _onReset() {
    setState(() {
      _showWinOverlay = false;
      _winCollected   = true;
      _showCoinFly    = false;
      _controller.resetGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Hintergrundbild ───────────────────────────────────────────
        Positioned.fill(
          child: Image.asset(
            'assets/cat_slot/ui/background.png',
            fit: BoxFit.cover,
            // Fallback: einfache Hintergrundfarbe wenn Bild noch fehlt
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: CatSlotStyles.scaffoldBackground,
            ),
          ),
        ),
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
                      const Text(
                        'Cat Slot',
                        style: TextStyle(
                          fontSize: CatSlotStyles.titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: CatSlotStyles.darkBgTextColor,
                          shadows: CatSlotStyles.darkBgTextShadows,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── Set-Auswahl (optional, leicht entfernbar) ────────
                      SymbolSetSelector(
                        activeSet: _activeSet,
                        onChanged: _onSetChanged,
                      ),
                      const SizedBox(height: CatSlotStyles.titleSpacing),
                      KeyedSubtree(
                        key: _balanceKey,
                        child: BalanceLabel(coins: _controller.coins),
                      ),
                      const SizedBox(height: CatSlotStyles.sectionSpacing),
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
                    ],
                  ),
                  const SizedBox(height: CatSlotStyles.sectionSpacing),
                  if (_controller.coins > 0)
                    SpinButton(
                      isSpinning: _controller.isSpinning,
                      onPressed: _controller.isSpinning ? null : _onSpin,
                    )
                  else
                    ResetButton(onPressed: _onReset),
                  const SizedBox(height: CatSlotStyles.sectionSpacing),
                  ResultLabel(text: _controller.result),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
        // ── Win-Overlay ─────────────────────────────────────────────
        _WinOverlay(
          visible: _showWinOverlay,
          onCollect: _onCollect,
          coinsWon: _controller.pendingWin,
        ),
        // ── Coin-Fly-Animation ───────────────────────────────────────
        if (_showCoinFly)
          Positioned.fill(
            child: CoinFlyOverlay(
              key: UniqueKey(),
              startCenter:  _coinStart,
              targetCenter: _coinTarget,
              onDone: _onCoinsDone,
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
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
              final lineAlpha  = 0.75 + t * 0.25;          // 0.75 → 1.0
              final glowBlur   = 6.0  + t * 18.0;          // 6 → 24
              final glowSpread = 0.0  + t * 3.0;           // 0 → 3
              final glowAlpha  = 0.3  + t * 0.5;           // 0.3 → 0.8
              // Sehr schmaler, kaum deckender Hintergrund-Glow
              final bgAlpha    = 0.03 + t * 0.05;          // 0.03 → 0.08

              Widget line(double top) => Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    height: CatSlotStyles.winLineThickness,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CatSlotStyles.winLineColor
                            .withValues(alpha: lineAlpha),
                        boxShadow: [
                          BoxShadow(
                            color: CatSlotStyles.winLineColor
                                .withValues(alpha: glowAlpha),
                            blurRadius: glowBlur,
                            spreadRadius: glowSpread,
                          ),
                          // zweiter, weiterer Glow-Ring
                          BoxShadow(
                            color: CatSlotStyles.winLineColor
                                .withValues(alpha: glowAlpha * 0.4),
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
                        color: CatSlotStyles.winLineColor
                            .withValues(alpha: bgAlpha),
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

// ── Win-Overlay Widget ────────────────────────────────────────────────────────

class _WinOverlay extends StatefulWidget {
  final bool visible;
  final VoidCallback onCollect;
  final int coinsWon;

  const _WinOverlay({
    required this.visible,
    required this.onCollect,
    required this.coinsWon,
  });

  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay>
    with TickerProviderStateMixin {
  // ── Eintritts-Animation (einmalig) ───────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<double>   _fade;
  late final Animation<double>   _entryScale;

  // ── Puls-Animation (dauerhaft, solange sichtbar) ─────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseOpacity;
  late final Animation<double>   _pulseScale;

  @override
  void initState() {
    super.initState();

    // Eintritt
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );

    // Puls
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseOpacity = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (widget.visible) _playEntry();
  }

  void _playEntry() {
    _entryCtrl.forward(from: 0).then((_) {
      if (mounted && widget.visible) _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void didUpdateWidget(_WinOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      _playEntry();
    } else if (!widget.visible && old.visible) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      _entryCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: CatSlotStyles.winOverlayBg,
          child: Center(
            child: ScaleTransition(
              scale: _entryScale,
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Opacity(
                  opacity: _pulseOpacity.value,
                  child: Transform.scale(
                    scale: _pulseScale.value,
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A3B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: CatSlotStyles.winLineColor,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CatSlotStyles.winLineColor
                            .withValues(alpha: 0.65),
                        blurRadius: 56,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: CatSlotStyles.winLineColor
                            .withValues(alpha: 0.25),
                        blurRadius: 130,
                        spreadRadius: 28,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🐱', style: TextStyle(fontSize: 58)),
                      const SizedBox(height: 10),
                      Text(
                        'YOU WIN!',
                        style: TextStyle(
                          fontSize: CatSlotStyles.winOverlayFontSize,
                          fontWeight: FontWeight.w900,
                          color: CatSlotStyles.winOverlayText,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: CatSlotStyles.winLineColor
                                  .withValues(alpha: 1.0),
                              blurRadius: 28,
                            ),
                            Shadow(
                              color: CatSlotStyles.winLineColor
                                  .withValues(alpha: 0.6),
                              blurRadius: 64,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      ElevatedButton(
                        onPressed: widget.onCollect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CatSlotStyles.winLineColor,
                          foregroundColor: const Color(0xFF1A0A3B),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text('COLLECT ${widget.coinsWon} PURRCOINS'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

