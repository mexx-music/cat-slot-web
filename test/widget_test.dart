import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:catslot/features/cat_slot/cat_slot_page.dart';

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    required Size logicalSize,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: CatSlotPage()));
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
    await pumpGame(tester, logicalSize: const Size(390, 844));

    await tester.tap(find.text('SPIN'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('PURRING'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
