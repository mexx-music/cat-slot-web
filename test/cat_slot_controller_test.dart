import 'dart:math';

import 'package:catslot/features/cat_slot/cat_slot_controller.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final List<int> values;
  int _index = 0;

  _SequenceRandom(this.values);

  @override
  bool nextBool() => nextInt(2).isEven;

  @override
  double nextDouble() => nextInt(1000) / 1000;

  @override
  int nextInt(int max) => values[_index++ % values.length] % max;
}

CatSlotController _controller(Random random) => CatSlotController(
  random: random,
  spinLeadIn: Duration.zero,
  reelStopGap: Duration.zero,
);

void main() {
  test('settles a win exactly once when the result is known', () async {
    final controller = _controller(const _FixedRandom(0));
    final stops = <int>[];
    final settled = <int>[];

    await controller.spin(
      () {},
      onReelStop: stops.add,
      onWinSettled: settled.add,
    );

    expect(controller.latestWin, 3);
    expect(controller.coins, 12); // 10 - 1 spin + 3 payout
    expect(stops, [0, 1, 2]);
    expect(settled, [3]);
  });

  test('rapid duplicate spin requests cannot double-credit a result', () async {
    final controller = _controller(const _FixedRandom(0));

    final first = controller.spin(() {});
    final overlapping = controller.spin(() {});
    await Future.wait([first, overlapping]);

    expect(controller.coins, 12);
    expect(controller.latestWin, 3);

    await controller.spin(() {});
    expect(controller.coins, 14); // a second real spin adds one further net +2
  });

  test('a mixed result keeps the unchanged one-coin spin cost', () async {
    final controller = _controller(_SequenceRandom([0, 1, 2, 0, 1, 2]));

    await controller.spin(() {});

    expect(controller.slots.toSet().length, 3);
    expect(controller.latestWin, 0);
    expect(controller.coins, 9);
  });
}
