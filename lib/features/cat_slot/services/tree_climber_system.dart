import 'dart:math';
import 'dart:ui';

class TreeClimberEconomy {
  const TreeClimberEconomy._();

  static const int sectionCount = 10;
  static const int pointsPerCoin = 10;
  static const int summitBonusCoins = 20;
  static const Map<int, int> checkpointPoints = {
    2: 20,
    4: 50,
    6: 100,
    8: 200,
    10: 400,
  };

  static bool isDecisionSection(int section) =>
      section > 0 &&
      section < sectionCount &&
      checkpointPoints.containsKey(section);

  static int pointsForSection(int section) {
    var points = 0;
    for (final entry in checkpointPoints.entries) {
      if (section >= entry.key) points = entry.value;
    }
    return points;
  }

  static int coinsFor({required int points, required bool reachedSummit}) =>
      max(0, points) ~/ pointsPerCoin + (reachedSummit ? summitBonusCoins : 0);
}

class TreeClimberSymbolPolicy {
  final Random _random;
  final int? _fixedCount;
  final List<int>? _sequence;
  int _sequenceIndex = 0;

  TreeClimberSymbolPolicy({Random? random})
    : _random = random ?? Random(),
      _fixedCount = null,
      _sequence = null;

  TreeClimberSymbolPolicy.fixed(int count)
    : assert(count >= 0 && count <= 9),
      _random = Random(0),
      _fixedCount = count,
      _sequence = null;

  TreeClimberSymbolPolicy.sequence(List<int> counts)
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
    if (roll < .006) return 2;
    if (roll < .030) return 1;
    return 0;
  }

  static const double directBonusProbability = .001;
  static const double expectedCollectorPointsPerSpin = .024 + 2 * .005;
  static const double expectedBonusRoundsPerSpin =
      directBonusProbability + expectedCollectorPointsPerSpin / 3;
}

class TreeClimberSection {
  final int number;
  final double targetX;
  final double heightGain;
  final double branchWidth;

  const TreeClimberSection({
    required this.number,
    required this.targetX,
    required this.heightGain,
    required this.branchWidth,
  });
}

class TreeClimberCourse {
  final int seed;
  final List<TreeClimberSection> sections;

  const TreeClimberCourse({required this.seed, required this.sections})
    : assert(sections.length == TreeClimberEconomy.sectionCount);

  factory TreeClimberCourse.generate({required int seed}) {
    final random = Random(seed);
    const distances = [.20, .23, .27, .30, .33, .36, .39, .42, .45, .48];
    const heights = [.27, .29, .32, .34, .36, .38, .39, .40, .41, .42];
    const widths = [.30, .27, .23, .20, .18, .16, .14, .12, .105, .09];
    var currentX = .5;
    final sections = <TreeClimberSection>[];
    for (var index = 0; index < TreeClimberEconomy.sectionCount; index++) {
      final direction = index.isEven ? 1.0 : -1.0;
      final distance = distances[index] + (random.nextDouble() - .5) * .012;
      final targetX = (currentX + direction * distance).clamp(.10, .90);
      final section = TreeClimberSection(
        number: index + 1,
        targetX: targetX,
        heightGain: heights[index] + (random.nextDouble() - .5) * .008,
        branchWidth: widths[index],
      );
      if (TreeClimberPhysics.findSolution(startX: currentX, section: section) ==
          null) {
        throw StateError(
          'Generated unreachable Tree Climber section ${index + 1}',
        );
      }
      sections.add(section);
      currentX = targetX;
    }
    return TreeClimberCourse(seed: seed, sections: List.unmodifiable(sections));
  }
}

class TreeJumpSettings {
  final double angleDegrees;
  final double powerPercent;

  const TreeJumpSettings({
    required this.angleDegrees,
    required this.powerPercent,
  });
}

class TreeJumpTrajectory {
  final Offset start;
  final Offset velocity;
  final double gravity;
  final double flightTime;
  final double? branchCrossingTime;
  final double impactX;
  final double targetY;
  final bool landsOnBranch;

