import '../models/slot_symbol.dart';
import 'slot_symbol_sets.dart';

/// Bequemer Alias auf die Symbol-Liste des aktuell aktiven Sets.
/// Bestehender Code kann weiterhin [kSlotSymbols] verwenden.
List<SlotSymbol> get kSlotSymbols => kActiveSymbolSet.symbols;
