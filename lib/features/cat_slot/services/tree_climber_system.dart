import 'dart:math';

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
  final double baseX;
  final double swayAmplitude;
  final double swaySpeed;
  final double phase;
  final double reachWindow;

  const TreeClimberSection({
    required this.number,
    required this.baseX,
    required this.swayAmplitude,
    required this.swaySpeed,
    required this.phase,
    required this.reachWindow,
  });

  double xAt(double worldSeconds) =>
      (baseX + sin(worldSeconds * swaySpeed + phase) * swayAmplitude).clamp(
        .12,
        .88,
      );
}

class TreeClimberCourse {
  final int seed;
  final List<TreeClimberSection> sections;

  const TreeClimberCourse({required this.seed, required this.sections})
    : assert(sections.length == TreeClimberEconomy.sectionCount);

  factory TreeClimberCourse.generate({required int seed}) {
    final random = Random(seed);
    return TreeClimberCourse(
      seed: seed,
      sections: List.generate(TreeClimberEconomy.sectionCount, (index) {
        final section = index + 1;
        final tier = (index ~/ 2).clamp(0, 4);
        const amplitudes = [0.0, .045, .105, .145, .18];
        const speeds = [0.0, .45, .78, 1.05, 1.30];
        const windows = [.40, .34, .285, .235, .20];
        final side = section.isEven ? -1.0 : 1.0;
        return TreeClimberSection(
          number: section,
          baseX: .5 + side * (.09 + random.nextDouble() * .055),
          swayAmplitude: amplitudes[tier],
          swaySpeed: speeds[tier] * (.9 + random.nextDouble() * .2),
          phase: random.nextDouble() * pi * 2,
          reachWindow: windows[tier],
        );
      }, growable: false),
    );
  }
}

class TreeClimberRules {
  const TreeClimberRules._();

  static bool canReach({
    required double catX,
    required double branchX,
    required double reachWindow,
  }) => (catX - branchX).abs() <= reachWindow;
}
