import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class GoldenCatEconomy {
  GoldenCatEconomy._();

  static const List<int> multipliers = [1, 2, 5, 10, 20, 50];
  static const List<int> payouts = [50, 100, 250, 500, 1000, 2500];
  static const List<Duration> switchIntervals = [
    Duration(milliseconds: 700),
    Duration(milliseconds: 550),
    Duration(milliseconds: 400),
    Duration(milliseconds: 300),
    Duration(milliseconds: 220),
    Duration(milliseconds: 160),
  ];

  static int get stages => payouts.length;
  static int payoutForStage(int stage) => payouts[stage - 1];
  static int multiplierForStage(int stage) => multipliers[stage - 1];
  static Duration intervalForStage(int stage) => switchIntervals[stage - 1];
}

/// Pure timing rule shared by the game and timing-boundary tests.
///
/// The image state changes only on animation frames. Input reads the same
/// AnimationController value that painted the current frame, so no hidden
/// random decision or delayed timer callback can change the outcome.
class GoldenCatTiming {
  const GoldenCatTiming._();

  static bool isGoldenAtCycleValue(double value) => value >= .5;
}

class GoldenCatSymbolPolicy {
  final Random _random;
  final int? _fixedCount;
  final List<int>? _sequence;
  int _sequenceIndex = 0;

  GoldenCatSymbolPolicy({Random? random})
    : _random = random ?? Random(),
      _fixedCount = null,
      _sequence = null;

  GoldenCatSymbolPolicy.fixed(int count)
    : assert(count >= 0 && count <= 9),
      _random = Random(0),
      _fixedCount = count,
      _sequence = null;

  GoldenCatSymbolPolicy.sequence(List<int> counts)
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
  Future<int> loadGoldenCatProgress();
  Future<void> saveGoldenCatProgress(int value);
  Future<int> loadFishingCatProgress();
  Future<void> saveFishingCatProgress(int value);
}

class MemoryBonusProgressStore implements BonusProgressStore {
  int value;
  int fishingValue;

  MemoryBonusProgressStore([this.value = 0, this.fishingValue = 0]);

  @override
  Future<int> loadGoldenCatProgress() async => value;

  @override
  Future<void> saveGoldenCatProgress(int value) async {
    this.value = value;
  }

  @override
  Future<int> loadFishingCatProgress() async => fishingValue;

  @override
  Future<void> saveFishingCatProgress(int value) async {
    fishingValue = value;
  }
}

class SharedPreferencesBonusProgressStore implements BonusProgressStore {
  static const _goldenCatKey = 'bonus.golden_cat.progress.v1';
  static const _legacyCatSwitchKey = 'bonus.cat_switch.progress.v1';
  static const _fishingCatKey = 'bonus.fishing_cat.progress.v1';
  SharedPreferencesAsync? _preferences;
  int _fallbackValue = 0;
  int _fishingFallbackValue = 0;

  SharedPreferencesBonusProgressStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<int> loadGoldenCatProgress() async {
    try {
      final current = await _prefs.getInt(_goldenCatKey);
      final value = (current ?? await _prefs.getInt(_legacyCatSwitchKey) ?? 0)
          .clamp(0, 2);
      if (current == null) await _prefs.setInt(_goldenCatKey, value);
      return value;
    } on StateError {
      return _fallbackValue;
    }
  }

  @override
  Future<void> saveGoldenCatProgress(int value) async {
    _fallbackValue = value.clamp(0, 2);
    try {
      await _prefs.setInt(_goldenCatKey, _fallbackValue);
    } on StateError {
      // Widget tests run without a registered platform store.
    }
  }

  @override
  Future<int> loadFishingCatProgress() async {
    try {
      return (await _prefs.getInt(_fishingCatKey) ?? 0).clamp(0, 2);
    } on StateError {
      return _fishingFallbackValue;
    }
  }

  @override
  Future<void> saveFishingCatProgress(int value) async {
    _fishingFallbackValue = value.clamp(0, 2);
    try {
      await _prefs.setInt(_fishingCatKey, _fishingFallbackValue);
    } on StateError {
      // Widget tests run without a registered platform store.
    }
  }
}

class WalletSnapshot {
  final int coins;
  final Set<String> creditedTransactions;

  const WalletSnapshot({
    required this.coins,
    required this.creditedTransactions,
  });
}

abstract interface class WalletStore {
  Future<WalletSnapshot?> load();
  Future<void> save(WalletSnapshot snapshot);
}

class MemoryWalletStore implements WalletStore {
  WalletSnapshot? snapshot;

  MemoryWalletStore([this.snapshot]);

  @override
  Future<WalletSnapshot?> load() async => snapshot;

  @override
  Future<void> save(WalletSnapshot snapshot) async {
    this.snapshot = WalletSnapshot(
      coins: snapshot.coins,
      creditedTransactions: Set.of(snapshot.creditedTransactions),
    );
  }
}

class SharedPreferencesWalletStore implements WalletStore {
  static const _walletKey = 'wallet.snapshot.v1';
  SharedPreferencesAsync? _preferences;
  WalletSnapshot? _fallback;

  SharedPreferencesWalletStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<WalletSnapshot?> load() async {
    try {
      final source = await _prefs.getString(_walletKey);
      if (source == null) return _fallback;
      final json = jsonDecode(source) as Map<String, dynamic>;
      return WalletSnapshot(
        coins: max(0, json['coins'] as int? ?? 0),
        creditedTransactions: Set<String>.from(
          json['creditedTransactions'] as List? ?? const [],
        ),
      );
    } on StateError {
      return _fallback;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(WalletSnapshot snapshot) async {
    final transactions = snapshot.creditedTransactions.toList();
    final retained = transactions.length <= 256
        ? transactions
        : transactions.sublist(transactions.length - 256);
    _fallback = WalletSnapshot(
      coins: max(0, snapshot.coins),
      creditedTransactions: retained.toSet(),
    );
    final source = jsonEncode({
      'coins': _fallback!.coins,
      'creditedTransactions': retained,
    });
    try {
      await _prefs.setString(_walletKey, source);
    } on StateError {
      // Deterministic in-memory fallback for pluginless widget tests.
    }
  }
}
