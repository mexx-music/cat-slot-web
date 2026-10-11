import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bonus_game.dart';
import '../services/golden_cat_system.dart';
import '../widgets/golden_cat_art.dart';

typedef GoldenCatCompletion = Future<void> Function(GoldenCatResult result);

class GoldenCatChallenge extends StatefulWidget {
  final BonusGameSession session;
  final GoldenCatCompletion onRoundCompleted;
  final VoidCallback onExit;
  final bool reduceMotion;
  final String? catAssetPath;

  const GoldenCatChallenge({
    super.key,
    required this.session,
    required this.onRoundCompleted,
    required this.onExit,
    this.reduceMotion = false,
    this.catAssetPath,
  });

  @override
  State<GoldenCatChallenge> createState() => _GoldenCatChallengeState();
}

class _GoldenCatChallengeState extends State<GoldenCatChallenge>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _blink;
  Timer? _introTimer;
  int _stage = 1;
  bool _inputLocked = true;
  bool _showDecision = false;
  bool _finished = false;
  bool _settling = false;
  bool _pausedDuringRound = false;
  bool _hitPulse = false;
  GoldenCatResult? _result;

  Duration get _interval {
    final configured = GoldenCatEconomy.intervalForStage(_stage);
    if (!widget.reduceMotion) return configured;
    return configured < const Duration(milliseconds: 600)
        ? const Duration(milliseconds: 600)
        : configured;
  }

  bool get _goldenVisible => GoldenCatTiming.isGoldenAtCycleValue(_blink.value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _blink = AnimationController(vsync: this, duration: _interval * 2);
    _introTimer = Timer(
      widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
      _startStage,
    );
  }

  void _startStage() {
    if (!mounted || _finished || _showDecision) return;
    _blink
      ..duration = _interval * 2
      ..value = 0
      ..repeat();
    setState(() {
      _inputLocked = false;
      _hitPulse = false;
      _pausedDuringRound = false;
    });
  }

  void _tapNow() {
    if (_inputLocked || _showDecision || _finished || !_blink.isAnimating) {
      return;
    }
    // The controller value is advanced by Flutter's monotonic frame ticker and
    // is also the value used by AnimatedBuilder for the visible cat.
    final hit = _goldenVisible;
    _inputLocked = true;
    _blink.stop(canceled: false);
    if (!hit) {
      HapticFeedback.selectionClick();
      _complete(
        GoldenCatResult(
          stageReached: _stage,
          coinsWon: 0,
          cashedOut: false,
          missed: true,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    if (_stage == GoldenCatEconomy.stages) {
      _complete(
        GoldenCatResult(
          stageReached: _stage,
          coinsWon: GoldenCatEconomy.payoutForStage(_stage),
          cashedOut: true,
          missed: false,
        ),
      );
      return;
    }
    setState(() {
      _showDecision = true;
      _hitPulse = true;
    });
  }

  void _riskNextStage() {
    if (!_showDecision || _finished) return;
    setState(() {
      _stage++;
      _showDecision = false;
      _inputLocked = true;
      _hitPulse = false;
    });
    _startStage();
  }

  void _cashOut() {
    if (!_showDecision || _finished) return;
    _complete(
      GoldenCatResult(
        stageReached: _stage,
        coinsWon: GoldenCatEconomy.payoutForStage(_stage),
        cashedOut: true,
        missed: false,
      ),
    );
  }

  Future<void> _complete(GoldenCatResult result) async {
    if (_finished) return;
    _finished = true;
    _settling = true;
    _inputLocked = true;
    _blink.stop(canceled: false);
    _introTimer?.cancel();
    _result = result;
    if (mounted) setState(() {});
    await widget.onRoundCompleted(result);
    if (!mounted) return;
    setState(() => _settling = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished || _showDecision) return;
    if (state != AppLifecycleState.resumed) {
      _introTimer?.cancel();
      _pausedDuringRound = true;
      _inputLocked = true;
      if (_blink.isAnimating) _blink.stop(canceled: false);
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _pausedDuringRound) {
      // Restart the same risk stage from a clear normal-cat frame. A pause can
      // therefore neither award a hidden hit nor cause an unfair miss.
      _startStage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introTimer?.cancel();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('golden-cat-challenge'),
    color: const Color(0xFF100A20),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _finished ? _buildResult() : _buildChallenge(),
          ),
        ),
      ),
    ),
  );

  Widget _buildChallenge() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 620;
      return Column(
        children: [
          Text(
            'GOLDEN CAT CHALLENGE',
            style: TextStyle(
              fontSize: compact ? 19 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: const Color(0xFFFFE08A),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Triff die goldene Katze!',
            style: TextStyle(color: Color(0xFFBFEDE8)),
          ),
          SizedBox(height: compact ? 8 : 14),
          _buildStageHeader(compact),
          SizedBox(height: compact ? 5 : 8),
          _buildStageProgress(compact),
          SizedBox(height: compact ? 7 : 12),
          Expanded(child: _buildCatField(compact)),
          SizedBox(height: compact ? 7 : 12),
          if (_showDecision) _buildDecision(compact) else _buildNowButton(),
          if (widget.reduceMotion)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Reduzierte Bewegung: ruhiger Wechsel',
                style: TextStyle(fontSize: 11, color: Color(0xFF9BB7BE)),
              ),
            ),
        ],
      );
    },
  );

  Widget _buildStageHeader(bool compact) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 12 : 18,
      vertical: compact ? 7 : 10,
    ),
    decoration: BoxDecoration(
      color: const Color(0x552E4456),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x77FFD65A)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'STUFE $_stage/${GoldenCatEconomy.stages}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '×${GoldenCatEconomy.multiplierForStage(_stage)}',
          key: const ValueKey('golden-cat-multiplier'),
          style: TextStyle(
            fontSize: compact ? 23 : 29,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFD65A),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${GoldenCatEconomy.payoutForStage(_stage)} Coins',
          style: const TextStyle(color: Color(0xFFBFEDE8)),
        ),
      ],
    ),
  );

  Widget _buildStageProgress(bool compact) => Semantics(
    label: 'Stufe $_stage von ${GoldenCatEconomy.stages}',
    child: Row(
      key: const ValueKey('golden-cat-stage-progress'),
      children: [
        for (var stage = 1; stage <= GoldenCatEconomy.stages; stage++) ...[
          if (stage > 1) const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: widget.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  height: compact ? 6 : 8,
                  decoration: BoxDecoration(
                    color: stage < _stage
                        ? const Color(0xFFFFE99A)
                        : stage == _stage
                        ? const Color(0xFFFFC83D)
                        : const Color(0xFF45505C),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: stage == _stage
                        ? const [
                            BoxShadow(color: Color(0x88FFD65A), blurRadius: 8),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${GoldenCatEconomy.payoutForStage(stage)}',
                  key: ValueKey('golden-cat-ladder-stage-$stage'),
                  style: TextStyle(
                    color: stage == _stage
                        ? const Color(0xFFFFE08A)
                        : const Color(0xFF91A6AD),
                    fontSize: compact ? 8 : 9,
                    fontWeight: stage == _stage
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildCatField(bool compact) => AnimatedBuilder(
    animation: _blink,
    builder: (context, child) {
      final golden = _showDecision || _hitPulse || _goldenVisible;
      return AnimatedContainer(
        key: ValueKey(golden ? 'golden-cat-visible' : 'normal-cat-visible'),
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 90),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: golden
                ? const [Color(0xFF66501C), Color(0xFF21152D)]
                : const [Color(0xFF324B58), Color(0xFF21152D)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: golden ? const Color(0xFFFFD65A) : const Color(0xFF7896A1),
            width: 2,
          ),
          boxShadow: golden
              ? const [BoxShadow(color: Color(0x55FFD65A), blurRadius: 24)]
              : null,
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .9, end: 1),
            duration: widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: GoldenCatPortrait(
              golden: golden,
              celebrating: _showDecision,
              size: compact ? 190 : 260,
              assetPath: widget.catAssetPath,
            ),
          ),
        ),
      );
    },
  );

  Widget _buildNowButton() => SizedBox(
    width: double.infinity,
    height: 62,
    child: FilledButton(
      key: const ValueKey('golden-cat-now'),
      onPressed: _inputLocked ? null : _tapNow,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFD65A),
        foregroundColor: const Color(0xFF38230A),
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      child: Text(_pausedDuringRound ? 'PAUSIERT' : 'JETZT!'),
    ),
  );

  Widget _buildDecision(bool compact) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Treffer! Du hast ${GoldenCatEconomy.payoutForStage(_stage)} Coins erreicht!',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFE08A),
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 7),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('golden-cat-cash-out'),
              onPressed: _cashOut,
              child: Text(
                _stage == 5
                    ? compact
                          ? '1.000 NEHMEN'
                          : '1.000 COINS NEHMEN'
                    : compact
                    ? 'NEHMEN'
                    : 'GEWINN NEHMEN',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('golden-cat-risk'),
              onPressed: _riskNextStage,
              child: Text(
                _stage == 5
                    ? compact
                          ? 'LEVEL 6'
                          : 'LEVEL 6 RISKIEREN'
                    : compact
                    ? 'RISKIEREN'
                    : 'WEITER RISKIEREN',
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildResult() {
    final result = _result!;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          key: const ValueKey('golden-cat-result'),
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5C4518), Color(0xFF21152D)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFFFD65A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoldenCatPortrait(
                golden: !result.missed,
                celebrating: !result.missed,
                disappointed: result.missed,
                size: 132,
                assetPath: widget.catAssetPath,
              ),
              Text(
                result.missed ? 'MIAU – KNAPP DANEBEN!' : 'GOLDENE PFOTEN!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.missed
                    ? 'Der ungesicherte Bonus verfällt. Dein Guthaben bleibt unangetastet.'
                    : 'Stufe ${result.stageReached} sicher ausgezahlt',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBFEDE8)),
              ),
              Text(
                '+${result.coinsWon}',
                key: const ValueKey('golden-cat-reward'),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE08A),
                ),
              ),
              const Text(
                'PURRCOINS',
                style: TextStyle(letterSpacing: 3, color: Color(0xFFD7C478)),
              ),
              const SizedBox(height: 16),
              if (_settling)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Auszahlung wird sicher gespeichert …'),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('return-from-golden-cat'),
                    onPressed: widget.onExit,
                    child: const Text('ZURÜCK ZUM SLOT'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
