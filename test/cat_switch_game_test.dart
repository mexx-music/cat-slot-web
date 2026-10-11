import 'dart:math';

import 'package:catslot/features/cat_slot/bonus/cat_switch_game.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TargetLeftRandom implements Random {
  const _TargetLeftRandom();

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

const _session = BonusGameSession(
  transactionId: 'cat-switch-test-session',
  game: kCatSwitchDefinition,
);

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    required ValueChanged<CatSwitchResult> onCompleted,
    Size size = const Size(390, 844),
    int rounds = 2,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: CatSwitchGame(
          session: _session,
          onRoundCompleted: onCompleted,
          onExit: () {},
          reduceMotion: true,
          random: const _TargetLeftRandom(),
          rounds: rounds,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('records one correct and one incorrect choice', (tester) async {
    CatSwitchResult? result;
    await pumpGame(tester, onCompleted: (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('cat-switch-left')));
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.byKey(const ValueKey('cat-switch-right')));
    await tester.pump(const Duration(milliseconds: 2));

    expect(result?.correct, 1);
    expect(result?.roundsPlayed, 2);
    expect(result?.coinsWon, 28);
    expect(result?.skipped, isFalse);
    expect(find.byKey(const ValueKey('cat-switch-result')), findsOneWidget);
    expect(find.text('+28'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid taps can score only once per round', (tester) async {
    final results = <CatSwitchResult>[];
    await pumpGame(tester, onCompleted: results.add, rounds: 1);

    await tester.tap(find.byKey(const ValueKey('cat-switch-left')));
    await tester.tap(find.byKey(const ValueKey('cat-switch-right')));
    await tester.tap(find.byKey(const ValueKey('cat-switch-left')));
    await tester.pump(const Duration(milliseconds: 2));

    expect(results, hasLength(1));
    expect(results.single.correct, 1);
    expect(results.single.coinsWon, 28);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip and lifecycle interruption complete exactly once', (
    tester,
  ) async {
    final results = <CatSwitchResult>[];
    await pumpGame(tester, onCompleted: results.add, rounds: 10);

    await tester.tap(find.byKey(const ValueKey('cat-switch-left')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(results, hasLength(1));
    expect(results.single.correct, 1);
    expect(results.single.coinsWon, 28);
    expect(results.single.skipped, isTrue);
    expect(find.byKey(const ValueKey('cat-switch-result')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('compact phone and tablet layouts render without overflow', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(1024, 1366)]) {
      await pumpGame(tester, size: size, onCompleted: (_) {});
      expect(find.byKey(const ValueKey('cat-switch-game')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
