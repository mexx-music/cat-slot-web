import 'dart:math';

import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/bonus_trigger_policy.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  final int value;

  const _FixedRandom(this.value);

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  test('bonus trigger simulation averages about one round per 25 spins', () {
    final policy = BonusTriggerPolicy(random: Random(4242));
    const spins = 200000;
    var bonuses = 0;

    for (var i = 0; i < spins; i++) {
      if (policy.shouldTrigger()) bonuses++;
    }

    final rate = bonuses / spins;
    final averageInterval = spins / bonuses;
    expect(rate, inInclusiveRange(0.038, 0.042));
    expect(averageInterval, inInclusiveRange(23.8, 26.4));
  });

  test(
    'three stable mouse IDs trigger Mouse Hunt without a normal payout',
    () async {
      final controller = CatSlotController(
        random: const _FixedRandom(0),
        bonusTriggerPolicy: BonusTriggerPolicy(probability: 1),
        spinLeadIn: Duration.zero,
        reelStopGap: Duration.zero,
      );

      await controller.spin(() {});

      expect(controller.slots, List.filled(3, kMouseBonusSymbolId));
      expect(controller.pendingBonusGame?.id, kMouseHuntGameId);
      expect(controller.latestWin, 0);
      expect(controller.coins, 9);
    },
  );

  test('bonus reward transaction is credited exactly once', () async {
    final controller = CatSlotController(
      random: const _FixedRandom(0),
      bonusTriggerPolicy: BonusTriggerPolicy(probability: 1),
      spinLeadIn: Duration.zero,
      reelStopGap: Duration.zero,
    );
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;
    const result = BonusGameResult(
      normalCaught: 2,
      goldenCaught: 1,
      coinsWon: 90,
      skipped: false,
    );

    expect(controller.creditBonusOnce(session, result), isTrue);
    expect(controller.creditBonusOnce(session, result), isFalse);
    expect(controller.coins, 99); // 10 - 1 + 90
  });

  test('bonus reward cannot exceed centrally configured catches', () async {
    final controller = CatSlotController(
      random: const _FixedRandom(0),
      bonusTriggerPolicy: BonusTriggerPolicy(probability: 1),
      spinLeadIn: Duration.zero,
      reelStopGap: Duration.zero,
    );
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;

    expect(
      () => controller.creditBonusOnce(
        session,
        const BonusGameResult(
          normalCaught: 1,
          goldenCaught: 0,
          coinsWon: 999,
          skipped: false,
        ),
      ),
      throwsArgumentError,
    );
    expect(controller.coins, 9);
  });

  test('bonus registry IDs are unique and economy remains explicit', () {
    expect(
      kBonusGames.map((game) => game.id).toSet().length,
      kBonusGames.length,
    );
    expect(BonusEconomy.expectedSpinsPerBonus, 25);
    expect(BonusEconomy.normalPayoutPerNonBonusSpin, closeTo(0.232, 0.000001));
    expect(BonusEconomy.normalPayoutPerAllSpins, closeTo(0.22272, 0.000001));
    expect(BonusEconomy.minimumBonusReturnPerSpin, 0.8);
    expect(BonusEconomy.maximumRoundReward, 170);
    expect(BonusEconomy.maximumBonusReturnPerSpin, 6.8);
  });
}
