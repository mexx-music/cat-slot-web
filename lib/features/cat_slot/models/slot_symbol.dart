/// Repräsentiert ein einzelnes Slot-Symbol.
///
/// Minimal gehalten – kann später um ein Asset-Pfad-Feld erweitert werden,
/// ohne dass sich der Rest des Projekts ändern muss.
class SlotSymbol {
  final String id;
  final String emoji;
  final String label;

  /// Anzahl PurrCoins bei 3 gleichen Symbolen.
  final int payout;

  const SlotSymbol({
    required this.id,
    required this.emoji,
    required this.label,
    required this.payout,
  });
}
