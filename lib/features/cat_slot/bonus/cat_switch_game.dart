import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bonus_game.dart';
import '../services/cat_switch_system.dart';
import '../widgets/cat_switch_art.dart';

class CatSwitchGame extends StatefulWidget {
  final BonusGameSession session;
  final ValueChanged<CatSwitchResult> onRoundCompleted;
  final VoidCallback onExit;
  final bool reduceMotion;
  final Random? random;
  final int rounds;
  final String? targetAssetPath;
  final String? distractorAssetPath;

  const CatSwitchGame({
    super.key,
    required this.session,
    required this.onRoundCompleted,
    required this.onExit,
    this.reduceMotion = false,
    this.random,
    this.rounds = CatSwitchEconomy.rounds,
    this.targetAssetPath,
    this.distractorAssetPath,
  });

  @override
  State<CatSwitchGame> createState() => _CatSwitchGameState();
}

class _CatSwitchGameState extends State<CatSwitchGame>
    with WidgetsBindingObserver {
  late final Random _random;
  Timer? _swapTimer;
  Timer? _feedbackTimer;
  int _round = 1;
  int _correct = 0;
  bool _targetLeft = true;
  bool _inputLocked = true;
  bool _swapping = false;
  bool? _lastCorrect;
  bool _finished = false;
  bool _completionSent = false;
  CatSwitchResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _random = widget.random ?? Random();
    _targetLeft = _random.nextBool();
    _feedbackTimer = Timer(
      widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
      _startRound,
    );
  }

  Duration get _swapInterval =>
      Duration(milliseconds: max(480, 900 - (_round - 1) * 42));

  void _startRound() {
    if (!mounted || _finished) return;
    setState(() {
      _inputLocked = false;
      _lastCorrect = null;
    });
    if (!widget.reduceMotion) _scheduleSwap();
  }

  void _scheduleSwap() {
    _swapTimer?.cancel();
    if (_finished || _inputLocked) return;
    _swapTimer = Timer(_swapInterval, _performSwap);
  }

  void _performSwap() {
    if (!mounted || _finished || _inputLocked) return;
    setState(() {
      _swapping = true;
      _inputLocked = true;
      _targetLeft = !_targetLeft;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 190), () {
      if (!mounted || _finished) return;
      setState(() {
        _swapping = false;
        _inputLocked = false;
      });
      _scheduleSwap();
    });
  }

  void _choose(bool tappedLeft) {
    if (_finished || _inputLocked || _swapping) return;
    _swapTimer?.cancel();
    _inputLocked = true;
    final correct = tappedLeft == _targetLeft;
    if (correct) {
      _correct++;
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() => _lastCorrect = correct);
    _feedbackTimer = Timer(
      widget.reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 520),
      _nextRound,
    );
  }

  void _nextRound() {
    if (!mounted || _finished) return;
    if (_round >= widget.rounds) {
      _finish();
      return;
    }
    setState(() {
      _round++;
      _targetLeft = _random.nextBool();
      _lastCorrect = null;
      _inputLocked = widget.reduceMotion;
    });
    if (widget.reduceMotion) {
      _feedbackTimer = Timer(Duration.zero, _startRound);
    } else {
      _startRound();
    }
  }

  void _finish({bool skipped = false}) {
    if (_finished) return;
    _finished = true;
    _swapTimer?.cancel();
    _feedbackTimer?.cancel();
    final result = CatSwitchResult(
      correct: _correct,
      roundsPlayed: skipped
          ? _round - (_lastCorrect == null ? 1 : 0)
          : widget.rounds,
      coinsWon: CatSwitchEconomy.rewardFor(_correct),
      skipped: skipped,
    );
    _result = result;
    if (!_completionSent) {
      _completionSent = true;
      widget.onRoundCompleted(result);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _finish(skipped: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swapTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('cat-switch-game'),
    color: const Color(0xFF100A20),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _finished ? _buildResult() : _buildGame(),
          ),
        ),
      ),
    ),
  );

  Widget _buildGame() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 620 || constraints.maxWidth < 340;
      return Column(
        children: [
          Row(
            children: [
              CatSwitchSymbol(size: compact ? 34 : 46),
              SizedBox(width: compact ? 6 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CAT SWITCH',
                      style: TextStyle(
                        fontSize: compact ? 16 : 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Runde $_round/${widget.rounds} · $_correct Treffer',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: compact ? 11 : 14,
                        color: const Color(0xFF9FE7E0),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('skip-cat-switch'),
                style: compact
                    ? TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 11),
                      )
                    : null,
                onPressed: () => _finish(skipped: true),
                child: const Text('ÜBERSPRINGEN'),
              ),
            ],
          ),
          SizedBox(height: compact ? 5 : 12),
          Text(
            'Finde die Katze mit dem goldenen Anhänger',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              color: const Color(0xFFFFE49A),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 6 : 12),
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: widget.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              tween: Tween(begin: .86, end: 1),
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Row(
                children: [
                  Expanded(child: _card(left: true)),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(child: _card(left: false)),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _lastCorrect == null
                  ? (_swapping ? 'Pfoten still …' : 'Jetzt tippen!')
                  : _lastCorrect!
                  ? 'Purrfekt gefangen!'
                  : 'Miau daneben – nächste Runde!',
              key: ValueKey(_lastCorrect),
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                color: _lastCorrect == false
                    ? const Color(0xFFFFA6B2)
                    : const Color(0xFFBFF4E8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _card({required bool left}) {
    final target = left == _targetLeft;
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey(left ? 'cat-switch-left' : 'cat-switch-right'),
        onTap: _inputLocked ? null : () => _choose(left),
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: widget.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: target
                  ? const [Color(0xFF315B62), Color(0xFF1C2940)]
                  : const [Color(0xFF3C2852), Color(0xFF20162E)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: target ? const Color(0xFF8CE4DC) : const Color(0xFF79628D),
              width: 2,
            ),
          ),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 170),
              scale: _swapping ? 0.88 : 1,
              child: CatSwitchPortrait(
                target: target,
                celebrating: _lastCorrect == true && target,
                size: 150,
                assetPath: target
                    ? widget.targetAssetPath
                    : widget.distractorAssetPath,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          key: const ValueKey('cat-switch-result'),
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF315B62), Color(0xFF20162E)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF8CE4DC)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CatSwitchPortrait(
                target: true,
                celebrating: true,
                size: 118,
                assetPath: widget.targetAssetPath,
              ),
              const Text(
                'PFOTEN-SCHARF!',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              Text(
                '${result.correct}/${widget.rounds} Bonuskatzen erkannt',
                style: const TextStyle(color: Color(0xFFBFEDE8)),
              ),
              const SizedBox(height: 12),
              Text(
                '+${result.coinsWon}',
                key: const ValueKey('cat-switch-reward'),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE49A),
                ),
              ),
              const Text(
                'PURRCOINS',
                style: TextStyle(letterSpacing: 3, color: Color(0xFFD7C478)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('return-from-cat-switch'),
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
