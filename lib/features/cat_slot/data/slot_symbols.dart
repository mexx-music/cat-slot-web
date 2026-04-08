import '../models/slot_symbol.dart';

/// Zentrale Liste aller Katzen-Symbole des Spiels.
///
/// Hier werden später echte Asset-Pfade ergänzt, ohne dass
/// Controller oder Widgets geändert werden müssen.
const List<SlotSymbol> kSlotSymbols = [
  SlotSymbol(id: 'cat',          emoji: '🐱', label: 'Cat',               payout: 3),
  SlotSymbol(id: 'cat_grinning', emoji: '😺', label: 'Grinning Cat',      payout: 4),
  SlotSymbol(id: 'cat_joy',      emoji: '😸', label: 'Cat with Joy',      payout: 5),
  SlotSymbol(id: 'cat_tears',    emoji: '😹', label: 'Cat with Tears',    payout: 7),
  SlotSymbol(id: 'cat_heart',    emoji: '😻', label: 'Heart-Eyes Cat',    payout: 10),
];
