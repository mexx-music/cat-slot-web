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
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: FishingCatGame(
          session: _session,
          onRoundCompleted: (result) async => onResult(result),
          onExit: () {},
          reduceMotion: reduceMotion,
          castDuration: const Duration(milliseconds: 200),
          feedbackDuration: Duration.zero,
          encounters: [
            for (var i = 0; i < 5; i++)
              [
                _target(
                  kinds[i] ?? FishingCatchKind.small,
                  hittable: kinds[i] != null,
                ),
              ],
          ],
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
    expect(completed!.pointsWon, 420);
    expect(completed!.coinsWon, 42);
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
    await tester.pump();
    expect(find.byKey(const ValueKey('cast-fishing-line')), findsOneWidget);
  });
}
