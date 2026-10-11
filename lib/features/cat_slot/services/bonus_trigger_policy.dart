import 'dart:math';

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
