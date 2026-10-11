import 'dart:math';
import 'dart:ui';

enum FishingCatchKind {
  small,
  colorful,
  big,
  swift,
  golden,
  boot,
  treasure,
  duck,
}

enum FishingCatPose { idle, alert, cast, pull, success, surprise, celebrate }

class FishingCatEconomy {
  const FishingCatEconomy._();

  static const int attempts = 5;
  static const int pointsPerCoin = 10;
  static const Map<FishingCatchKind, int> points = {
    FishingCatchKind.small: 10,
    FishingCatchKind.colorful: 30,
    FishingCatchKind.big: 100,
    FishingCatchKind.swift: 200,
    FishingCatchKind.golden: 500,
    FishingCatchKind.boot: 0,
    FishingCatchKind.treasure: 150,
    FishingCatchKind.duck: 10,
  };

  static int pointsFor(FishingCatchKind kind) => points[kind]!;
  static int coinsForPoints(int points) => max(0, points) ~/ pointsPerCoin;
}

class FishingCatSymbolPolicy {
  final Random _random;
  final int? _fixedCount;
  final List<int>? _sequence;
  int _sequenceIndex = 0;

  FishingCatSymbolPolicy({Random? random})
    : _random = random ?? Random(),
      _fixedCount = null,
      _sequence = null;

  FishingCatSymbolPolicy.fixed(int count)
    : assert(count >= 0 && count <= 9),
      _random = Random(0),
      _fixedCount = count,
      _sequence = null;

  FishingCatSymbolPolicy.sequence(List<int> counts)
    : assert(counts.isNotEmpty),
      assert(counts.every((count) => count >= 0 && count <= 9)),
      _random = Random(0),
      _fixedCount = null,
      _sequence = List.unmodifiable(counts);

  int visibleCount() {
    if (_fixedCount case final count?) return count;
    if (_sequence case final sequence?) {
      final count = sequence[_sequenceIndex % sequence.length];
      _sequenceIndex++;
      return count;
    }
    final roll = _random.nextDouble();
    if (roll < directBonusProbability) return 3;
    if (roll < 0.010) return 2;
    if (roll < 0.040) return 1;
    return 0;
  }

  static const double directBonusProbability = 0.002;
  static const double expectedCollectorPointsPerSpin = 0.030 + 2 * 0.008;
  static const double expectedBonusRoundsPerSpin =
      directBonusProbability + expectedCollectorPointsPerSpin / 3;
}

class FishingTarget {
  final String id;
  final FishingCatchKind kind;
  final double startX;
  final double depth;
  final double speed;
  final double size;
  final bool swimsRight;
  final double depthDrift;
  final double depthSpeed;
  final double appearancePhase;
  final double visibleFraction;

  const FishingTarget({
    required this.id,
    required this.kind,
    required this.startX,
    required this.depth,
    required this.speed,
    required this.size,
    required this.swimsRight,
    this.depthDrift = 0,
    this.depthSpeed = 0,
    this.appearancePhase = 0,
    this.visibleFraction = 1,
  });

  Offset positionAt(double worldTime) {
    final signed = swimsRight ? speed : -speed;
    final phase = (startX + worldTime * signed) % 2;
    final x = phase <= 1 ? phase : 2 - phase;
    final y =
        (depth +
                sin(worldTime * depthSpeed + appearancePhase * pi * 2) *
                    depthDrift)
            .clamp(.36, .90);
    return Offset(x, y);
  }

  bool movesRightAt(double worldTime) {
    final signed = swimsRight ? speed : -speed;
    final phase = (startX + worldTime * signed) % 2;
    final reflectedDirection = phase <= 1 ? signed : -signed;
    return reflectedDirection >= 0;
  }

  bool visibleAt(double worldTime) {
    if (visibleFraction >= 1) return true;
    final phase = (worldTime * .35 + appearancePhase) % 1;
    return phase < visibleFraction;
  }
}

class FishingEncounterFactory {
  const FishingEncounterFactory._();

  static List<List<FishingTarget>> create({required int seed}) {
    final random = Random(seed);
    const weightedKinds = [
      FishingCatchKind.small,
      FishingCatchKind.small,
      FishingCatchKind.small,
      FishingCatchKind.colorful,
      FishingCatchKind.colorful,
      FishingCatchKind.colorful,
      FishingCatchKind.big,
      FishingCatchKind.big,
      FishingCatchKind.swift,
      FishingCatchKind.boot,
      FishingCatchKind.duck,
      FishingCatchKind.treasure,
    ];
    final goldenSlot = random.nextInt(FishingCatEconomy.attempts * 4);
    return List.generate(FishingCatEconomy.attempts, (attempt) {
      return List.generate(4, (index) {
        final slot = attempt * 4 + index;
        final kind = slot == goldenSlot
            ? FishingCatchKind.golden
            : weightedKinds[random.nextInt(weightedKinds.length)];
        final size = switch (kind) {
          FishingCatchKind.small || FishingCatchKind.swift => .045,
          FishingCatchKind.big => .085,
          FishingCatchKind.golden => .052,
          FishingCatchKind.treasure => .07,
          _ => .06,
        };
        final speed = switch (kind) {
          FishingCatchKind.small => .055 + random.nextDouble() * .035,
          FishingCatchKind.colorful => .095 + random.nextDouble() * .045,
          FishingCatchKind.big => .145 + random.nextDouble() * .055,
          FishingCatchKind.swift => .21 + random.nextDouble() * .06,
          FishingCatchKind.golden => .25 + random.nextDouble() * .07,
          FishingCatchKind.boot => .04 + random.nextDouble() * .025,
          FishingCatchKind.treasure => .07 + random.nextDouble() * .035,
          FishingCatchKind.duck => .08 + random.nextDouble() * .04,
        };
        final changesDepth = switch (kind) {
          FishingCatchKind.colorful ||
          FishingCatchKind.big ||
          FishingCatchKind.swift ||
          FishingCatchKind.golden => true,
          _ => false,
        };
        return FishingTarget(
          id: '$attempt-$index-${kind.name}',
          kind: kind,
          startX: .08 + random.nextDouble() * .84,
          depth: .40 + random.nextDouble() * .46,
          speed: speed,
          size: size,
          swimsRight: random.nextBool(),
          depthDrift: changesDepth ? .018 + random.nextDouble() * .045 : 0,
          depthSpeed: changesDepth ? .75 + random.nextDouble() * .8 : 0,
          appearancePhase: random.nextDouble(),
          visibleFraction: kind == FishingCatchKind.golden ? .32 : 1,
        );
      });
    });
  }
}

class FishingCollision {
  const FishingCollision._();

  static FishingTarget? catchAt({
    required Offset hook,
    required List<FishingTarget> targets,
    required double worldTime,
  }) {
    FishingTarget? closest;
    var closestDistance = double.infinity;
    for (final target in targets) {
      if (!target.visibleAt(worldTime)) continue;
      final position = target.positionAt(worldTime);
      final dx = (position.dx - hook.dx).abs();
      final dy = (position.dy - hook.dy).abs();
      if (dx <= target.size * 1.15 && dy <= target.size * .85) {
        final distance = dx * dx + dy * dy;
        if (distance < closestDistance) {
          closest = target;
          closestDistance = distance;
        }
      }
    }
    return closest;
  }
}
