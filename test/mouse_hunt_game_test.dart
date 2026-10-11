import 'dart:math';

import 'package:catslot/features/cat_slot/bonus/mouse_hunt_game.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/widgets/hunt_cat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = BonusGameSession(
  transactionId: 'mouse-hunt-test-session',
  game: kMouseHuntDefinition,
);

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    required ValueChanged<BonusGameResult> onCompleted,
    required VoidCallback onExit,
    bool reduceMotion = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: MouseHuntGame(
          session: _session,
          onRoundCompleted: onCompleted,
          onExit: onExit,
          reduceMotion: reduceMotion,
          random: Random(7),
          roundDuration: const Duration(seconds: 2),
          spawnInterval: const Duration(milliseconds: 250),
          mouseLifetime: const Duration(milliseconds: 600),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('catches a mouse and preserves reward when skipped', (
    tester,
  ) async {
    BonusGameResult? completed;
    var exits = 0;
    await pumpGame(
      tester,
      onCompleted: (result) => completed = result,
      onExit: () => exits++,
      reduceMotion: true,
    );

    await tester.pump(const Duration(milliseconds: 1));
    final mouse = find.byKey(const ValueKey('mouse-target-0'));
    expect(mouse, findsOneWidget);
    await tester.tap(mouse);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('skip-mouse-hunt')));
    await tester.pump();

    expect(completed?.normalCaught, 1);
    expect(completed?.goldenCaught, 0);
    expect(completed?.coinsWon, 30);
    expect(completed?.skipped, isTrue);
    expect(find.byKey(const ValueKey('mouse-hunt-result')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('return-to-slot')));
    expect(exits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app interruption finalizes once and keeps caught mice', (
    tester,
  ) async {
    final results = <BonusGameResult>[];
    await pumpGame(
      tester,
      onCompleted: results.add,
      onExit: () {},
      size: const Size(1024, 1366),
    );

    await tester.pump(const Duration(milliseconds: 360));
    await tester.tap(find.byKey(const ValueKey('mouse-target-0')));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(results, hasLength(1));
    expect(results.single.normalCaught, 1);
    expect(results.single.coinsWon, 30);
    expect(find.byKey(const ValueKey('mouse-hunt-result')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('cat prepares, pounces, catches and celebrates in sequence', (
    tester,
  ) async {
    BonusGameResult? completed;
    await pumpGame(
      tester,
      onCompleted: (result) => completed = result,
      onExit: () {},
    );

    await tester.pump(const Duration(milliseconds: 360));
    expect(
      tester.widget<HuntCat>(find.byType(HuntCat)).state,
      HuntCatState.alert,
    );
    final mouse = find.byKey(const ValueKey('mouse-target-0'));
    await tester.tap(mouse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final pouncingCat = tester.widget<HuntCat>(find.byType(HuntCat));
    expect(pouncingCat.phase, greaterThan(0.16));
    expect(pouncingCat.state, HuntCatState.pounce);
    expect(mouse, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<HuntCat>(find.byType(HuntCat)).state,
      HuntCatState.catching,
    );
    expect(mouse, findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.widget<HuntCat>(find.byType(HuntCat)).state,
      HuntCatState.celebrate,
    );
    await tester.tap(find.byKey(const ValueKey('skip-mouse-hunt')));
    await tester.pump();

    expect(completed?.normalCaught, 1);
    expect(completed?.coinsWon, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid taps during a pounce cannot catch twice', (tester) async {
    BonusGameResult? completed;
    await pumpGame(
      tester,
      onCompleted: (result) => completed = result,
      onExit: () {},
    );

    await tester.pump(const Duration(milliseconds: 360));
    final mouse = find.byKey(const ValueKey('mouse-target-0'));
    await tester.tap(mouse);
    await tester.tap(mouse);
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('mouse-hunt-scene'))) +
          const Offset(20, 20),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const ValueKey('skip-mouse-hunt')));
    await tester.pump();

    expect(completed?.normalCaught, 1);
    expect(completed?.goldenCaught, 0);
    expect(completed?.coinsWon, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missed tap produces the humorous miss state without reward', (
    tester,
  ) async {
    BonusGameResult? completed;
    await pumpGame(
      tester,
      size: const Size(320, 568),
      onCompleted: (result) => completed = result,
      onExit: () {},
    );

    await tester.pump(const Duration(milliseconds: 360));
    final scene = find.byKey(const ValueKey('mouse-hunt-scene'));
    await tester.tapAt(tester.getBottomLeft(scene) + const Offset(14, -14));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 560));

    expect(
      tester.widget<HuntCat>(find.byType(HuntCat)).state,
      HuntCatState.miss,
    );
    await tester.tap(find.byKey(const ValueKey('skip-mouse-hunt')));
    await tester.pump();
    expect(completed?.normalCaught, 0);
    expect(completed?.goldenCaught, 0);
    expect(completed?.coinsWon, 20);
    expect(tester.takeException(), isNull);
  });

  test('hunter appearance is ready for future symbol sets', () {
    expect(
      HunterCatAppearance.forSymbolSetId('santa_cats').accessory,
      HuntCatAccessory.santaHat,
    );
    expect(
      HunterCatAppearance.forSymbolSetId('unknown').sourceSetId,
      'standard',
    );
  });
}
