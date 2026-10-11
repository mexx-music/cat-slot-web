import 'package:catslot/features/cat_slot/bonus/golden_cat_challenge.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/golden_cat_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = BonusGameSession(
  transactionId: 'golden-cat-test-session',
  game: kGoldenCatDefinition,
);

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    required GoldenCatCompletion onCompleted,
    Size size = const Size(390, 844),
    bool reduceMotion = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: GoldenCatChallenge(
          key: UniqueKey(),
          session: _session,
          onRoundCompleted: onCompleted,
          onExit: () {},
          reduceMotion: reduceMotion,
        ),
      ),
    );
    await tester.pump(
      reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 651),
    );
  }

  Future<void> hitCurrentStage(WidgetTester tester, int stage) async {
    await tester.pump(
      GoldenCatEconomy.intervalForStage(stage) +
          const Duration(milliseconds: 1),
    );
    expect(find.byKey(const ValueKey('golden-cat-visible')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('golden-cat-now')));
    await tester.pump();
  }

  testWidgets('golden frame is a hit and normal frame is a miss', (
    tester,
  ) async {
    final hits = <GoldenCatResult>[];
    await pumpGame(tester, onCompleted: (result) async => hits.add(result));
    await hitCurrentStage(tester, 1);

    expect(find.byKey(const ValueKey('golden-cat-cash-out')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('golden-cat-cash-out')));
    await tester.pump();
    expect(hits.single.coinsWon, 50);
    expect(hits.single.missed, isFalse);

    final misses = <GoldenCatResult>[];
    await pumpGame(tester, onCompleted: (result) async => misses.add(result));
    expect(find.byKey(const ValueKey('normal-cat-visible')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('golden-cat-now')));
    await tester.pump();
    expect(misses.single.coinsWon, 0);
    expect(misses.single.missed, isTrue);
  });

  testWidgets('input around a frame boundary follows the painted state', (
    tester,
  ) async {
    final beforeBoundary = <GoldenCatResult>[];
    await pumpGame(
      tester,
      onCompleted: (result) async => beforeBoundary.add(result),
    );
    await tester.pump(const Duration(milliseconds: 699));
    expect(find.byKey(const ValueKey('normal-cat-visible')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('golden-cat-now')));
    await tester.pump();
    expect(beforeBoundary.single.missed, isTrue);

    final afterBoundary = <GoldenCatResult>[];
    await pumpGame(
      tester,
      onCompleted: (result) async => afterBoundary.add(result),
    );
    await tester.pump(const Duration(milliseconds: 701));
    expect(find.byKey(const ValueKey('golden-cat-visible')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('golden-cat-now')));
    await tester.pump();
    expect(find.byKey(const ValueKey('golden-cat-cash-out')), findsOneWidget);
    expect(afterBoundary, isEmpty);
  });

  testWidgets('double tap produces only one decision and one payout', (
    tester,
  ) async {
    final results = <GoldenCatResult>[];
    await pumpGame(
      tester,
      size: const Size(320, 568),
      onCompleted: (result) async => results.add(result),
    );
    await tester.pump(const Duration(milliseconds: 701));

    final now = find.byKey(const ValueKey('golden-cat-now'));
    await tester.tap(now);
    await tester.tap(now);
    await tester.pump();
    expect(find.byKey(const ValueKey('golden-cat-cash-out')), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.byKey(const ValueKey('golden-cat-cash-out')));
    await tester.tap(find.byKey(const ValueKey('golden-cat-cash-out')));
    await tester.pump();
    expect(results, hasLength(1));
  });

  testWidgets('player can cash out after every non-final stage', (
    tester,
  ) async {
    for (
      var desiredStage = 1;
      desiredStage < GoldenCatEconomy.stages;
      desiredStage++
    ) {
      final results = <GoldenCatResult>[];
      await pumpGame(
        tester,
        onCompleted: (result) async => results.add(result),
      );
      for (var stage = 1; stage <= desiredStage; stage++) {
        await hitCurrentStage(tester, stage);
        if (stage < desiredStage) {
          await tester.tap(find.byKey(const ValueKey('golden-cat-risk')));
          await tester.pump();
        }
      }
      await tester.tap(find.byKey(const ValueKey('golden-cat-cash-out')));
      await tester.pump();

      expect(results.single.stageReached, desiredStage);
      expect(
        results.single.coinsWon,
        GoldenCatEconomy.payoutForStage(desiredStage),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('level five offers 1000 coins or the level six risk', (
    tester,
  ) async {
    final results = <GoldenCatResult>[];
    await pumpGame(
      tester,
      size: const Size(320, 568),
      onCompleted: (result) async => results.add(result),
    );

    for (var stage = 1; stage <= 5; stage++) {
      await hitCurrentStage(tester, stage);
      if (stage < 5) {
        await tester.tap(find.byKey(const ValueKey('golden-cat-risk')));
        await tester.pump();
      }
    }

    expect(results, isEmpty);
    expect(find.text('Treffer! Du hast 1000 Coins erreicht!'), findsOneWidget);
    expect(find.text('1.000 NEHMEN'), findsOneWidget);
    expect(find.text('LEVEL 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('golden-cat-cash-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('golden-cat-risk')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('golden-cat-cash-out')));
    await tester.pump();
    expect(results.single.stageReached, 5);
    expect(results.single.coinsWon, 1000);
  });

  testWidgets('risk continues through six stages and level six auto-pays', (
    tester,
  ) async {
    final results = <GoldenCatResult>[];
    await pumpGame(tester, onCompleted: (result) async => results.add(result));

    for (var stage = 1; stage <= GoldenCatEconomy.stages; stage++) {
      await hitCurrentStage(tester, stage);
      if (stage < GoldenCatEconomy.stages) {
        await tester.tap(find.byKey(const ValueKey('golden-cat-risk')));
        await tester.pump();
        expect(find.text('STUFE ${stage + 1}/6'), findsOneWidget);
      }
    }

    expect(results, hasLength(1));
    expect(results.single.stageReached, 6);
    expect(results.single.coinsWon, 2500);
    expect(find.byKey(const ValueKey('golden-cat-result')), findsOneWidget);
  });

  testWidgets('level six visibly switches at the configured 160ms boundary', (
    tester,
  ) async {
    final results = <GoldenCatResult>[];
    await pumpGame(
      tester,
      size: const Size(320, 568),
      onCompleted: (result) async => results.add(result),
    );

    for (var stage = 1; stage <= 5; stage++) {
      await hitCurrentStage(tester, stage);
      await tester.tap(find.byKey(const ValueKey('golden-cat-risk')));
      await tester.pump();
    }

    expect(find.text('STUFE 6/6'), findsOneWidget);
    expect(find.text('×50'), findsOneWidget);
    expect(find.text('2500 Coins'), findsOneWidget);
    expect(find.byKey(const ValueKey('normal-cat-visible')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 159));
    expect(find.byKey(const ValueKey('normal-cat-visible')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byKey(const ValueKey('golden-cat-visible')), findsOneWidget);

    final now = find.byKey(const ValueKey('golden-cat-now'));
    await tester.tap(now);
    await tester.tap(now);
    await tester.pump();
    expect(results, hasLength(1));
    expect(results.single.stageReached, 6);
    expect(results.single.coinsWon, 2500);
  });

  testWidgets('a level six miss loses only the unsecured bonus', (
    tester,
  ) async {
    final results = <GoldenCatResult>[];
    await pumpGame(tester, onCompleted: (result) async => results.add(result));

    for (var stage = 1; stage <= 5; stage++) {
      await hitCurrentStage(tester, stage);
      await tester.tap(find.byKey(const ValueKey('golden-cat-risk')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('golden-cat-now')));
    await tester.pump();

    expect(results.single.stageReached, 6);
    expect(results.single.coinsWon, 0);
    expect(results.single.missed, isTrue);
  });

  testWidgets('app pause freezes and fairly restarts the same risk stage', (
    tester,
  ) async {
    final results = <GoldenCatResult>[];
    await pumpGame(tester, onCompleted: (result) async => results.add(result));
    await tester.pump(const Duration(milliseconds: 250));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(results, isEmpty);
    expect(find.text('PAUSIERT'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('normal-cat-visible')), findsOneWidget);
    await hitCurrentStage(tester, 1);
    expect(find.byKey(const ValueKey('golden-cat-cash-out')), findsOneWidget);
  });

  testWidgets('compact phone, reduced motion and tablet do not overflow', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(1024, 1366)]) {
      await pumpGame(
        tester,
        size: size,
        reduceMotion: true,
        onCompleted: (_) async {},
      );
      expect(
        find.byKey(const ValueKey('golden-cat-challenge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('golden-cat-stage-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('golden-cat-ladder-stage-6')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
