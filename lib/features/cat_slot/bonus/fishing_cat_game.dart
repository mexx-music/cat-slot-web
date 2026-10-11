import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bonus_game.dart';
import '../services/fishing_cat_system.dart';
import '../widgets/fishing_cat_art.dart';

typedef FishingCatCompletion = Future<void> Function(FishingCatResult result);

enum _FishingRoundPhase { ready, casting, feedback, finishing, complete }

class FishingCatGame extends StatefulWidget {
  final BonusGameSession session;
  final FishingCatCompletion onRoundCompleted;
  final VoidCallback onExit;
  final bool reduceMotion;
  final int? seed;
  final List<List<FishingTarget>>? encounters;
  final Duration castDuration;
  final Duration feedbackDuration;
  final Duration castRecoveryGrace;

  const FishingCatGame({
    super.key,
    required this.session,
    required this.onRoundCompleted,
    required this.onExit,
    required this.reduceMotion,
    this.seed,
    this.encounters,
    this.castDuration = const Duration(milliseconds: 1250),
    this.feedbackDuration = const Duration(milliseconds: 650),
    this.castRecoveryGrace = const Duration(milliseconds: 700),
  });

  @override
  State<FishingCatGame> createState() => _FishingCatGameState();
}

class _FishingCatGameState extends State<FishingCatGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _world;
  late final AnimationController _cast;
  late final List<List<FishingTarget>> _encounters;
  final Map<FishingCatchKind, int> _catches = {};
  int _attempt = 0;
  int _points = 0;
  _FishingRoundPhase _phase = _FishingRoundPhase.ready;
  int _castGeneration = 0;
  double _lastSampledCastValue = 0;
  FishingTarget? _caught;
  FishingCatPose _pose = FishingCatPose.idle;
  String _message = 'Beobachte die Fische und wirf im richtigen Moment aus.';
  FishingCatResult? _result;
  Timer? _feedbackTimer;
  Timer? _castRecoveryTimer;

  double get _worldTime => _world.value * 3600;
  bool get _casting => _phase == _FishingRoundPhase.casting;
  bool get _finishing => _phase == _FishingRoundPhase.finishing;
  bool get _inputLocked => _phase != _FishingRoundPhase.ready;
  String get _buttonLabel => switch (_phase) {
    _FishingRoundPhase.casting => 'ANGEL UNTERWEGS …',
    _FishingRoundPhase.feedback => 'FANG WIRD GEWERTET …',
    _FishingRoundPhase.finishing => 'ERGEBNIS WIRD GESICHERT …',
    _ => 'ANGEL AUSWERFEN',
  };

  double _hookYAt(double castValue) =>
      .18 + sin(pi * castValue.clamp(0, 1)) * .70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final stableSeed =
        widget.seed ??
        widget.session.transactionId.codeUnits.fold<int>(
          17,
          (a, b) => (a * 31 + b) & 0x7fffffff,
        );
    _encounters =
        widget.encounters ?? FishingEncounterFactory.create(seed: stableSeed);
    // A long, non-looping clock keeps every fish path continuous throughout a
    // normal round instead of jumping at the edge of a short repeated cycle.
    _world =
        AnimationController(vsync: this, duration: const Duration(hours: 1))
          ..addListener(_onFrame)
          ..forward();
    _cast = AnimationController(vsync: this, duration: widget.castDuration)
      ..addListener(_onFrame)
      ..addStatusListener(_onCastStatus);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_world.isAnimating && _result == null) _world.forward();
      if (_phase == _FishingRoundPhase.feedback) {
        _advance(_castGeneration);
      }
      return;
    }
    _world.stop();
    _castRecoveryTimer?.cancel();
    if (_casting) {
      _castGeneration++;
      _cast.stop();
      _cast.reset();
      if (mounted) {
        setState(() {
          _phase = _FishingRoundPhase.ready;
          _caught = null;
          _pose = FishingCatPose.alert;
          _message = 'Die Angel wartet sicher auf deine Rückkehr.';
        });
      }
    } else if (_phase == _FishingRoundPhase.feedback) {
      // The attempt is already resolved and must not be scored again. The next
      // round is prepared once the app is visible again.
      _feedbackTimer?.cancel();
    }
  }

  void _onFrame() {
    if (!mounted || _result != null) return;
    if (_casting) {
      _sampleCollision(_lastSampledCastValue, _cast.value);
      _lastSampledCastValue = _cast.value;
    }
  }

  void _sampleCollision(double from, double to) {
    if (_caught != null || to < from) return;
    // Sweep the hook path in small deterministic increments. This prevents a
    // low Safari frame rate from tunnelling through a small fish.
    final steps = max(1, ((to - from) / .018).ceil());
    for (var step = 1; step <= steps; step++) {
      final value = from + (to - from) * step / steps;
      if (value > .58) break;
      final caught = FishingCollision.catchAt(
        hook: Offset(.68, _hookYAt(value)),
        targets: _encounters[_attempt],
        worldTime: _worldTime,
      );
      if (caught != null) {
        setState(() {
          _caught = caught;
          _pose = caught.kind == FishingCatchKind.boot
              ? FishingCatPose.surprise
              : FishingCatPose.pull;
        });
        HapticFeedback.selectionClick();
        return;
      }
    }
  }

  void _castLine() {
    if (_phase != _FishingRoundPhase.ready || _result != null) return;
    _feedbackTimer?.cancel();
    final generation = ++_castGeneration;
    setState(() {
      _phase = _FishingRoundPhase.casting;
      _lastSampledCastValue = 0;
      _caught = null;
      _pose = FishingCatPose.cast;
      _message = 'Surr … die Angel fliegt!';
    });
    HapticFeedback.lightImpact();
    _cast.forward(from: 0);
    _castRecoveryTimer?.cancel();
    _castRecoveryTimer = Timer(
      widget.castDuration + widget.castRecoveryGrace,
      () => _recoverStalledCast(generation),
    );
  }

  void _onCastStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _resolveCast(_castGeneration);
    }
  }

  void _recoverStalledCast(int generation) {
    if (!mounted ||
        _phase != _FishingRoundPhase.casting ||
        generation != _castGeneration) {
      return;
    }
    // This is a guarded completion, not a blind reset: only the still-active
    // cast generation may recover, after its animation deadline was exceeded.
    // The complete hook path is sampled before the attempt is resolved.
    _sampleCollision(_lastSampledCastValue, 1);
    _lastSampledCastValue = 1;
    _resolveCast(generation);
    _cast.stop();
    _cast.value = 1;
  }

  void _resolveCast(int generation) {
    if (!mounted ||
        _phase != _FishingRoundPhase.casting ||
        generation != _castGeneration) {
      return;
    }
    _castRecoveryTimer?.cancel();
    _phase = _FishingRoundPhase.feedback;
    _attempt++;
    final caught = _caught;
    if (caught == null) {
      _pose = FishingCatPose.surprise;
      _message = 'Platsch! Knapp daneben – die Fische kichern leise.';
    } else {
      final points = FishingCatEconomy.pointsFor(caught.kind);
      _points += points;
      _catches[caught.kind] = (_catches[caught.kind] ?? 0) + 1;
      _pose = caught.kind == FishingCatchKind.boot
          ? FishingCatPose.surprise
          : FishingCatPose.success;
      _message = _catchMessage(caught.kind, points);
      HapticFeedback.mediumImpact();
    }
    setState(() {});
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(
      widget.reduceMotion ? Duration.zero : widget.feedbackDuration,
      () => _advance(generation),
    );
  }

  String _catchMessage(FishingCatchKind kind, int points) => switch (kind) {
    FishingCatchKind.boot =>
      'Ein alter Stiefel! Die Katze ist nicht beeindruckt.',
    FishingCatchKind.treasure => 'Schatzkiste! +$points Punkte',
    FishingCatchKind.golden =>
      'Goldfisch! +$points Punkte und extra Schnurren.',
    FishingCatchKind.duck =>
      'Quak statt Fisch! Die Ente spendiert +$points Punkte.',
    _ => 'Gefangen! +$points Punkte',
  };

  void _advance(int generation) {
    if (!mounted ||
        _phase != _FishingRoundPhase.feedback ||
        generation != _castGeneration) {
      return;
    }
    if (_attempt >= FishingCatEconomy.attempts) {
      _finish(skipped: false);
      return;
    }
    _cast.reset();
    setState(() {
      _phase = _FishingRoundPhase.ready;
      _caught = null;
      _pose = FishingCatPose.alert;
      _message = 'Neue Fische nähern sich – Versuch ${_attempt + 1} wartet.';
    });
  }

  Future<void> _finish({required bool skipped}) async {
    if (_finishing ||
        _phase == _FishingRoundPhase.complete ||
        _result != null) {
      return;
    }
    _phase = _FishingRoundPhase.finishing;
    _castGeneration++;
    _feedbackTimer?.cancel();
    _castRecoveryTimer?.cancel();
    _world.stop();
    _cast.stop();
    final result = FishingCatResult(
      attemptsCompleted: _attempt,
      catches: {
        for (final entry in _catches.entries) entry.key.name: entry.value,
      },
      pointsWon: _points,
      coinsWon: FishingCatEconomy.coinsForPoints(_points),
      skipped: skipped,
    );
    await widget.onRoundCompleted(result);
    if (!mounted) return;
    setState(() {
      _result = result;
      _pose = FishingCatPose.celebrate;
      _phase = _FishingRoundPhase.complete;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _castRecoveryTimer?.cancel();
    _world.dispose();
    _cast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Material(
      key: const ValueKey('fishing-cat-game'),
      color: const Color(0xFF081D2B),
      child: SafeArea(
        child: result == null ? _buildGame() : _buildResult(result),
      ),
    );
  }

  Widget _buildGame() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 650;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 20,
          12,
          compact ? 12 : 20,
          14,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FISHING CAT',
                        style: TextStyle(
                          color: Color(0xFFFFE5A0),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'FÜNF WÜRFE · EINE RUHIGE BUCHT',
                        style: TextStyle(
                          color: Color(0xFF9DE6DF),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${min(_attempt + 1, 5)}/5',
                  key: const ValueKey('fishing-attempt'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '$_points P',
                  key: const ValueKey('fishing-points'),
                  style: const TextStyle(
                    color: Color(0xFFFFD76B),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_world, _cast]),
                  builder: (_, __) => FishingScene(
                    targets:
                        _encounters[min(
                          _attempt,
                          FishingCatEconomy.attempts - 1,
                        )],
                    worldTime: _worldTime,
                    castValue: _cast.value,
                    caught: _caught,
                    pose: _pose,
                    reduceMotion: widget.reduceMotion,
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            SizedBox(
              height: compact ? 34 : 42,
              child: Center(
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Color(0xFFDDF9F5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('cast-fishing-line'),
                onPressed: _inputLocked ? null : _castLine,
                icon: const Icon(Icons.water),
                label: Text(_buttonLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE59456),
                  foregroundColor: const Color(0xFF251627),
                  padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('skip-fishing-cat'),
              onPressed: _inputLocked ? null : () => _finish(skipped: true),
              child: const Text(
                'BONUS BEENDEN · PUNKTE BEHALTEN',
                style: TextStyle(color: Color(0xFF9DE6DF), fontSize: 11),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildResult(FishingCatResult result) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF244B58), Color(0xFF18293D)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x88FFE39A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FishingCatSymbol(size: 100),
              const SizedBox(height: 14),
              Text(
                result.skipped ? 'ANGEL EINGEPACKT' : 'FANG DES TAGES',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.pointsWon} Punkte',
                style: const TextStyle(
                  color: Color(0xFFFFD76B),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '+${result.coinsWon} PurrCoins',
                key: const ValueKey('fishing-result-coins'),
                style: const TextStyle(
                  color: Color(0xFF9DE6DF),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('return-from-fishing'),
                  onPressed: widget.onExit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE59456),
                    foregroundColor: const Color(0xFF251627),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'ZURÜCK ZU CAT SLOT',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
