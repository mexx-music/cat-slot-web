import 'package:catslot/features/cat_slot/bonus/fishing_cat_game.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/fishing_cat_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = BonusGameSession(
  transactionId: 'fishing-test-session',
  game: kFishingCatDefinition,
);

FishingTarget _target(FishingCatchKind kind, {bool hittable = true}) =>
    FishingTarget(
      id: '${kind.name}-$hittable',
      kind: kind,
      startX: hittable ? .68 : .08,
      depth: .675,
      speed: 0,
      size: .08,
      swimsRight: true,
    );

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    required List<FishingCatchKind?> kinds,
    required ValueChanged<FishingCatResult> onResult,
    Size size = const Size(390, 844),
    bool reduceMotion = true,
    Duration feedbackDuration = Duration.zero,
    Duration recoveryGrace = const Duration(milliseconds: 80),
    ValueNotifier<bool>? tickerEnabled,
    BonusGameSession session = _session,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final game = FishingCatGame(
      key: ValueKey(session.transactionId),
      session: session,
      onRoundCompleted: (result) async => onResult(result),
      onExit: () {},
      reduceMotion: reduceMotion,
      castDuration: const Duration(milliseconds: 200),
      feedbackDuration: feedbackDuration,
      castRecoveryGrace: recoveryGrace,
      encounters: [
        for (var i = 0; i < 5; i++)
          [
            _target(
              kinds[i] ?? FishingCatchKind.small,
              hittable: kinds[i] != null,
            ),
          ],
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: tickerEnabled == null
            ? game
            : ValueListenableBuilder<bool>(
                valueListenable: tickerEnabled,
                builder: (_, enabled, child) =>
                    TickerMode(enabled: enabled, child: child!),
                child: game,
              ),
      ),
    );
    await tester.pump();
  }

  testWidgets('five casts score catches, boot and miss deterministically', (
    tester,
  ) async {
    FishingCatResult? completed;
    await pumpGame(
      tester,
      kinds: const [
        FishingCatchKind.small,
        FishingCatchKind.golden,
        FishingCatchKind.boot,
        null,
        FishingCatchKind.treasure,
      ],
      onResult: (result) => completed = result,
    );

    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
      await tester.pump();
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.attemptsCompleted, 5);
    expect(completed!.pointsWon, 660);
    expect(completed!.coinsWon, 66);
    expect(completed!.catches['boot'], 1);
    expect(find.byKey(const ValueKey('fishing-result-coins')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid taps consume only one attempt and skip keeps points', (
    tester,
  ) async {
    FishingCatResult? completed;
    await pumpGame(
      tester,
      kinds: const [FishingCatchKind.big, null, null, null, null],
      onResult: (result) => completed = result,
    );

    await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
    await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
    await tester.pump();
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('2/5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('skip-fishing-cat')));
    await tester.pump();
    expect(completed!.attemptsCompleted, 1);
    expect(completed!.pointsWon, 100);
    expect(completed!.coinsWon, 10);
    expect(completed!.skipped, isTrue);
  });

  testWidgets('feedback phase blocks the next cast and stale timer race', (
    tester,
  ) async {
    await pumpGame(
      tester,
      kinds: const [
        FishingCatchKind.big,
        FishingCatchKind.big,
        null,
        null,
        null,
      ],
      onResult: (_) {},
      reduceMotion: false,
      feedbackDuration: const Duration(milliseconds: 400),
    );

    await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
    await tester.pump();
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final feedbackButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cast-fishing-line')),
    );
    expect(feedbackButton.onPressed, isNull);
    expect(find.text('FANG WIRD GEWERTET …'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 401));
    expect(find.text('ANGEL AUSWERFEN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
    await tester.pump();
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('200 P'), findsOneWidget);
  });

  testWidgets(
    'guard completes a cast when Safari ticker stops producing frames',
    (tester) async {
      final tickerEnabled = ValueNotifier(true);
      addTearDown(tickerEnabled.dispose);
      await pumpGame(
        tester,
        kinds: const [FishingCatchKind.golden, null, null, null, null],
        onResult: (_) {},
        tickerEnabled: tickerEnabled,
        recoveryGrace: const Duration(milliseconds: 80),
      );

      await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
      await tester.pump();
      tickerEnabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 281));
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('500 P'), findsOneWidget);
      expect(find.text('ANGEL AUSWERFEN'), findsOneWidget);

      tickerEnabled.value = true;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('500 P'), findsOneWidget);
    },
  );

  testWidgets('three complete five-cast rounds never duplicate attempts', (
    tester,
  ) async {
    final results = <FishingCatResult>[];
    for (var round = 0; round < 3; round++) {
      await pumpGame(
        tester,
        session: BonusGameSession(
          transactionId: 'fishing-repeat-$round',
          game: kFishingCatDefinition,
        ),
        kinds: const [
          FishingCatchKind.small,
          null,
          FishingCatchKind.boot,
          FishingCatchKind.colorful,
          null,
        ],
        onResult: results.add,
      );
      for (var attempt = 0; attempt < 5; attempt++) {
        await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
        await tester.pump();
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
    }

    expect(results, hasLength(3));
    for (final result in results) {
      expect(result.attemptsCompleted, 5);
      expect(result.pointsWon, 40);
      expect(result.catches.values.fold<int>(0, (a, b) => a + b), 3);
    }
  });

  testWidgets('compact phone and tablet layouts have no overflow', (
    tester,
  ) async {
    await pumpGame(
      tester,
      kinds: const [null, null, null, null, null],
      onResult: (_) {},
      size: const Size(320, 568),
    );
    expect(tester.takeException(), isNull);

    await pumpGame(
      tester,
      kinds: const [null, null, null, null, null],
      onResult: (_) {},
      size: const Size(1024, 1366),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('interruption cancels an in-flight cast without using a try', (
    tester,
  ) async {
    await pumpGame(
      tester,
      kinds: const [FishingCatchKind.small, null, null, null, null],
      onResult: (_) {},
      reduceMotion: false,
    );
    await tester.tap(find.byKey(const ValueKey('cast-fishing-line')));
    await tester.pump(const Duration(milliseconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('1/5'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1/5'), findsOneWidget);
    expect(find.text('ANGEL AUSWERFEN'), findsOneWidget);
    expect(find.byKey(const ValueKey('cast-fishing-line')), findsOneWidget);
  });
}
