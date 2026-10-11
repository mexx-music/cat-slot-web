/// Stable metadata for a bonus game and the reel symbol that activates it.
class BonusGameDefinition {
  final String id;
  final String symbolId;
  final String label;
  final String icon;

  const BonusGameDefinition({
    required this.id,
    required this.symbolId,
    required this.label,
    required this.icon,
  });
}

/// One uniquely identifiable bonus round.
class BonusGameSession {
  final String transactionId;
  final BonusGameDefinition game;

  const BonusGameSession({required this.transactionId, required this.game});
}

class BonusGameResult {
  final int normalCaught;
  final int goldenCaught;
  final int coinsWon;
  final bool skipped;

  const BonusGameResult({
    required this.normalCaught,
    required this.goldenCaught,
    required this.coinsWon,
    required this.skipped,
  });
}

class GoldenCatResult {
  final int stageReached;
  final int coinsWon;
  final bool cashedOut;
  final bool missed;

  const GoldenCatResult({
    required this.stageReached,
    required this.coinsWon,
    required this.cashedOut,
    required this.missed,
  });
}