  const TreeJumpTrajectory({
    required this.start,
    required this.velocity,
    required this.gravity,
    required this.flightTime,
    required this.branchCrossingTime,
    required this.impactX,
    required this.targetY,
    required this.landsOnBranch,
  });

  Offset positionAtTime(double time) => Offset(
    start.dx + velocity.dx * time,
    start.dy + velocity.dy * time + .5 * gravity * time * time,
  );

  Offset positionAtProgress(double progress) =>
      positionAtTime(flightTime * progress.clamp(0, 1));

  List<Offset> previewPoints([int count = 24, double maxProgress = 1]) => [
    for (var i = 0; i < count; i++)
      positionAtProgress(i / max(1, count - 1) * maxProgress.clamp(0, 1)),
  ];
}

class TreeClimberPhysics {
  const TreeClimberPhysics._();

  static const double minAngle = 20;
  static const double maxAngle = 80;
  static const double minPower = 30;
  static const double maxPower = 100;
  static const double gravity = 2.4;
  static const double startY = .72;
  static const List<double> previewFractions = [
    1,
    .92,
    .84,
    .76,
    .68,
    .61,
    .55,
    .49,
    .44,
    .40,
  ];

  static double previewFractionForSection(int section) =>
      previewFractions[(section - 1).clamp(0, previewFractions.length - 1)];

  static bool isPerfectLanding({
    required TreeJumpTrajectory trajectory,
    required TreeClimberSection section,
  }) =>
      trajectory.landsOnBranch &&
      (trajectory.impactX - section.targetX).abs() <=
          min(.012, section.branchWidth * .12);

  static double speedForPower(double powerPercent) =>
      .75 + powerPercent.clamp(minPower, maxPower) * .0095;

  static TreeJumpTrajectory trajectoryFor({
    required double startX,
    required TreeClimberSection section,
    required double angleDegrees,
    required double powerPercent,
  }) {
    final angle = angleDegrees.clamp(minAngle, maxAngle) * pi / 180;
    final speed = speedForPower(powerPercent);
    final direction = section.targetX >= startX ? 1.0 : -1.0;
    final velocity = Offset(
      cos(angle) * speed * direction,
      -sin(angle) * speed,
    );
    final targetY = startY - section.heightGain;
    final discriminant =
        velocity.dy * velocity.dy - 2 * gravity * (startY - targetY);
    double? crossingTime;
    if (discriminant >= 0) {
      crossingTime = (-velocity.dy + sqrt(discriminant)) / gravity;
    }
    final impactX = crossingTime == null
        ? double.nan
        : startX + velocity.dx * crossingTime;
    final lands =
        crossingTime != null &&
        (impactX - section.targetX).abs() <= section.branchWidth / 2;
    final returnTime = max(.35, -2 * velocity.dy / gravity);
    final flightTime = lands
        ? crossingTime
        : crossingTime == null
        ? returnTime
        : min(returnTime, crossingTime + .26);
    return TreeJumpTrajectory(
      start: Offset(startX, startY),
      velocity: velocity,
      gravity: gravity,
      flightTime: flightTime,
      branchCrossingTime: crossingTime,
      impactX: impactX,
      targetY: targetY,
      landsOnBranch: lands,
    );
  }

  static TreeJumpSettings? findSolution({
    required double startX,
    required TreeClimberSection section,
  }) {
    TreeJumpSettings? best;
    var bestScore = double.infinity;
    for (var power = minPower.toInt(); power <= maxPower; power++) {
      for (var angle = minAngle.toInt(); angle <= maxAngle; angle++) {
        final trajectory = trajectoryFor(
          startX: startX,
          section: section,
          angleDegrees: angle.toDouble(),
          powerPercent: power.toDouble(),
        );
        if (!trajectory.landsOnBranch) continue;
        final score =
            (trajectory.impactX - section.targetX).abs() * 100 +
            (angle - 60).abs() * .01 +
            (power - 75).abs() * .005;
        if (score < bestScore) {
          bestScore = score;
          best = TreeJumpSettings(
            angleDegrees: angle.toDouble(),
            powerPercent: power.toDouble(),
          );
        }
      }
    }
    return best;
  }
}
