import 'package:catslot/features/cat_slot/bonus/tree_climber_game.dart';
import 'package:catslot/features/cat_slot/data/bonus_games.dart';
import 'package:catslot/features/cat_slot/models/bonus_game.dart';
import 'package:catslot/features/cat_slot/services/tree_climber_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = BonusGameSession(
  transactionId: 'tree-climber-test',
  game: kTreeClimberDefinition,
);

TreeClimberCourse _course({double x = .5, double reach = .2}) =>
    TreeClimberCourse(
      seed: 7,
      sections: [
        for (var i = 1; i <= 10; i++)
          TreeClimberSection(
            number: i,
            baseX: x,
            swayAmplitude: 0,
            swaySpeed: 0,
            phase: 0,
            reachWindow: reach,
          ),
      ],
    );

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    required ValueChanged<TreeClimberResult> onResult,
    TreeClimberCourse? course,
    Size size = const Size(390, 844),
    bool reduceMotion = true,
    ValueNotifier<bool>? tickerEnabled,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final game = TreeClimberGame(
      session: _session,
      onRoundCompleted: (result) async => onResult(result),
      onExit: () {},
      reduceMotion: reduceMotion,
      course: course ?? _course(),
      jumpDuration: const Duration(milliseconds: 120),
      feedbackDuration: Duration.zero,
      recoveryGrace: const Duration(milliseconds: 60),
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

  Future<void> jump(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tree-jump')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('all ten successful jumps reach summit and award 400 points', (
    tester,
  ) async {
    TreeClimberResult? completed;
    await pumpGame(tester, onResult: (result) => completed = result);

    for (var section = 1; section <= 10; section++) {
      await jump(tester);
      if (section.isEven && section < 10) {
        expect(
          find.byKey(const ValueKey('secure-tree-points')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('continue-tree-climb')));
        await tester.pump();
      }
    }
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.sectionsReached, 10);
    expect(completed!.pointsWon, 400);
    expect(completed!.coinsWon, 60);
    expect(completed!.reachedSummit, isTrue);
    expect(find.byKey(const ValueKey('tree-result-coins')), findsOneWidget);
  });

  testWidgets('safe branch offers cash out or continue', (tester) async {
    TreeClimberResult? completed;
    await pumpGame(tester, onResult: (result) => completed = result);

    await jump(tester);
    await jump(tester);
    expect(find.byKey(const ValueKey('secure-tree-points')), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-tree-climb')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('secure-tree-points')));
    await tester.pump();

    expect(completed!.sectionsReached, 2);
    expect(completed!.pointsWon, 20);
    expect(completed!.coinsWon, 2);
    expect(completed!.cashedOut, isTrue);
  });

  testWidgets('first miss uses claw save and second returns a fair result', (
    tester,
  ) async {
    TreeClimberResult? completed;
    await pumpGame(
      tester,
      course: _course(x: .9, reach: .05),
      onResult: (result) => completed = result,
    );

    await jump(tester);
    expect(completed, isNull);
    expect(find.textContaining('Krallen halten'), findsOneWidget);
    expect(find.byKey(const ValueKey('tree-jump')), findsOneWidget);
    await jump(tester);
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.sectionsReached, 0);
    expect(completed!.pointsWon, 0);
    expect(completed!.coinsWon, 0);
  });

  testWidgets('rapid taps start only one jump', (tester) async {
    await pumpGame(tester, onResult: (_) {});

    await tester.tap(find.byKey(const ValueKey('tree-jump')));
    await tester.tap(find.byKey(const ValueKey('tree-jump')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pump();

    expect(find.text('1/10'), findsOneWidget);
  });

  testWidgets('pause safely resolves an in-flight jump without duplication', (
    tester,
  ) async {
    await pumpGame(tester, onResult: (_) {}, reduceMotion: false);
    await tester.tap(find.byKey(const ValueKey('tree-jump')));
    await tester.pump(const Duration(milliseconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('1/10'), findsOneWidget);
    expect(find.byKey(const ValueKey('tree-jump')), findsOneWidget);
  });

  testWidgets('generation guard recovers when ticker frames stop', (
    tester,
  ) async {
    final tickerEnabled = ValueNotifier(true);
    addTearDown(tickerEnabled.dispose);
    await pumpGame(tester, onResult: (_) {}, tickerEnabled: tickerEnabled);

    await tester.tap(find.byKey(const ValueKey('tree-jump')));
    await tester.pump();
    tickerEnabled.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();

    expect(find.text('1/10'), findsOneWidget);
    tickerEnabled.value = true;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1/10'), findsOneWidget);
  });

  testWidgets('compact phone and tablet layouts stay overflow-free', (
    tester,
  ) async {
    await pumpGame(tester, onResult: (_) {}, size: const Size(320, 568));
    expect(tester.takeException(), isNull);

    await pumpGame(tester, onResult: (_) {}, size: const Size(1024, 1366));
    expect(tester.takeException(), isNull);
  });
}
