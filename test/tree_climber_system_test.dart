import 'dart:math';

import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/bonus_trigger_policy.dart';
import 'package:catslot/features/cat_slot/services/fishing_cat_system.dart';
import 'package:catslot/features/cat_slot/services/golden_cat_system.dart';
import 'package:catslot/features/cat_slot/services/tree_climber_system.dart';
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
  required TreeClimberSymbolPolicy treePolicy,
  BonusProgressStore? progressStore,
  WalletStore? walletStore,
}) => CatSlotController(
  random: const _FixedRandom(),
  bonusTriggerPolicy: BonusTriggerPolicy(probability: 0),
  goldenCatPolicy: GoldenCatSymbolPolicy.fixed(0),
  fishingCatPolicy: FishingCatSymbolPolicy.fixed(0),
  treeClimberPolicy: treePolicy,
  progressStore: progressStore,
  walletStore: walletStore,
  spinLeadIn: Duration.zero,
  reelStopGap: Duration.zero,
);

void main() {
  test(
    'course is deterministic and difficulty tightens across ten sections',
    () {
      final first = TreeClimberCourse.generate(seed: 417);
      final second = TreeClimberCourse.generate(seed: 417);

      expect(first.sections, hasLength(10));
      for (var i = 0; i < first.sections.length; i++) {
        final a = first.sections[i];
        final b = second.sections[i];
        expect(a.targetX, b.targetX);
        expect(a.heightGain, b.heightGain);
        expect(a.branchWidth, b.branchWidth);
      }
      expect(
        first.sections[9].branchWidth,
        lessThan(first.sections[0].branchWidth),
      );
      expect(
        first.sections[9].heightGain,
        greaterThan(first.sections[0].heightGain),
      );
    },
  );

  test('landing is derived only from the visible projectile geometry', () {
    const section = TreeClimberSection(
      number: 1,
      targetX: .70,
      heightGain: .26,
      branchWidth: .20,
    );
    final solution = TreeClimberPhysics.findSolution(
      startX: .5,
      section: section,
    );
    expect(solution, isNotNull);
    final hit = TreeClimberPhysics.trajectoryFor(
      startX: .5,
      section: section,
      angleDegrees: solution!.angleDegrees,
      powerPercent: solution.powerPercent,
    );
    expect(hit.landsOnBranch, isTrue);
    expect(hit.positionAtProgress(1).dx, hit.impactX);
    expect(hit.positionAtProgress(1).dy, closeTo(hit.targetY, 1e-9));
    expect((hit.impactX - section.targetX).abs(), lessThanOrEqualTo(.10));

    final miss = TreeClimberPhysics.trajectoryFor(
      startX: .5,
      section: section,
      angleDegrees: TreeClimberPhysics.minAngle,
      powerPercent: TreeClimberPhysics.minPower,
    );
    expect(miss.landsOnBranch, isFalse);
  });

  test('all ten sections remain solvable across generated courses', () {
    for (var seed = 0; seed < 120; seed++) {
      final course = TreeClimberCourse.generate(seed: seed);
      var startX = .5;
      for (final section in course.sections) {
        final solution = TreeClimberPhysics.findSolution(
          startX: startX,
          section: section,
        );
        expect(
          solution,
          isNotNull,
          reason: 'seed $seed section ${section.number}',
        );
        final trajectory = TreeClimberPhysics.trajectoryFor(
          startX: startX,
          section: section,
          angleDegrees: solution!.angleDegrees,
          powerPercent: solution.powerPercent,
        );
        expect(trajectory.landsOnBranch, isTrue);
        startX = section.targetX;
      }
    }
  });

  test('later climbs narrow the preview without changing real physics', () {
    expect(TreeClimberPhysics.previewFractionForSection(1), 1);
    expect(TreeClimberPhysics.previewFractionForSection(10), lessThan(.5));
    final course = TreeClimberCourse.generate(seed: 417);
    expect(course.sections.first.branchWidth, greaterThan(.25));
    expect(course.sections.last.branchWidth, lessThan(.1));
  });

  test('perfect jump requires a real center landing', () {
    const section = TreeClimberSection(
      number: 8,
      targetX: .7,
      heightGain: .36,
      branchWidth: .12,
    );
    final solution = TreeClimberPhysics.findSolution(
      startX: .5,
      section: section,
    )!;
    final trajectory = TreeClimberPhysics.trajectoryFor(
      startX: .5,
      section: section,
      angleDegrees: solution.angleDegrees,
      powerPercent: solution.powerPercent,
    );
    expect(trajectory.landsOnBranch, isTrue);
    expect(
      TreeClimberPhysics.isPerfectLanding(
        trajectory: trajectory,
        section: section,
      ),
      isTrue,
    );
  });

  test('checkpoint points and summit conversion stay centrally configured', () {
    expect(TreeClimberEconomy.pointsForSection(1), 0);
    expect(TreeClimberEconomy.pointsForSection(2), 20);
    expect(TreeClimberEconomy.pointsForSection(4), 50);
    expect(TreeClimberEconomy.pointsForSection(6), 100);
    expect(TreeClimberEconomy.pointsForSection(8), 200);
    expect(TreeClimberEconomy.pointsForSection(10), 400);
    expect(TreeClimberEconomy.coinsFor(points: 400, reachedSummit: true), 60);
  });

  test('three distributed tree IDs trigger Tree Climber', () async {
    final controller = _controller(
      treePolicy: TreeClimberSymbolPolicy.fixed(3),
    );
    await controller.spin(() {});

    expect(controller.treeClimberVisibleCount, 3);
    expect(controller.pendingBonusGame?.id, kTreeClimberGameId);
    expect(controller.latestWin, 0);
    expect(
      controller.reels
          .expand((reel) => reel)
          .where((id) => id == kTreeClimberBonusSymbolId),
      hasLength(3),
    );
  });

  test('collector progress persists and queues exactly one round', () async {
    final progress = MemoryBonusProgressStore();
    final controller = _controller(
      treePolicy: TreeClimberSymbolPolicy.sequence([1, 1, 2]),
      progressStore: progress,
    );
    await controller.spin(() {});
    await controller.spin(() {});
    expect(controller.treeClimberProgress, 2);
    await controller.spin(() {});

    expect(controller.pendingBonusGame?.id, kTreeClimberGameId);
    expect(controller.treeClimberProgress, 1);
    expect(progress.treeValue, 1);
    expect(progress.value, 0);
    expect(progress.fishingValue, 0);
  });

  test('summit reward is persisted exactly once across restart', () async {
    final wallet = MemoryWalletStore();
    final controller = _controller(
      treePolicy: TreeClimberSymbolPolicy.fixed(3),
      walletStore: wallet,
    );
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;
    const result = TreeClimberResult(
      sectionsReached: 10,
      pointsWon: 400,
      coinsWon: 60,
      reachedSummit: true,
      cashedOut: false,
    );

    expect(await controller.creditTreeClimberOnce(session, result), isTrue);
    expect(await controller.creditTreeClimberOnce(session, result), isFalse);
    expect(controller.coins, 69);

    final restarted = _controller(
      treePolicy: TreeClimberSymbolPolicy.fixed(0),
      walletStore: wallet,
    );
    await restarted.initialize();
    expect(restarted.coins, 69);
    expect(await restarted.creditTreeClimberOnce(session, result), isFalse);
  });

  test('all four bonus events stay queued in stable order', () async {
    final progress = MemoryBonusProgressStore(2, 2, 2);
    final controller = CatSlotController(
      random: const _FixedRandom(),
      bonusTriggerPolicy: BonusTriggerPolicy(probability: 1),
      goldenCatPolicy: GoldenCatSymbolPolicy.fixed(1),
      fishingCatPolicy: FishingCatSymbolPolicy.fixed(1),
      treeClimberPolicy: TreeClimberSymbolPolicy.fixed(1),
      progressStore: progress,
      spinLeadIn: Duration.zero,
      reelStopGap: Duration.zero,
    );
    await controller.spin(() {});

    expect(controller.beginPendingBonus()?.game.id, kMouseHuntGameId);
    expect(controller.beginPendingBonus()?.game.id, kGoldenCatGameId);
    expect(controller.beginPendingBonus()?.game.id, kFishingCatGameId);
    expect(controller.beginPendingBonus()?.game.id, kTreeClimberGameId);
    expect(controller.beginPendingBonus(), isNull);
  });

  test('invalid Tree Climber reward is rejected', () async {
    final controller = _controller(
      treePolicy: TreeClimberSymbolPolicy.fixed(3),
    );
    await controller.spin(() {});
    final session = controller.beginPendingBonus()!;

    await expectLater(
      controller.creditTreeClimberOnce(
        session,
        const TreeClimberResult(
          sectionsReached: 8,
          pointsWon: 200,
          coinsWon: 999,
          reachedSummit: false,
          cashedOut: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('200k spins stay near configured Tree Climber frequency', () {
    final policy = TreeClimberSymbolPolicy(random: Random(86420));
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

    expect(bonuses / spins, inInclusiveRange(.0115, .0135));
  });

  test('bonus registry contains four unique stable IDs', () {
    expect(kBonusGames, contains(kTreeClimberDefinition));
    expect(kBonusGames.map((game) => game.id).toSet(), hasLength(4));
    expect(
      bonusGameForSymbolId(kTreeClimberBonusSymbolId)?.id,
      kTreeClimberGameId,
    );
  });
}
