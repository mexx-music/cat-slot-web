/// Repräsentiert ein einzelnes Slot-Symbol.
///
/// Minimal gehalten – kann später um ein Asset-Pfad-Feld erweitert werden,
/// ohne dass sich der Rest des Projekts ändern muss.
class SlotSymbol {
  /// Eindeutiger Bezeichner, z. B. 'cat_grinning'.
  final String id;

  /// Emoji-Darstellung – solange noch keine echten Assets verwendet werden.
  final String emoji;

  /// Lesbarer Name, z. B. für Accessibility oder spätere Labels.
  final String label;

  const SlotSymbol({
    required this.id,
    required this.emoji,
    required this.label,
  });
}
