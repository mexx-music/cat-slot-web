import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class CatSwitchEconomy {
  CatSwitchEconomy._();

  static const int rounds = 10;
  static const int participationCoins = 20;
  static const int correctCoins = 8;
  static const int perfectBonusCoins = 20;

  static int rewardFor(int correct) =>
      participationCoins +
      correct * correctCoins +
      (correct == rounds ? perfectBonusCoins : 0);

  static const int maximumReward = 120;
}

class CatSwitchSymbolPolicy {
  final Random _random;
  final int? _fixedCount;
  final List<int>? _sequence;
  int _sequenceIndex = 0;

  CatSwitchSymbolPolicy({Random? random})
    : _random = random ?? Random(),
      _fixedCount = null,
      _sequence = null;

  CatSwitchSymbolPolicy.fixed(int count)
    : assert(count >= 0 && count <= 9),
      _random = Random(0),
      _fixedCount = count,
      _sequence = null;

  CatSwitchSymbolPolicy.sequence(List<int> counts)
    : assert(counts.isNotEmpty),
      assert(counts.every((count) => count >= 0 && count <= 9)),
      _random = Random(0),
      _fixedCount = null,
      _sequence = List.unmodifiable(counts);

  int visibleCount() {
    if (_fixedCount case final count?) return count;
    if (_sequence case final sequence?) {
      final count = sequence[_sequenceIndex % sequence.length];
      _sequenceIndex++;
      return count;
    }
    final roll = _random.nextDouble();
    if (roll < 0.003) return 3;
    if (roll < 0.015) return 2;
    if (roll < 0.060) return 1;
    return 0;
  }

  static const double directBonusProbability = 0.003;
  static const double expectedCollectorPointsPerSpin = 0.045 + 2 * 0.012;
  static const double expectedBonusRoundsPerSpin =
      directBonusProbability + expectedCollectorPointsPerSpin / 3;
}

class VisibleBonusCounter {
  const VisibleBonusCounter._();

  static int count(List<List<String>> reels, String symbolId) => reels
      .expand((reel) => reel)
      .where((visibleId) => visibleId == symbolId)
      .length;
}

abstract interface class BonusProgressStore {
  Future<int> loadCatSwitchProgress();
  Future<void> saveCatSwitchProgress(int value);
}

class MemoryBonusProgressStore implements BonusProgressStore {
  int value;

  MemoryBonusProgressStore([this.value = 0]);

  @override
  Future<int> loadCatSwitchProgress() async => value;

  @override
  Future<void> saveCatSwitchProgress(int value) async {
    this.value = value;
  }
}

class SharedPreferencesBonusProgressStore implements BonusProgressStore {
  static const _catSwitchKey = 'bonus.cat_switch.progress.v1';
  SharedPreferencesAsync? _preferences;
  int _fallbackValue = 0;

  SharedPreferencesBonusProgressStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<int> loadCatSwitchProgress() async {
    try {
      return ((await _prefs.getInt(_catSwitchKey)) ?? 0).clamp(0, 2);
    } on StateError {
      // Widget-Tests haben ohne registriertes Plattform-Plugin keinen Store.
      // Auf Android, iOS und Web ist das Plugin registriert; die In-Memory-
      // Rückfallebene hält reine Dart-/Widget-Tests dennoch deterministisch.
      return _fallbackValue;
    }
  }

  @override
  Future<void> saveCatSwitchProgress(int value) async {
    _fallbackValue = value.clamp(0, 2);
    try {
      await _prefs.setInt(_catSwitchKey, _fallbackValue);
    } on StateError {
      // Siehe loadCatSwitchProgress: ausschließlich für pluginlose Tests.
    }
  }
}
