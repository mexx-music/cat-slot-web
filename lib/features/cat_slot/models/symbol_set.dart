import 'slot_symbol.dart';

/// Beschreibt ein vollständiges Symbol-Set für Cat Slot.
///
/// Jedes Set hat eine stabile [id], einen [label] für die UI
/// und eine [symbols]-Liste mit genau den gleichen IDs wie das Standard-Set.
/// Payouts stecken im Symbol – sie bleiben set-übergreifend gleich.
class SymbolSet {
  final String id;
  final String label;
  final List<SlotSymbol> symbols;

  const SymbolSet({
    required this.id,
    required this.label,
    required this.symbols,
  });

  /// Bequemer Zugriff auf ein Symbol per ID.
  /// Gibt null zurück, wenn die ID nicht im Set vorhanden ist.
  SlotSymbol? findById(String symbolId) {
    for (final s in symbols) {
      if (s.id == symbolId) return s;
    }
    return null;
  }
}
