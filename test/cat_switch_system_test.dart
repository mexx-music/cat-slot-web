import 'dart:math';

import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/bonus_trigger_policy.dart';
import 'package:catslot/features/cat_slot/services/cat_switch_system.dart';
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
  required CatSwitchSymbolPolicy policy,
  BonusProgressStore? store,
  double mouseProbability = 0,
}) => CatSlotController(
  random: const _FixedRandom(),
  bonusTriggerPolicy: BonusTriggerPolicy(probability: mouseProbability),
  catSwitchPolicy: policy,
  progressStore: store,
  spinLeadIn: Duration.zero,
  reelStopGap: Duration.zero,
);

void main() {
  test('counts bonus cats anywhere in the complete 3x3 window', () {
    const row = [
      [kCatSwitchBonusSymbolId, 'a', 'b'],
      [kCatSwitchBonusSymbolId, 'c', 'd'],
      [kCatSwitchBonusSymbolId, 'e', 'f'],
    ];
    const diagonal = [
      [kCatSwitchBonusSymbolId, 'a', 'b'],
      ['c', kCatSwitchBonusSymbolId, 'd'],
      ['e', 'f', kCatSwitchBonusSymbolId],
    ];
    const distributed = [
      ['a', 'b', kCatSwitchBonusSymbolId],
      [kCatSwitchBonusSymbolId, 'c', 'd'],
      ['e', kCatSwitchBonusSymbolId, 'f'],
    ];

    for (final reels in [row, diagonal, distributed]) {
      expect(VisibleBonusCounter.count(reels, kCatSwitchBonusSymbolId), 3);
    }
  });

  test(
    'collects single symbols over several spins and carries remainder',
    () async {
      final store = MemoryBonusProgressStore();
      final controller = _controller(
        policy: CatSwitchSymbolPolicy.sequence([1, 1, 2]),
        store: store,
      );

      await controller.spin(() {});
      expect(controller.catSwitchProgress, 1);
      await controller.spin(() {});
      expect(controller.catSwitchProgress, 2);
      await controller.spin(() {});

      expect(controller.pendingBonusGame?.id, kCatSwitchGameId);
      expect(controller.catSwitchProgress, 1);
      expect(store.value, 1);
    },
  );

  test('collector progress survives a controller restart', () async {
    final store = MemoryBonusProgressStore();
    final first = _controller(
      policy: CatSwitchSymbolPolicy.fixed(1),
      store: store,
    );
    await first.spin(() {});

    final restarted = _controller(
      policy: CatSwitchSymbolPolicy.fixed(0),
      store: store,
    );
    await restarted.initialize();

    expect(restarted.catSwitchProgress, 1);
  });

  test(
    'three visible symbols trigger directly without double collecting',
    () async {
      final store = MemoryBonusProgressStore(2);
      final controller = _controller(
        policy: CatSwitchSymbolPolicy.fixed(3),
        store: store,
      );

      await controller.spin(() {});

      expect(controller.catSwitchVisibleCount, 3);
      expect(controller.pendingBonusGame?.id, kCatSwitchGameId);
      expect(controller.catSwitchProgress, 2);
      expect(store.value, 2);
    },
  );

  test('simultaneous bonuses queue Mouse Hunt before Cat Switch', () async {
    final controller = _controller(
      policy: CatSwitchSymbolPolicy.fixed(3),
      mouseProbability: 1,
    );

    await controller.spin(() {});

    expect(controller.beginPendingBonus()?.game.id, kMouseHuntGameId);
    expect(controller.beginPendingBonus()?.game.id, kCatSwitchGameId);
    expect(controller.beginPendingBonus(), isNull);
  });

  test('Cat Switch reward transaction is credited exactly once', () async {
    final controller = _controller(policy: CatSwitchSymbolPolicy.fixed(3));
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;
    const result = CatSwitchResult(
      correct: 2,
      roundsPlayed: 2,
      coinsWon: 36,
      skipped: false,
    );

    expect(controller.creditCatSwitchOnce(session, result), isTrue);
    expect(controller.creditCatSwitchOnce(session, result), isFalse);
    expect(controller.coins, 45);
  });

  test('production frequency stays close to its configured expectation', () {
    final policy = CatSwitchSymbolPolicy(random: Random(4242));
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
    expect(rate, inInclusiveRange(0.024, 0.028));
    expect(spins / bonuses, inInclusiveRange(35.5, 41.7));
  });
}
