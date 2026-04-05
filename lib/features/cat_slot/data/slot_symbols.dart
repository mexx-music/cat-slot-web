import '../models/slot_symbol.dart';

/// Zentrale Liste aller Katzen-Symbole des Spiels.
///
/// Hier werden später echte Asset-Pfade ergänzt, ohne dass
/// Controller oder Widgets geändert werden müssen.
const List<SlotSymbol> kSlotSymbols = [
  SlotSymbol(id: 'cat',          emoji: '🐱', label: 'Cat'),
  SlotSymbol(id: 'cat_grinning', emoji: '😺', label: 'Grinning Cat'),
  SlotSymbol(id: 'cat_joy',      emoji: '😸', label: 'Cat with Joy'),
  SlotSymbol(id: 'cat_tears',    emoji: '😹', label: 'Cat with Tears'),
  SlotSymbol(id: 'cat_heart',    emoji: '😻', label: 'Heart-Eyes Cat'),
];
