/// Repräsentiert ein einzelnes Slot-Symbol.
class SlotSymbol {
  final String id;
  final String label;
  final int payout;

  /// Emoji-Darstellung – wird verwendet, wenn kein assetPath gesetzt ist.
  final String emoji;

  /// Optionaler Asset-Pfad für echte Bilder (z. B. 'assets/cats/cat_01.png').
  /// Wenn gesetzt, wird das Bild angezeigt statt des Emojis.
  final String? assetPath;

  const SlotSymbol({
    required this.id,
    required this.label,
    required this.payout,
    required this.emoji,
    this.assetPath,
  });
}
