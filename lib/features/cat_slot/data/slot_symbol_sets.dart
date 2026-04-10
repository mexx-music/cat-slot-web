import '../models/slot_symbol.dart';
import '../models/symbol_set.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hilfsfunktion: Asset-Pfad für ein Symbol in einem Set
// ─────────────────────────────────────────────────────────────────────────────

String _asset(String setFolder, String symbolId) =>
    'assets/cat_slot/$setFolder/$symbolId.png';

// ─────────────────────────────────────────────────────────────────────────────
// Set 1: Standard (Emojis) – kein assetPath, sofort funktionsfähig
// ─────────────────────────────────────────────────────────────────────────────

const SymbolSet kStandardSet = SymbolSet(
  id: 'standard',
  label: 'Standard Icons',
  symbols: [
    SlotSymbol(id: 'cat',          emoji: '🐱', label: 'Cat',            payout: 3),
    SlotSymbol(id: 'cat_grinning', emoji: '😺', label: 'Grinning Cat',   payout: 4),
    SlotSymbol(id: 'cat_joy',      emoji: '😸', label: 'Cat with Joy',   payout: 5),
    SlotSymbol(id: 'cat_tears',    emoji: '😹', label: 'Cat with Tears', payout: 7),
    SlotSymbol(id: 'cat_heart',    emoji: '😻', label: 'Heart-Eyes Cat', payout: 10),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Set 2: Classic – stilisierte eigene Bilder
// Ordner: assets/cat_slot/classic/
// Dateien: cat.png, cat_grinning.png, cat_joy.png, cat_tears.png, cat_heart.png
// Solange Bilder fehlen, zeigt SymbolDisplay automatisch das Emoji als Fallback.
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kClassicSet = SymbolSet(
  id: 'classic',
  label: 'Classic',
  symbols: [
    SlotSymbol(id: 'cat',          emoji: '🐱', label: 'Cat',            payout: 3,  assetPath: _asset('classic', 'cat')),
    SlotSymbol(id: 'cat_grinning', emoji: '😺', label: 'Grinning Cat',   payout: 4,  assetPath: _asset('classic', 'cat_grinning')),
    SlotSymbol(id: 'cat_joy',      emoji: '😸', label: 'Cat with Joy',   payout: 5,  assetPath: _asset('classic', 'cat_joy')),
    SlotSymbol(id: 'cat_tears',    emoji: '😹', label: 'Cat with Tears', payout: 7,  assetPath: _asset('classic', 'cat_tears')),
    SlotSymbol(id: 'cat_heart',    emoji: '😻', label: 'Heart-Eyes Cat', payout: 10, assetPath: _asset('classic', 'cat_heart')),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Set 3: Real Cats – echte Katzenfotos
// Ordner: assets/cat_slot/real_cats/
// Dateien: cat.png, cat_grinning.png, cat_joy.png, cat_tears.png, cat_heart.png
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kRealCatsSet = SymbolSet(
  id: 'real_cats',
  label: 'Real Cats',
  symbols: [
    SlotSymbol(id: 'cat',          emoji: '🐱', label: 'Cat',            payout: 3,  assetPath: _asset('real_cats', 'cat')),
    SlotSymbol(id: 'cat_grinning', emoji: '😺', label: 'Grinning Cat',   payout: 4,  assetPath: _asset('real_cats', 'cat_grinning')),
    SlotSymbol(id: 'cat_joy',      emoji: '😸', label: 'Cat with Joy',   payout: 5,  assetPath: _asset('real_cats', 'cat_joy')),
    SlotSymbol(id: 'cat_tears',    emoji: '😹', label: 'Cat with Tears', payout: 7,  assetPath: _asset('real_cats', 'cat_tears')),
    SlotSymbol(id: 'cat_heart',    emoji: '😻', label: 'Heart-Eyes Cat', payout: 10, assetPath: _asset('real_cats', 'cat_heart')),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Set 4: Custom – eigene kreative Bilder
// Ordner: assets/cat_slot/custom/
// Dateien: cat.png, cat_grinning.png, cat_joy.png, cat_tears.png, cat_heart.png
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kCustomSet = SymbolSet(
  id: 'custom',
  label: 'Custom',
  symbols: [
    SlotSymbol(id: 'cat',          emoji: '🐱', label: 'Cat',            payout: 3,  assetPath: _asset('custom', 'cat')),
    SlotSymbol(id: 'cat_grinning', emoji: '😺', label: 'Grinning Cat',   payout: 4,  assetPath: _asset('custom', 'cat_grinning')),
    SlotSymbol(id: 'cat_joy',      emoji: '😸', label: 'Cat with Joy',   payout: 5,  assetPath: _asset('custom', 'cat_joy')),
    SlotSymbol(id: 'cat_tears',    emoji: '😹', label: 'Cat with Tears', payout: 7,  assetPath: _asset('custom', 'cat_tears')),
    SlotSymbol(id: 'cat_heart',    emoji: '😻', label: 'Heart-Eyes Cat', payout: 10, assetPath: _asset('custom', 'cat_heart')),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Alle verfügbaren Sets
// ─────────────────────────────────────────────────────────────────────────────

List<SymbolSet> kAllSymbolSets = [
  kStandardSet,
  kClassicSet,
  kRealCatsSet,
  kCustomSet,
];

/// Das aktuell aktive Set.
/// Zum Wechseln einfach z. B. auf kClassicSet, kRealCatsSet oder kCustomSet ändern.
/// Solange ein Ordner noch keine Bilder enthält, zeigt SymbolDisplay automatisch
/// das Emoji als Fallback – das Spiel bleibt also immer funktionsfähig.
SymbolSet kActiveSymbolSet = kStandardSet;
