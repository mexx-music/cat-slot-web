import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bonus_game.dart';
import '../services/bonus_trigger_policy.dart';
import '../widgets/hunt_cat.dart';
import '../widgets/mouse_art.dart';

class MouseHuntGame extends StatefulWidget {
  final BonusGameSession session;
  final ValueChanged<BonusGameResult> onRoundCompleted;
  final VoidCallback onExit;
  final bool reduceMotion;
  final Random? random;
  final Duration roundDuration;
  final Duration spawnInterval;
  final Duration mouseLifetime;
  final String hunterSetId;

  const MouseHuntGame({
    super.key,
    required this.session,
    required this.onRoundCompleted,
    required this.onExit,
    this.reduceMotion = false,
    this.random,
    this.roundDuration = BonusEconomy.roundDuration,
    this.spawnInterval = BonusEconomy.spawnInterval,
    this.mouseLifetime = BonusEconomy.mouseLifetime,
    this.hunterSetId = 'standard',
  });

  @override
  State<MouseHuntGame> createState() => _MouseHuntGameState();
}

class _MouseHuntGameState extends State<MouseHuntGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Random _random;
  late final AnimationController _roundController;
  late final AnimationController _mouseController;
  late final AnimationController _hitController;
  late final AnimationController _idleController;
  late final AnimationController _huntController;
  late final HunterCatAppearance _hunterAppearance;

  Timer? _spawnTimer;
  Timer? _mouseLifeTimer;
  _MouseTarget? _mouse;
  Size _sceneSize = Size.zero;
  Offset _hitPosition = Offset.zero;
  Offset _huntTarget = const Offset(0.5, 0.48);
  int _spawned = 0;
  int _normalCaught = 0;
  int _goldenCaught = 0;
  int _misses = 0;
  late final int _goldenIndex;
  bool _roundFinished = false;
  bool _completionSent = false;
  bool _huntInProgress = false;
  bool _huntWillCatch = false;
  bool _catchResolved = false;
  bool _lastHuntCaught = false;
  HuntCatState _restingCatState = HuntCatState.idle;
  _MouseTarget? _huntedMouse;
  BonusGameResult? _result;
  String _catReaction = 'Leise Pfoten … die Mäuse kommen gleich.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _random = widget.random ?? Random();
    _hunterAppearance = HunterCatAppearance.forSymbolSetId(widget.hunterSetId);
    _goldenIndex = 3 + _random.nextInt(5);
    _roundController =
        AnimationController(vsync: this, duration: widget.roundDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finishRound();
          });
    _mouseController = AnimationController(
      vsync: this,
      duration: widget.mouseLifetime,
    );
    _hitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _huntController =
        AnimationController(
            vsync: this,
            duration: widget.reduceMotion
                ? const Duration(milliseconds: 1)
                : const Duration(milliseconds: 860),
          )
          ..addListener(_advanceHunt)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _completeHunt();
          });

    if (!widget.reduceMotion) _idleController.repeat();

    _roundController.forward();
    _scheduleSpawn(
      widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_roundFinished) {
      _finishRound(skipped: true);
    }
  }

  void _scheduleSpawn(Duration delay) {
    _spawnTimer?.cancel();
    if (_roundFinished || _spawned >= BonusEconomy.mouseCount) return;
    _spawnTimer = Timer(delay, _spawnMouse);
  }

  void _spawnMouse() {
    if (!mounted || _roundFinished || _spawned >= BonusEconomy.mouseCount) {
      return;
    }
    _mouseLifeTimer?.cancel();
    final start = Offset(
      0.10 + _random.nextDouble() * 0.72,
      0.12 + _random.nextDouble() * 0.62,
    );
    final drift = Offset(
      (_random.nextDouble() - 0.5) * 0.20,
      (_random.nextDouble() - 0.5) * 0.14,
    );
    final end = Offset(
      (start.dx + drift.dx).clamp(0.08, 0.86),
      (start.dy + drift.dy).clamp(0.10, 0.78),
    );
    final target = _MouseTarget(
      index: _spawned,
      golden: _spawned == _goldenIndex,
      start: start,
      end: widget.reduceMotion ? start : end,
    );
    _spawned++;
    setState(() {
      _mouse = target;
      _restingCatState = HuntCatState.alert;
      _catReaction = target.golden
          ? 'Goldenes Rascheln! Die besondere Maus ist da.'
          : 'Da wackeln Schnurrhaare im Versteck …';
    });
    if (widget.reduceMotion) {
      _mouseController.value = 1;
    } else {
      _mouseController.forward(from: 0);
    }
    _mouseLifeTimer = Timer(widget.mouseLifetime, _mouseEscaped);
    _scheduleSpawn(widget.spawnInterval);
  }

  void _mouseEscaped() {
    if (!mounted || _roundFinished || _mouse == null || _huntInProgress) return;
    setState(() {
      _mouse = null;
      _restingCatState = HuntCatState.miss;
      _catReaction = 'Flitz! Diese Maus kennt den geheimen Tunnel.';
    });
    _scheduleSpawn(_betweenMouseDelay);
  }

  void _catchMouse() {
    final caught = _mouse;
    if (caught == null || _roundFinished || _huntInProgress) return;
    final current = Offset.lerp(
      caught.start,
      caught.end,
      widget.reduceMotion
          ? 0
          : Curves.easeInOut.transform(_mouseController.value),
    )!;
    _startHunt(target: current, caught: caught);
  }

  void _missedTap(TapUpDetails details) {
    if (_roundFinished || _huntInProgress || _sceneSize.isEmpty) return;
    _misses++;
    final target = Offset(
      (details.localPosition.dx / _sceneSize.width).clamp(0.08, 0.92),
      (details.localPosition.dy / _sceneSize.height).clamp(0.14, 0.68),
    );
    _startHunt(target: target);
  }

  Duration get _betweenMouseDelay {
    final difference = widget.spawnInterval - widget.mouseLifetime;
    if (difference.isNegative) return Duration.zero;
    return difference;
  }

  void _startHunt({required Offset target, _MouseTarget? caught}) {
    if (_huntInProgress || _roundFinished) return;
    _spawnTimer?.cancel();
    _mouseLifeTimer?.cancel();
    _mouseController.stop();
    _huntTarget = Offset(target.dx, min(target.dy + 0.06, 0.70));
    _huntedMouse = caught;
    _huntWillCatch = caught != null;
    _lastHuntCaught = false;
    _catchResolved = false;
    _huntInProgress = true;
    HapticFeedback.selectionClick();
    setState(() {
      _catReaction = caught == null
          ? 'Volle Pfote voraus … war da wirklich eine Maus?'
          : caught.golden
          ? 'Goldblick fixiert. Jetzt ganz leise …'
          : 'Ziel erfasst. Schnurrhaare nach vorn!';
    });
    _huntController.forward(from: 0);
  }

  void _advanceHunt() {
    if (!_huntInProgress || _catchResolved || _huntController.value < 0.56) {
      return;
    }
    _resolveHuntOutcome();
  }

  void _resolveHuntOutcome() {
    if (_catchResolved) return;
    _catchResolved = true;
    if (!mounted || _roundFinished) return;
    final caught = _huntedMouse;
    if (_huntWillCatch && caught != null) {
      _lastHuntCaught = true;
      _hitPosition = Offset(
        _huntTarget.dx * _sceneSize.width,
        _huntTarget.dy * _sceneSize.height,
      );
      if (caught.golden) {
        _goldenCaught++;
        HapticFeedback.mediumImpact();
      } else {
        _normalCaught++;
        HapticFeedback.lightImpact();
      }
      setState(() {
        _mouse = null;
        _catReaction = caught.golden
            ? 'Goldpfote! Funkelnde Beute gesichert.'
            : 'Patsch! Sauber gefangen und würdevoll geschnurrt.';
      });
      if (!widget.reduceMotion) _hitController.forward(from: 0);
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _mouse = null;
        _catReaction = _misses.isEven
            ? 'Nur ein Staubmäuschen. Die Katze tut ganz gelassen.'
            : 'Patsch daneben – die Maus kichert aus dem Versteck.';
      });
    }
  }

  void _completeHunt() {
    if (!_huntInProgress) return;
    if (!_catchResolved) _advanceHunt();
    _huntInProgress = false;
    _huntedMouse = null;
    if (!mounted || _roundFinished) return;
    setState(() {
      _restingCatState = _lastHuntCaught
          ? HuntCatState.celebrate
          : HuntCatState.miss;
    });
    _scheduleSpawn(widget.reduceMotion ? Duration.zero : _betweenMouseDelay);
  }

  void _finishRound({bool skipped = false}) {
    if (_roundFinished) return;
    // A correctly tapped mouse is already secured even when Skip or an app
    // interruption arrives during the short visual pounce.
    if (_huntInProgress && _huntWillCatch && !_catchResolved) {
      _resolveHuntOutcome();
    }
    _roundFinished = true;
    _spawnTimer?.cancel();
    _mouseLifeTimer?.cancel();
    _roundController.stop();
    _mouseController.stop();
    _huntController.stop();
    _idleController.stop();
    final result = BonusGameResult(
      normalCaught: _normalCaught,
      goldenCaught: _goldenCaught,
      coinsWon: BonusEconomy.rewardFor(
        normalCaught: _normalCaught,
        goldenCaught: _goldenCaught,
      ),
      skipped: skipped,
    );
    _result = result;
    if (!_completionSent) {
      _completionSent = true;
      widget.onRoundCompleted(result);
    }
    if (mounted) {
      setState(() {
        _mouse = null;
        _catReaction = skipped
            ? 'Abgekürzt, aber jeder Fang bleibt deiner.'
            : 'Zeit! Die Mäuse ziehen sich zur Teepause zurück.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spawnTimer?.cancel();
    _mouseLifeTimer?.cancel();
    _roundController.dispose();
    _mouseController.dispose();
    _hitController.dispose();
    _idleController.dispose();
    _huntController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Material(
      key: const ValueKey('mouse-hunt-game'),
      color: const Color(0xFF0E091D),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 390 ? 10 : 18,
              ),
              child: _roundFinished ? _buildResult() : _buildGame(),
            ),
          ),
        ),
      ),
    );
    if (widget.reduceMotion) return content;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: content,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.985 + value * 0.015, child: child),
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _sceneSize = constraints.biggest;
              return RepaintBoundary(
                child: GestureDetector(
                  key: const ValueKey('mouse-hunt-scene'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _missedTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        const Positioned.fill(child: _MouseHuntScene()),
                        if (_mouse case final target?)
                          AnimatedBuilder(
                            animation: _mouseController,
                            builder: (_, __) {
                              final t = widget.reduceMotion
                                  ? 0.0
                                  : Curves.easeInOut.transform(
                                      _mouseController.value,
                                    );
                              final position = Offset.lerp(
                                target.start,
                                target.end,
                                t,
                              )!;
                              final targetSize = target.golden ? 84.0 : 74.0;
                              return Positioned(
                                left:
                                    position.dx * constraints.maxWidth -
                                    targetSize / 2,
                                top:
                                    position.dy * constraints.maxHeight -
                                    targetSize / 2,
                                child: GestureDetector(
                                  key: ValueKey('mouse-target-${target.index}'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _catchMouse,
                                  child: SizedBox.square(
                                    dimension: targetSize,
                                    child: Center(
                                      child: CozyMouse(
                                        golden: target.golden,
                                        size: target.golden ? 74 : 64,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (!widget.reduceMotion)
                          AnimatedBuilder(
                            animation: _huntController,
                            builder: (_, __) => Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _PounceDustPainter(
                                    progress: _huntController.value,
                                    target: _huntTarget,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _buildHunter(constraints),
                        if (!widget.reduceMotion)
                          AnimatedBuilder(
                            animation: _hitController,
                            builder: (_, __) => Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _PawHitPainter(
                                    center: _hitPosition,
                                    progress: _hitController.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 12,
                          child: IgnorePointer(
                            child: _CatReaction(message: _catReaction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHunter(BoxConstraints constraints) {
    return AnimatedBuilder(
      animation: Listenable.merge([_huntController, _idleController]),
      builder: (context, _) {
        final state = _currentCatState;
        final position = _currentCatPosition;
        final catSize = constraints.maxWidth < 390 ? 96.0 : 118.0;
        return Positioned(
          left: position.dx * constraints.maxWidth - catSize / 2,
          top: position.dy * constraints.maxHeight - catSize * 0.62,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: HuntCat(
                state: state,
                appearance: _hunterAppearance,
                phase: _huntController.value,
                idlePhase: _idleController.value,
                facingRight: _huntTarget.dx >= 0.5,
                size: catSize,
              ),
            ),
          ),
        );
      },
    );
  }

  HuntCatState get _currentCatState {
    if (!_huntInProgress) return _restingCatState;
    final t = _huntController.value;
    if (t < 0.16) return HuntCatState.alert;
    if (t < 0.56) return HuntCatState.pounce;
    if (t < 0.73) {
      return _huntWillCatch ? HuntCatState.catching : HuntCatState.miss;
    }
    if (t < 0.91) return HuntCatState.pounce;
    return _huntWillCatch ? HuntCatState.celebrate : HuntCatState.miss;
  }

  Offset get _currentCatPosition {
    const home = Offset(0.5, 0.84);
    if (!_huntInProgress || widget.reduceMotion) return home;
    final t = _huntController.value;
    if (t < 0.16) {
      final prepare = Curves.easeIn.transform(t / 0.16);
      return home +
          Offset((_huntTarget.dx - home.dx) * prepare * 0.04, 0.025 * prepare);
    }
    if (t < 0.56) {
      final travel = Curves.easeOutCubic.transform((t - 0.16) / 0.40);
      final direct = Offset.lerp(home, _huntTarget, travel)!;
      return direct - Offset(0, sin(travel * pi) * 0.20);
    }
    if (t < 0.73) {
      final catchPhase = (t - 0.56) / 0.17;
      return _huntTarget + Offset(sin(catchPhase * pi * 2) * 0.008, 0);
    }
    if (t < 0.91) {
      final returning = Curves.easeInOutCubic.transform((t - 0.73) / 0.18);
      final direct = Offset.lerp(_huntTarget, home, returning)!;
      return direct - Offset(0, sin(returning * pi) * 0.10);
    }
    final landing = (t - 0.91) / 0.09;
    return home + Offset(0, sin(landing * pi) * 0.018);
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xDD24163A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x668CE4DC)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 14,
              vertical: compact ? 7 : 10,
            ),
            child: Row(
              children: [
                Text('🐱', style: TextStyle(fontSize: compact ? 22 : 28)),
                SizedBox(width: compact ? 6 : 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOUSE HUNT',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: compact ? 0.8 : 1.5,
                        ),
                      ),
                      if (!compact)
                        const Text(
                          'Tippe auf die Mäuse',
                          style: TextStyle(
                            color: Color(0xFF9FE7E0),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _roundController,
                  builder: (_, __) {
                    final seconds =
                        (widget.roundDuration.inMilliseconds *
                                (1 - _roundController.value) /
                                1000)
                            .ceil()
                            .clamp(0, 99);
                    return _ScorePill(
                      label: '$seconds s',
                      icon: '⏱',
                      compact: compact,
                    );
                  },
                ),
                SizedBox(width: compact ? 4 : 7),
                _ScorePill(
                  label: '${_normalCaught + _goldenCaught}',
                  icon: '🐭',
                  compact: compact,
                ),
                SizedBox(width: compact ? 2 : 7),
                if (compact)
                  IconButton(
                    key: const ValueKey('skip-mouse-hunt'),
                    tooltip: 'Überspringen',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _finishRound(skipped: true),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                else
                  TextButton(
                    key: const ValueKey('skip-mouse-hunt'),
                    onPressed: () => _finishRound(skipped: true),
                    child: const Text('ÜBERSPRINGEN'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          key: const ValueKey('mouse-hunt-result'),
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF342052), Color(0xFF17102B)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xAA8CE4DC)),
            boxShadow: const [
              BoxShadow(color: Color(0x5543D6CB), blurRadius: 40),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CozyMouse(golden: true, size: 88),
              const SizedBox(height: 8),
              Text(
                result.skipped ? 'BEUTE GESICHERT' : 'JAGD BEENDET',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.normalCaught} Mäuse · ${result.goldenCaught} goldene Maus',
                style: const TextStyle(color: Color(0xFFB8DDD9)),
              ),
              const SizedBox(height: 18),
              Text(
                '+${result.coinsWon}',
                key: const ValueKey('mouse-hunt-reward'),
                style: const TextStyle(
                  color: Color(0xFFFFE79A),
                  fontSize: 58,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Color(0x99F4D77C), blurRadius: 22)],
                ),
              ),
              const Text(
                'PURRCOINS',
                style: TextStyle(
                  color: Color(0xFFD9C475),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'inklusive 20 PurrCoins Teilnahmebonus',
                style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('return-to-slot'),
                  onPressed: widget.onExit,
                  icon: const Text('🐾'),
                  label: const Text('ZURÜCK ZUM SLOT'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1D77A),
                    foregroundColor: const Color(0xFF211333),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MouseTarget {
  final int index;
  final bool golden;
  final Offset start;
  final Offset end;

  const _MouseTarget({
    required this.index,
    required this.golden,
    required this.start,
    required this.end,
  });
}

class _ScorePill extends StatelessWidget {
  final String label;
  final String icon;
  final bool compact;

  const _ScorePill({
    required this.label,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0x66100A20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(fontSize: compact ? 10 : 12),
      ),
    );
  }
}

class _CatReaction extends StatelessWidget {
  final String message;

  const _CatReaction({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD170F29),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x556BD8D0)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🐱', style: TextStyle(fontSize: 19)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD6F2EF),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MouseHuntScene extends StatelessWidget {
  const _MouseHuntScene();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF213C49), Color(0xFF17273A), Color(0xFF2B183D)],
        ),
      ),
      child: CustomPaint(painter: _RoomPainter()),
    );
  }
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final moon = Paint()..color = const Color(0x33FFF1B5);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 58, moon);

    final windowFrame = Paint()
      ..color = const Color(0x665F9C9A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.18),
        width: 128,
        height: 112,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(window, windowFrame);
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.08),
      Offset(size.width * 0.82, size.height * 0.28),
      windowFrame,
    );

    final shelf = Paint()..color = const Color(0x775B3C62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.07, size.height * 0.25, 112, 9),
        const Radius.circular(5),
      ),
      shelf,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.09 + i * 28,
            size.height * 0.19 - i * 3,
            21,
            size.height * 0.06 + i * 3,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0x6675C7BE),
      );
    }

    final floor = Paint()..color = const Color(0x33201432);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      floor,
    );
    final line = Paint()
      ..color = const Color(0x224FD7CD)
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.74 + i * 0.04);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.84),
        width: min(size.width * 0.58, 370),
        height: min(size.height * 0.20, 120),
      ),
      Paint()..color = const Color(0x3343D6CB),
    );

    final holePaint = Paint()..color = const Color(0xCC100B18);
    for (final position in [
      Offset(size.width * 0.08, size.height * 0.68),
      Offset(size.width * 0.91, size.height * 0.62),
    ]) {
      canvas.drawArc(
        Rect.fromCenter(center: position, width: 64, height: 50),
        pi,
        pi,
        true,
        holePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: position, width: 68, height: 54),
        pi,
        pi,
        false,
        Paint()
          ..color = const Color(0x5575D9D0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final cushion = Paint()..color = const Color(0x557A4C82);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.07, size.height * 0.58, 95, 44),
        const Radius.circular(22),
      ),
      cushion,
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.70),
      34,
      Paint()..color = const Color(0x44E4A65E),
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.70),
      17,
      Paint()
        ..color = const Color(0x555E3A68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PounceDustPainter extends CustomPainter {
  final double progress;
  final Offset target;

  const _PounceDustPainter({required this.progress, required this.target});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final launch = progress < 0.28;
    final landing = progress > 0.82;
    if (!launch && !landing) return;
    final local = launch ? progress / 0.28 : (progress - 0.82) / 0.18;
    final center = launch
        ? Offset(size.width * 0.5, size.height * 0.86)
        : Offset(size.width * target.dx, size.height * target.dy);
    final opacity = sin(local.clamp(0.0, 1.0) * pi) * 0.48;
    final paint = Paint()
      ..color = const Color(0xFFFFE6B0).withValues(alpha: opacity);
    for (var i = 0; i < 5; i++) {
      final direction = i.isEven ? -1.0 : 1.0;
      final distance = 12 + local * (18 + i * 5);
      canvas.drawCircle(
        center + Offset(direction * distance, -local * (8 + i * 2)),
        2.5 + (1 - local) * 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PounceDustPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.target != target;
}

class _PawHitPainter extends CustomPainter {
  final Offset center;
  final double progress;

  const _PawHitPainter({required this.center, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || center == Offset.zero) return;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFFFFE79A).withValues(alpha: opacity * 0.8);
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final distance = 12 + progress * 34;
      canvas.drawCircle(
        center + Offset(cos(angle), sin(angle)) * distance,
        2.5 + (1 - progress) * 2,
        paint,
      );
    }
    canvas.drawCircle(
      center,
      10 + progress * 10,
      Paint()
        ..color = const Color(0xFF8CE4DC).withValues(alpha: opacity * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PawHitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.center != center;
}
