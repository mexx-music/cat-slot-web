import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bonus_game.dart';
import '../services/tree_climber_system.dart';
import '../widgets/tree_climber_art.dart';

typedef TreeClimberCompletion = Future<void> Function(TreeClimberResult result);

enum _ClimberPhase { ready, jumping, feedback, decision, finishing, complete }

class TreeClimberGame extends StatefulWidget {
  final BonusGameSession session;
  final TreeClimberCompletion onRoundCompleted;
  final VoidCallback onExit;
  final bool reduceMotion;
  final int? seed;
  final TreeClimberCourse? course;
  final Duration jumpDuration;
  final Duration feedbackDuration;
  final Duration recoveryGrace;

  const TreeClimberGame({
    super.key,
    required this.session,
    required this.onRoundCompleted,
    required this.onExit,
    required this.reduceMotion,
    this.seed,
    this.course,
    this.jumpDuration = const Duration(milliseconds: 760),
    this.feedbackDuration = const Duration(milliseconds: 680),
    this.recoveryGrace = const Duration(milliseconds: 600),
  });

  @override
  State<TreeClimberGame> createState() => _TreeClimberGameState();
}

class _TreeClimberGameState extends State<TreeClimberGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _world;
  late final AnimationController _jump;
  late final AnimationController _camera;
  late final TreeClimberCourse _course;
  _ClimberPhase _phase = _ClimberPhase.ready;
  TreeCatPose _pose = TreeCatPose.idle;
  TreeClimberResult? _result;
  Timer? _feedbackTimer;
  Timer? _recoveryTimer;
  int _generation = 0;
  int _sectionsReached = 0;
  double _catX = .5;
  double _sampledTargetX = .5;
  bool _sampledSuccess = false;
  bool _clawSaveUsed = false;
  bool _terminalMiss = false;
  bool _advanceOnResume = false;
  String _message = 'Der erste Ast ist nah. Beobachte ihn und springe!';

  double get _worldSeconds => _world.value * 3600;
  TreeClimberSection get _nextSection =>
      _course.sections[min(_sectionsReached, _course.sections.length - 1)];
  double get _liveTargetX => _phase == _ClimberPhase.jumping
      ? _sampledTargetX
      : _nextSection.xAt(_worldSeconds);
  int get _points => TreeClimberEconomy.pointsForSection(_sectionsReached);
  bool get _inputLocked => _phase != _ClimberPhase.ready;
  Duration get _effectiveJumpDuration =>
      widget.reduceMotion && widget.jumpDuration.inMilliseconds > 180
      ? const Duration(milliseconds: 180)
      : widget.jumpDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final stableSeed =
        widget.seed ??
        widget.session.transactionId.codeUnits.fold<int>(
          29,
          (value, code) => (value * 37 + code) & 0x7fffffff,
        );
    _course = widget.course ?? TreeClimberCourse.generate(seed: stableSeed);
    _world = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..forward();
    _jump = AnimationController(vsync: this, duration: _effectiveJumpDuration)
      ..addStatusListener(_onJumpStatus);
    _camera = AnimationController(
      vsync: this,
      duration: widget.reduceMotion || widget.feedbackDuration == Duration.zero
          ? const Duration(milliseconds: 1)
          : widget.feedbackDuration,
      value: 1,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_world.isAnimating && _result == null) _world.forward();
      if (_advanceOnResume && _phase == _ClimberPhase.feedback) {
        _advanceOnResume = false;
        _camera.value = 1;
        _advance(_generation);
      }
      return;
    }
    _world.stop();
    _camera.stop();
    _recoveryTimer?.cancel();
    if (_phase == _ClimberPhase.jumping) {
      _jump.stop();
      _resolveJump(_generation);
    } else if (_phase == _ClimberPhase.feedback) {
      _feedbackTimer?.cancel();
      _advanceOnResume = true;
    }
  }

  void _beginJump() {
    if (_inputLocked || _result != null) return;
    final generation = ++_generation;
    final target = _nextSection.xAt(_worldSeconds);
    final success = TreeClimberRules.canReach(
      catX: _catX,
      branchX: target,
      reachWindow: _nextSection.reachWindow,
    );
    setState(() {
      _phase = _ClimberPhase.jumping;
      _sampledTargetX = target;
      _sampledSuccess = success;
      _pose = TreeCatPose.jump;
      _message = success
          ? 'Pfoten voran – der Ast ist in Reichweite!'
          : 'Mrrrp … das wird knapp!';
    });
    HapticFeedback.lightImpact();
    _jump.forward(from: 0);
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(
      _effectiveJumpDuration + widget.recoveryGrace,
      () => _recoverJump(generation),
    );
  }

  void _onJumpStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _resolveJump(_generation);
  }

  void _recoverJump(int generation) {
    if (!mounted ||
        _phase != _ClimberPhase.jumping ||
        generation != _generation) {
      return;
    }
    // The outcome was captured from the visible branch at button-down. This
    // guard only completes that same action if a browser drops ticker frames.
    _jump.stop();
    _jump.value = 1;
    _resolveJump(generation);
  }

  void _resolveJump(int generation) {
    if (!mounted ||
        _phase != _ClimberPhase.jumping ||
        generation != _generation) {
      return;
    }
    _recoveryTimer?.cancel();
    _phase = _ClimberPhase.feedback;
    if (_sampledSuccess) {
      _terminalMiss = false;
      _sectionsReached++;
      _catX = _sampledTargetX;
      _pose = _sectionsReached == TreeClimberEconomy.sectionCount
          ? TreeCatPose.celebrate
          : TreeCatPose.land;
      _message = _sectionsReached == TreeClimberEconomy.sectionCount
          ? 'Baumspitze! Da wartet schon eine neue Katzenfreundin.'
          : _landingMessage(_sectionsReached);
      HapticFeedback.mediumImpact();
      if (widget.reduceMotion) {
        _camera.value = 1;
      } else {
        _camera.forward(from: 0);
      }
    } else if (!_clawSaveUsed) {
      _terminalMiss = false;
      _clawSaveUsed = true;
      _pose = TreeCatPose.slip;
      _message = 'Gerade noch festgekrallt! Ein empörter Blick, dann weiter.';
      HapticFeedback.heavyImpact();
    } else {
      _terminalMiss = true;
      _pose = TreeCatPose.slip;
      _message = 'Sanft zurück zum letzten sicheren Ast.';
      HapticFeedback.selectionClick();
    }
    setState(() {});
    _feedbackTimer?.cancel();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      _advanceOnResume = true;
      return;
    }
    _feedbackTimer = Timer(
      widget.reduceMotion ? Duration.zero : widget.feedbackDuration,
      () => _advance(generation),
    );
  }

  String _landingMessage(int section) {
    if (TreeClimberEconomy.isDecisionSection(section)) {
      return 'Sicherer Ast erreicht: $_points Punkte. Sichern oder höher?';
    }
    const reactions = [
      'Saubere Landung – der Schwanz bleibt würdevoll oben.',
      'Pfotengenau! Die Blätter applaudieren leise.',
      'Geschafft. Ein Schmetterling wirkt beeindruckt.',
    ];
    return reactions[(section - 1) % reactions.length];
  }

  void _advance(int generation) {
    if (!mounted ||
        _phase != _ClimberPhase.feedback ||
        generation != _generation) {
      return;
    }
    if (_terminalMiss) {
      _finish(cashedOut: true);
      return;
    }
    if (_sectionsReached >= TreeClimberEconomy.sectionCount) {
      _finish(cashedOut: false);
      return;
    }
    _jump.reset();
    setState(() {
      if (TreeClimberEconomy.isDecisionSection(_sectionsReached) &&
          _sampledSuccess) {
        _phase = _ClimberPhase.decision;
        _pose = TreeCatPose.idle;
      } else {
        _phase = _ClimberPhase.ready;
        _pose = TreeCatPose.ready;
        if (!_sampledSuccess) {
          _message =
              'Die Krallen halten. Versuch ${_sectionsReached + 1} wartet.';
        }
      }
    });
  }

  void _keepClimbing() {
    if (_phase != _ClimberPhase.decision) return;
    setState(() {
      _phase = _ClimberPhase.ready;
      _pose = TreeCatPose.ready;
      _message = 'Mutige Pfoten: Abschnitt ${_sectionsReached + 1} wartet.';
    });
  }

  Future<void> _finish({required bool cashedOut}) async {
    if (_phase == _ClimberPhase.finishing ||
        _phase == _ClimberPhase.complete ||
        _result != null) {
      return;
    }
    _phase = _ClimberPhase.finishing;
    _generation++;
    _feedbackTimer?.cancel();
    _recoveryTimer?.cancel();
    _world.stop();
    _jump.stop();
    _camera.stop();
    final summit = _sectionsReached == TreeClimberEconomy.sectionCount;
    final points = TreeClimberEconomy.pointsForSection(_sectionsReached);
    final result = TreeClimberResult(
      sectionsReached: _sectionsReached,
      pointsWon: points,
      coinsWon: TreeClimberEconomy.coinsFor(
        points: points,
        reachedSummit: summit,
      ),
      reachedSummit: summit,
      cashedOut: cashedOut || !summit,
    );
    await widget.onRoundCompleted(result);
    if (!mounted) return;
    setState(() {
      _result = result;
      _phase = _ClimberPhase.complete;
      _pose = summit ? TreeCatPose.celebrate : TreeCatPose.idle;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _recoveryTimer?.cancel();
    _world.dispose();
    _jump.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Material(
      key: const ValueKey('tree-climber-game'),
      color: const Color(0xFF173A34),
      child: SafeArea(
        child: result == null ? _buildGame() : _buildResult(result),
      ),
    );
  }

  Widget _buildGame() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 650 || constraints.maxWidth < 350;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 18,
          10,
          compact ? 10 : 18,
          10,
        ),
        child: Column(
          children: [
            _header(compact),
            SizedBox(height: compact ? 6 : 10),
            _progressLadder(),
            SizedBox(height: compact ? 6 : 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_world, _jump, _camera]),
                  builder: (_, __) => TreeClimberScene(
                    worldSeconds: _worldSeconds,
                    sectionsReached: _sectionsReached,
                    catX: _catX,
                    targetX: _liveTargetX,
                    jumpProgress: _jump.value,
                    cameraProgress: _camera.value,
                    jumpSuccess: _sampledSuccess,
                    pose: _pose,
                    reduceMotion: widget.reduceMotion,
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            SizedBox(
              height: compact ? 32 : 42,
              child: Center(
                child: Text(
                  _message,
                  key: const ValueKey('tree-message'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Color(0xFFE8FFF4),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (_phase == _ClimberPhase.decision)
              _decisionButtons(compact)
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('tree-jump'),
                  onPressed: _inputLocked ? null : _beginJump,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  label: Text(
                    _phase == _ClimberPhase.jumping
                        ? 'KATZE SPRINGT …'
                        : _phase == _ClimberPhase.feedback
                        ? 'PFOTEN LANDEN …'
                        : 'SPRINGEN',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF2B45F),
                    foregroundColor: const Color(0xFF2B1C24),
                    padding: EdgeInsets.symmetric(vertical: compact ? 11 : 15),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            TextButton(
              key: const ValueKey('skip-tree-climber'),
              onPressed:
                  _phase == _ClimberPhase.ready ||
                      _phase == _ClimberPhase.decision
                  ? () => _finish(cashedOut: true)
                  : null,
              child: const Text(
                'BONUS BEENDEN · SICHEREN STAND WERTEN',
                style: TextStyle(color: Color(0xFFB8E9D4), fontSize: 10),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _header(bool compact) => Row(
    children: [
      const TreeClimberSymbol(size: 42),
      const SizedBox(width: 9),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TREE CLIMBER',
              style: TextStyle(
                color: Color(0xFFFFE5A0),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
            Text(
              'ZEHN ÄSTE · EIN MUTIGES KÄTZCHEN',
              style: TextStyle(
                color: Color(0xFFB8E9D4),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: .9,
              ),
            ),
          ],
        ),
      ),
      Text(
        '$_sectionsReached/10',
        key: const ValueKey('tree-section'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        '$_points P',
        key: const ValueKey('tree-points'),
        style: const TextStyle(
          color: Color(0xFFFFD76B),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );

  Widget _progressLadder() => Row(
    children: [
      for (var i = 1; i <= TreeClimberEconomy.sectionCount; i++) ...[
        Expanded(
          child: AnimatedContainer(
            key: ValueKey('tree-step-$i'),
            duration: widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            height: i <= _sectionsReached ? 8 : 5,
            decoration: BoxDecoration(
              color: i <= _sectionsReached
                  ? const Color(0xFFFFD76B)
                  : const Color(0x554FAF70),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        if (i < TreeClimberEconomy.sectionCount) const SizedBox(width: 3),
      ],
    ],
  );

  Widget _decisionButtons(bool compact) => Row(
    children: [
      Expanded(
        child: FilledButton(
          key: const ValueKey('secure-tree-points'),
          onPressed: () => _finish(cashedOut: true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F8E72),
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
          ),
          child: Text(
            compact ? '$_points SICHERN' : '$_points PUNKTE SICHERN',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          key: const ValueKey('continue-tree-climb'),
          onPressed: _keepClimbing,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF2B45F),
            foregroundColor: const Color(0xFF2B1C24),
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
          ),
          child: const Text(
            'WEITERKLETTERN',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ),
    ],
  );

  Widget _buildResult(TreeClimberResult result) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF315E4E), Color(0xFF172F2D)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x99FFE39A)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 190,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TreeClimberScene(
                    worldSeconds: 0,
                    sectionsReached: result.sectionsReached,
                    catX: .45,
                    targetX: .7,
                    jumpProgress: 1,
                    jumpSuccess: true,
                    pose: result.reachedSummit
                        ? TreeCatPose.celebrate
                        : TreeCatPose.idle,
                    reduceMotion: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                result.reachedSummit
                    ? 'ZWEI KATZEN AN DER SPITZE!'
                    : 'SICHERER AST ERREICHT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 7),
              Text(
                '${result.sectionsReached}/10 Äste · ${result.pointsWon} Punkte',
                style: const TextStyle(
                  color: Color(0xFFFFD76B),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '+${result.coinsWon} PurrCoins',
                key: const ValueKey('tree-result-coins'),
                style: const TextStyle(
                  color: Color(0xFFB8E9D4),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (result.reachedSummit)
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Text(
                    'Inklusive 20 PurrCoins Gipfelbonus',
                    style: TextStyle(color: Color(0xFFD7F7E9), fontSize: 11),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('return-from-tree'),
                  onPressed: widget.onExit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF2B45F),
                    foregroundColor: const Color(0xFF2B1C24),
                    padding: const EdgeInsets.all(15),
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
