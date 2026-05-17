import '../models/slot_symbol.dart';
import '../models/symbol_set.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Kanonische PurrCoin-Staffelung (FINAL – set-übergreifend identisch)
//
//   😻  cat_heart      → 10 PurrCoins
//   😹  cat_tears      →  7 PurrCoins
//   😸  cat_joy        →  5 PurrCoins
//   😺  cat_grinning   →  4 PurrCoins
//   🐱  cat            →  3 PurrCoins
//
// Alle Sets MÜSSEN über _buildSymbols(...) konstruiert werden, damit Emoji,
// Label und Payout nicht zwischen Sets driften können.
// ─────────────────────────────────────────────────────────────────────────────

String _asset(String setFolder, String symbolId) =>
    'assets/cat_slot/$setFolder/$symbolId.png';

/// Erzeugt die finale Symbol-Liste für ein Set.
/// Übergib [setFolder] für ein Set mit eigenen Bildern;
/// ohne Argument entsteht das Standard-Set (Emoji-only).
List<SlotSymbol> _buildSymbols({String? setFolder}) {
  String? path(String id) => setFolder == null ? null : _asset(setFolder, id);
  return [
    SlotSymbol(
      id: 'cat',
      emoji: '🐱',
      label: 'Cat',
      payout: 3,
      assetPath: path('cat'),
    ),
    SlotSymbol(
      id: 'cat_grinning',
      emoji: '😺',
      label: 'Grinning Cat',
      payout: 4,
      assetPath: path('cat_grinning'),
    ),
    SlotSymbol(
      id: 'cat_joy',
      emoji: '😸',
      label: 'Cat with Joy',
      payout: 5,
      assetPath: path('cat_joy'),
    ),
    SlotSymbol(
      id: 'cat_tears',
      emoji: '😹',
      label: 'Cat with Tears',
      payout: 7,
      assetPath: path('cat_tears'),
    ),
    SlotSymbol(
      id: 'cat_heart',
      emoji: '😻',
      label: 'Heart-Eyes Cat',
      payout: 10,
      assetPath: path('cat_heart'),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Set 1: Standard (Emojis) – kein assetPath, sofort funktionsfähig
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kStandardSet = SymbolSet(
  id: 'standard',
  label: 'Standard Icons',
  symbols: _buildSymbols(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Set 2: Classic – stilisierte eigene Bilder
// Ordner: assets/cat_slot/classic/
// Solange Bilder fehlen, zeigt SymbolDisplay automatisch das Emoji als Fallback.
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kClassicSet = SymbolSet(
  id: 'classic',
  label: 'Classic',
  symbols: _buildSymbols(setFolder: 'classic'),
);

// ─────────────────────────────────────────────────────────────────────────────
// Set 3: Real Cats – echte Katzenfotos
// Ordner: assets/cat_slot/real_cats/
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kRealCatsSet = SymbolSet(
  id: 'real_cats',
  label: 'Real Cats',
  symbols: _buildSymbols(setFolder: 'real_cats'),
);

// ─────────────────────────────────────────────────────────────────────────────
// Set 4: Custom – eigene kreative Bilder
// Ordner: assets/cat_slot/custom/
// ─────────────────────────────────────────────────────────────────────────────

SymbolSet kCustomSet = SymbolSet(
  id: 'custom',
  label: 'Custom',
  symbols: _buildSymbols(setFolder: 'custom'),
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
