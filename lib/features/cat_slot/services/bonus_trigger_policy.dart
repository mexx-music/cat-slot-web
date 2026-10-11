import 'dart:math';
import 'dart:ui';

class BonusTriggerPolicy {
  final Random _random;
  final double probability;

  BonusTriggerPolicy({
    Random? random,
    this.probability = BonusEconomy.triggerProbability,
  }) : assert(probability >= 0 && probability <= 1),
       _random = random ?? Random();

  bool shouldTrigger() => _random.nextDouble() < probability;
}

class BonusEconomy {
  BonusEconomy._();

  static const double triggerProbability = 0.04;
  static const int participationCoins = 20;
  static const int normalMouseCoins = 10;
  static const int goldenMouseCoins = 50;
  static const int mouseCount = 11;

  static const Duration roundDuration = Duration(seconds: 15);
  static const Duration mouseLifetime = Duration(milliseconds: 1100);
  static const Duration spawnInterval = Duration(milliseconds: 1300);

  static int rewardFor({
    required int normalCaught,
    required int goldenCaught,
  }) =>
      participationCoins +
      normalCaught * normalMouseCoins +
      goldenCaught * goldenMouseCoins;

  static int get maximumRoundReward =>
      participationCoins +
      (mouseCount - 1) * normalMouseCoins +
      goldenMouseCoins;

  static double get expectedSpinsPerBonus => 1 / triggerProbability;

  /// Existing five-cat payout expectation: (3 + 4 + 5 + 7 + 10) / 5³.
  static const double normalPayoutPerNonBonusSpin = 29 / 125;
  static const double normalPayoutPerAllSpins =
      (1 - triggerProbability) * normalPayoutPerNonBonusSpin;
  static const double minimumBonusReturnPerSpin =
      triggerProbability * participationCoins;
  static double get maximumBonusReturnPerSpin =>
      triggerProbability * maximumRoundReward;
}

class MouseHuntDifficulty {
  const MouseHuntDifficulty._();

  static const double firstMouseTravel = .10;
  static const double lastMouseTravel = .36;
  static const double goldenMouseTravel = .46;
  static const double catchRadius = .095;
  static const double goldenCatchRadius = .058;
  static const double impactProgress = .56;

  static double progressForSpawn(int index) =>
      (index / max(1, BonusEconomy.mouseCount - 1)).clamp(0, 1);

  static double travelFor({required int index, required bool golden}) {
    if (golden) return goldenMouseTravel;
    final progress = progressForSpawn(index);
    return firstMouseTravel + (lastMouseTravel - firstMouseTravel) * progress;
  }

  static double catchRadiusFor({required bool golden}) =>
      golden ? goldenCatchRadius : catchRadius;

  static bool isCatch({
    required Offset mousePosition,
    required Offset aimedPosition,
    required bool golden,
  }) =>
      (mousePosition - aimedPosition).distance <=
      catchRadiusFor(golden: golden);
}
