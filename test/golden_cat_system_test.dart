import 'dart:math';

import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/bonus_trigger_policy.dart';
import 'package:catslot/features/cat_slot/services/golden_cat_system.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  const _FixedRandom();

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;
}

CatSlotController _controller({
  required GoldenCatSymbolPolicy policy,
  BonusProgressStore? progressStore,
  WalletStore? walletStore,
  double mouseProbability = 0,
}) => CatSlotController(
  random: const _FixedRandom(),
  bonusTriggerPolicy: BonusTriggerPolicy(probability: mouseProbability),
  goldenCatPolicy: policy,
  progressStore: progressStore,
  walletStore: walletStore,
  spinLeadIn: Duration.zero,
  reelStopGap: Duration.zero,
);

void main() {
  test('counts golden cats across rows, diagonals and distributed cells', () {
    const row = [
      [kGoldenCatBonusSymbolId, 'a', 'b'],
      [kGoldenCatBonusSymbolId, 'c', 'd'],
      [kGoldenCatBonusSymbolId, 'e', 'f'],
    ];
    const diagonal = [
      [kGoldenCatBonusSymbolId, 'a', 'b'],
      ['c', kGoldenCatBonusSymbolId, 'd'],
      ['e', 'f', kGoldenCatBonusSymbolId],
    ];
    const distributed = [
      ['a', 'b', kGoldenCatBonusSymbolId],
      [kGoldenCatBonusSymbolId, 'c', 'd'],
      ['e', kGoldenCatBonusSymbolId, 'f'],
    ];

    for (final reels in [row, diagonal, distributed]) {
      expect(VisibleBonusCounter.count(reels, kGoldenCatBonusSymbolId), 3);
    }
  });

  test('collects symbols over spins and persists the remainder', () async {
    final store = MemoryBonusProgressStore();
    final controller = _controller(
      policy: GoldenCatSymbolPolicy.sequence([1, 1, 2]),
      progressStore: store,
    );

    await controller.spin(() {});
    expect(controller.goldenCatProgress, 1);
    await controller.spin(() {});
    expect(controller.goldenCatProgress, 2);
    await controller.spin(() {});

    expect(controller.pendingBonusGame?.id, kGoldenCatGameId);
    expect(controller.goldenCatProgress, 1);
    expect(store.value, 1);
  });

  test('collector and wallet survive a controller restart', () async {
    final progress = MemoryBonusProgressStore();
    final wallet = MemoryWalletStore();
    final first = _controller(
      policy: GoldenCatSymbolPolicy.fixed(1),
      progressStore: progress,
      walletStore: wallet,
    );
    await first.spin(() {});

    final restarted = _controller(
      policy: GoldenCatSymbolPolicy.fixed(0),
      progressStore: progress,
      walletStore: wallet,
    );
    await restarted.initialize();

    expect(restarted.goldenCatProgress, 1);
    expect(restarted.coins, first.coins);
  });

  test(
    'direct trigger neither consumes nor duplicates collector progress',
    () async {
      final progress = MemoryBonusProgressStore(2);
      final controller = _controller(
        policy: GoldenCatSymbolPolicy.fixed(3),
        progressStore: progress,
      );

      await controller.spin(() {});

      expect(controller.goldenCatVisibleCount, 3);
      expect(controller.pendingBonusGame?.id, kGoldenCatGameId);
      expect(controller.goldenCatProgress, 2);
      expect(progress.value, 2);
    },
  );

  test('simultaneous bonuses queue Mouse Hunt before Golden Cat', () async {
    final controller = _controller(
      policy: GoldenCatSymbolPolicy.fixed(3),
      mouseProbability: 1,
    );

    await controller.spin(() {});

    expect(controller.beginPendingBonus()?.game.id, kMouseHuntGameId);
    expect(controller.beginPendingBonus()?.game.id, kGoldenCatGameId);
    expect(controller.beginPendingBonus(), isNull);
  });

  test(
    'cash-out is persisted and credited exactly once across restart',
    () async {
      final wallet = MemoryWalletStore();
      final controller = _controller(
        policy: GoldenCatSymbolPolicy.fixed(3),
        walletStore: wallet,
      );
      await controller.spin(() {});
      final session = controller.beginPendingBonus()!;
      const result = GoldenCatResult(
        stageReached: 3,
        coinsWon: 250,
        cashedOut: true,
        missed: false,
      );

      expect(await controller.creditGoldenCatOnce(session, result), isTrue);
      expect(await controller.creditGoldenCatOnce(session, result), isFalse);
      expect(controller.coins, 259);

      final restarted = _controller(
        policy: GoldenCatSymbolPolicy.fixed(0),
        walletStore: wallet,
      );
      await restarted.initialize();
      expect(restarted.coins, 259);
      expect(await restarted.creditGoldenCatOnce(session, result), isFalse);
      expect(restarted.coins, 259);
    },
  );

  test('miss records the transaction but never removes wallet coins', () async {
    final controller = _controller(policy: GoldenCatSymbolPolicy.fixed(3));
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;
    const miss = GoldenCatResult(
      stageReached: 2,
      coinsWon: 0,
      cashedOut: false,
      missed: true,
    );
    final before = controller.coins;

    expect(await controller.creditGoldenCatOnce(session, miss), isTrue);
    expect(await controller.creditGoldenCatOnce(session, miss), isFalse);
    expect(controller.coins, before);
  });

  test('200k-spin simulation reproduces both bonus frequencies and return', () {
    final golden = GoldenCatSymbolPolicy(random: Random(4242));
    final mouse = BonusTriggerPolicy(random: Random(8484));
    const spins = 200000;
    var progress = 0;
    var goldenBonuses = 0;
    var mouseBonuses = 0;

    for (var i = 0; i < spins; i++) {
      if (mouse.shouldTrigger()) mouseBonuses++;
      final visible = golden.visibleCount();
      if (visible >= 3) {
        goldenBonuses++;
      } else {
        progress += visible;
        if (progress >= 3) {
          goldenBonuses++;
          progress %= 3;
        }
      }
    }

    final goldenRate = goldenBonuses / spins;
    final mouseRate = mouseBonuses / spins;
    expect(goldenRate, inInclusiveRange(0.024, 0.028));
    expect(mouseRate, inInclusiveRange(0.038, 0.042));

    // A random-timing player who always risks all five stages succeeds with
    // probability 1/32: 31.25 coins per challenge, about 0.81 per spin.
    const randomRiskExpectedPerChallenge = 1000 / 32;
    expect(
      goldenRate * randomRiskExpectedPerChallenge,
      inInclusiveRange(.75, .88),
    );
  });

  test('speed and prize ladder match the documented central configuration', () {
    expect(GoldenCatEconomy.payouts, [50, 100, 250, 500, 1000]);
    expect(GoldenCatEconomy.multipliers, [1, 2, 5, 10, 20]);
    expect(
      GoldenCatEconomy.switchIntervals.map((value) => value.inMilliseconds),
      [700, 550, 400, 300, 220],
    );
  });
}
