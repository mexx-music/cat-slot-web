import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:catslot/features/cat_slot/cat_slot_page.dart';
import 'package:catslot/features/cat_slot/services/bonus_trigger_policy.dart';
import 'package:catslot/features/cat_slot/services/golden_cat_system.dart';

class _FixedRandom implements Random {
  final int value;

  const _FixedRandom(this.value);

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => value % max;
}

class _SequenceRandom implements Random {
  int _index = 0;

  @override
  bool nextBool() => nextInt(2).isEven;

  @override
  double nextDouble() => nextInt(1000) / 1000;

  @override
  int nextInt(int max) => (_index++ % 3) % max;
}

CatSlotController _fastController(Random random) => CatSlotController(
  random: random,
  bonusTriggerPolicy: BonusTriggerPolicy(probability: 0),
  spinLeadIn: Duration.zero,
  reelStopGap: Duration.zero,
);

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    required Size logicalSize,
    CatSlotController? controller,
    bool reduceMotion = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: CatSlotPage(controller: controller),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the complete game on a compact phone', (tester) async {
    await pumpGame(tester, logicalSize: const Size(320, 568));

    expect(find.text('CAT SLOT'), findsOneWidget);
    expect(find.text('PURRCOINS'), findsOneWidget);
    expect(find.text('SPIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the wide layout without overflow on a tablet', (
    tester,
  ) async {
    await pumpGame(tester, logicalSize: const Size(1024, 1366));

    expect(find.text('COZY CAT ARCADE'), findsOneWidget);
    expect(find.text('THREE CATS · ONE PURRFECT MATCH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a spin animates and keeps the existing one-coin cost', (
    tester,
  ) async {
    final controller = CatSlotController(
      random: _SequenceRandom(),
      bonusTriggerPolicy: BonusTriggerPolicy(probability: 0),
    );
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
    );

    await tester.tap(find.text('SPIN'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('PURRING'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small wins settle immediately and stay inline', (tester) async {
    final controller = _fastController(const _FixedRandom(0));
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
    );

    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(controller.coins, 12);
    expect(find.byKey(const ValueKey('small-win-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('big-win-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large win panel never credits the reward twice', (tester) async {
    final controller = _fastController(const _FixedRandom(4));
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
    );

    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(controller.coins, 19); // 10 - 1 + 10
    expect(find.byKey(const ValueKey('big-win-panel')), findsOneWidget);
    expect(find.text('CAT-TASTIC!'), findsOneWidget);
    await tester.tap(find.text('WEITER'));
    await tester.pump();
    expect(controller.coins, 19);
    expect(find.byKey(const ValueKey('big-win-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid repeated taps start only one spin', (tester) async {
    final controller = _fastController(const _FixedRandom(0));
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
    );

    await tester.tap(find.text('SPIN'));
    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(controller.coins, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion completes a large reward without coin flight', (
    tester,
  ) async {
    final controller = _fastController(const _FixedRandom(2));
    await pumpGame(
      tester,
      logicalSize: const Size(320, 568),
      controller: controller,
      reduceMotion: true,
    );

    await tester.ensureVisible(find.text('SPIN'));
    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.tap(find.text('WEITER'));
    await tester.pump();

    expect(controller.coins, 14);
    expect(find.byType(CatSlotPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app interruption safely completes visual-only reward state', (
    tester,
  ) async {
    final controller = _fastController(const _FixedRandom(2));
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
    );

    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.byKey(const ValueKey('big-win-panel')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(controller.coins, 14);
    expect(find.byKey(const ValueKey('big-win-panel')), findsNothing);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('three mouse IDs open Mouse Hunt and return to the slot', (
    tester,
  ) async {
    final controller = CatSlotController(
      random: const _FixedRandom(0),
      bonusTriggerPolicy: BonusTriggerPolicy(probability: 1),
      spinLeadIn: Duration.zero,
      reelStopGap: Duration.zero,
    );
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
    );

    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 550));

    expect(find.byKey(const ValueKey('mouse-hunt-game')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skip-mouse-hunt')));
    await tester.pump();
    expect(controller.coins, 29); // 10 - 1 + 20 participation bonus
    await tester.tap(find.byKey(const ValueKey('return-to-slot')));
    await tester.pump();

    expect(find.text('CAT SLOT'), findsOneWidget);
    expect(find.byKey(const ValueKey('mouse-hunt-game')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three golden cats open the challenge and persist cash-out', (
    tester,
  ) async {
    final wallet = MemoryWalletStore();
    final controller = CatSlotController(
      random: const _FixedRandom(0),
      bonusTriggerPolicy: BonusTriggerPolicy(probability: 0),
      goldenCatPolicy: GoldenCatSymbolPolicy.fixed(3),
      walletStore: wallet,
      spinLeadIn: Duration.zero,
      reelStopGap: Duration.zero,
    );
    await pumpGame(
      tester,
      logicalSize: const Size(390, 844),
      controller: controller,
      reduceMotion: true,
    );

    await tester.tap(find.text('SPIN'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.byKey(const ValueKey('golden-cat-challenge')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 701));
    await tester.tap(find.byKey(const ValueKey('golden-cat-now')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('golden-cat-cash-out')));
    await tester.pump();
    await tester.pump();

    expect(controller.coins, 59);
    expect(wallet.snapshot?.coins, 59);
    await tester.tap(find.byKey(const ValueKey('return-from-golden-cat')));
    await tester.pump();
    expect(find.text('CAT SLOT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
