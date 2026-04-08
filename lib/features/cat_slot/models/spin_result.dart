/// Ergebnis eines einzelnen Spins.
class SpinResult {
  final bool isWin;
  final String message;

  /// Anzahl gewonnener PurrCoins – bei Niederlage 0.
  final int coinsWon;

  const SpinResult({
    required this.isWin,
    required this.message,
    this.coinsWon = 0,
  });
}
