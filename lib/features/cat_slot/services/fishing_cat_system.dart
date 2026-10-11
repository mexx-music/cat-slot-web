import 'dart:math';
import 'dart:ui';

enum FishingCatchKind { small, colorful, big, golden, boot, treasure, duck }

enum FishingCatPose { idle, alert, cast, pull, success, surprise, celebrate }

class FishingCatEconomy {
  const FishingCatEconomy._();

  static const int attempts = 5;
  static const int pointsPerCoin = 10;
  static const Map<FishingCatchKind, int> points = {
    FishingCatchKind.small: 20,
    FishingCatchKind.colorful: 50,
    FishingCatchKind.big: 100,
    FishingCatchKind.golden: 250,
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

  const FishingTarget({
    required this.id,
    required this.kind,
    required this.startX,
    required this.depth,
    required this.speed,
    required this.size,
    required this.swimsRight,
  });

  Offset positionAt(double worldTime) {
    final signed = swimsRight ? speed : -speed;
    final x = (startX + worldTime * signed) % 1;
    return Offset(x < 0 ? x + 1 : x, depth);
  }
}

class FishingEncounterFactory {
  const FishingEncounterFactory._();

  static List<List<FishingTarget>> create({required int seed}) {
    final random = Random(seed);
    const weightedKinds = [
      FishingCatchKind.small,
      FishingCatchKind.small,
      FishingCatchKind.colorful,
      FishingCatchKind.colorful,
      FishingCatchKind.big,
      FishingCatchKind.boot,
      FishingCatchKind.duck,
      FishingCatchKind.treasure,
      FishingCatchKind.golden,
    ];
    return List.generate(FishingCatEconomy.attempts, (attempt) {
      return List.generate(4, (index) {
        final kind = weightedKinds[random.nextInt(weightedKinds.length)];
        final size = switch (kind) {
          FishingCatchKind.small => .045,
          FishingCatchKind.big => .085,
          FishingCatchKind.golden || FishingCatchKind.treasure => .07,
          _ => .06,
        };
        return FishingTarget(
          id: '$attempt-$index-${kind.name}',
          kind: kind,
          startX: .08 + random.nextDouble() * .84,
          depth: .40 + random.nextDouble() * .46,
          speed: .035 + random.nextDouble() * .075,
          size: size,
          swimsRight: random.nextBool(),
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
