import 'dart:math';

import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/bonus_trigger_policy.dart';
import 'package:catslot/features/cat_slot/services/fishing_cat_system.dart';
import 'package:catslot/features/cat_slot/services/golden_cat_system.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  const _FixedRandom();

  @override
  bool nextBool() => true;
  @override
  double nextDouble() => .5;
  @override
  int nextInt(int max) => 0;
}

CatSlotController _controller({
  required FishingCatSymbolPolicy policy,
  BonusProgressStore? progressStore,
  WalletStore? walletStore,
  GoldenCatSymbolPolicy? goldenPolicy,
  double mouseProbability = 0,
}) => CatSlotController(
  random: const _FixedRandom(),
  bonusTriggerPolicy: BonusTriggerPolicy(probability: mouseProbability),
  goldenCatPolicy: goldenPolicy ?? GoldenCatSymbolPolicy.fixed(0),
  fishingCatPolicy: policy,
  progressStore: progressStore,
  walletStore: walletStore,
  spinLeadIn: Duration.zero,
  reelStopGap: Duration.zero,
);

void main() {
  test('collision uses actual target position and size', () {
    const target = FishingTarget(
      id: 'fish',
      kind: FishingCatchKind.small,
      startX: .2,
      depth: .6,
      speed: .1,
      size: .05,
      swimsRight: true,
    );

    expect(
      FishingCollision.catchAt(
        hook: const Offset(.4, .6),
        targets: const [target],
        worldTime: 2,
      ),
      same(target),
    );
    expect(
      FishingCollision.catchAt(
        hook: const Offset(.55, .6),
        targets: const [target],
        worldTime: 2,
      ),
      isNull,
    );
  });

  test('point values and conversion are centrally configured', () {
    expect(FishingCatEconomy.attempts, 5);
    expect(FishingCatEconomy.pointsFor(FishingCatchKind.small), 20);
    expect(FishingCatEconomy.pointsFor(FishingCatchKind.colorful), 50);
    expect(FishingCatEconomy.pointsFor(FishingCatchKind.big), 100);
    expect(FishingCatEconomy.pointsFor(FishingCatchKind.golden), 250);
    expect(FishingCatEconomy.pointsFor(FishingCatchKind.boot), 0);
    expect(FishingCatEconomy.pointsFor(FishingCatchKind.treasure), 150);
    expect(FishingCatEconomy.coinsForPoints(249), 24);
  });

  test('encounters are exactly reproducible from a fixed seed', () {
    final first = FishingEncounterFactory.create(seed: 7357);
    final second = FishingEncounterFactory.create(seed: 7357);
    expect(first.length, 5);
    for (var attempt = 0; attempt < first.length; attempt++) {
      for (var index = 0; index < first[attempt].length; index++) {
        final a = first[attempt][index];
        final b = second[attempt][index];
        expect(a.kind, b.kind);
        expect(a.startX, b.startX);
        expect(a.depth, b.depth);
        expect(a.speed, b.speed);
        expect(a.size, b.size);
      }
    }
  });

  test('collector persists independently and queues Fishing Cat', () async {
    final progress = MemoryBonusProgressStore();
    final controller = _controller(
      policy: FishingCatSymbolPolicy.sequence([1, 1, 2]),
      progressStore: progress,
    );
    await controller.spin(() {});
    await controller.spin(() {});
    expect(controller.fishingCatProgress, 2);
    await controller.spin(() {});

    expect(controller.pendingBonusGame?.id, kFishingCatGameId);
    expect(controller.fishingCatProgress, 1);
    expect(progress.fishingValue, 1);
    expect(progress.value, 0);
  });

  test('simultaneous bonuses retain Mouse, Golden, Fishing order', () async {
    final controller = _controller(
      policy: FishingCatSymbolPolicy.fixed(3),
      goldenPolicy: GoldenCatSymbolPolicy.fixed(3),
      mouseProbability: 1,
    );
    await controller.spin(() {});

    expect(controller.beginPendingBonus()?.game.id, kMouseHuntGameId);
    expect(controller.beginPendingBonus()?.game.id, kGoldenCatGameId);
    expect(controller.beginPendingBonus()?.game.id, kFishingCatGameId);
    expect(controller.beginPendingBonus(), isNull);
  });

  test('fishing reward persists exactly once across restart', () async {
    final wallet = MemoryWalletStore();
    final controller = _controller(
      policy: FishingCatSymbolPolicy.fixed(3),
      walletStore: wallet,
    );
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;
    const result = FishingCatResult(
      attemptsCompleted: 5,
      catches: {'small': 2, 'golden': 1, 'boot': 1},
      pointsWon: 290,
      coinsWon: 29,
      skipped: false,
    );

    expect(await controller.creditFishingCatOnce(session, result), isTrue);
    expect(await controller.creditFishingCatOnce(session, result), isFalse);
    expect(controller.coins, 38);

    final restarted = _controller(
      policy: FishingCatSymbolPolicy.fixed(0),
      walletStore: wallet,
    );
    await restarted.initialize();
    expect(restarted.coins, 38);
    expect(await restarted.creditFishingCatOnce(session, result), isFalse);
  });

  test('200k spin simulation keeps fishing frequency near configured rate', () {
    final policy = FishingCatSymbolPolicy(random: Random(97531));
    const spins = 200000;
    var progress = 0;
    var bonuses = 0;
    for (var i = 0; i < spins; i++) {
      final visible = policy.visibleCount();
      if (visible >= 3) {
        bonuses++;
      } else {
        progress += visible;
        if (progress >= 3) {
          bonuses++;
          progress %= 3;
        }
      }
    }
    final rate = bonuses / spins;
    expect(rate, inInclusiveRange(.0165, .0185));
  });
}
