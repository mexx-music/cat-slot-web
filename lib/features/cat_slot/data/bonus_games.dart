import '../models/bonus_game.dart';

const String kMouseHuntGameId = 'mouse_hunt';
const String kMouseBonusSymbolId = 'bonus_mouse';
const String kCatSwitchGameId = 'cat_switch';
const String kCatSwitchBonusSymbolId = 'bonus_cat_switch';

const BonusGameDefinition kMouseHuntDefinition = BonusGameDefinition(
  id: kMouseHuntGameId,
  symbolId: kMouseBonusSymbolId,
  label: 'Mouse Hunt',
  icon: '🐭',
);

const BonusGameDefinition kCatSwitchDefinition = BonusGameDefinition(
  id: kCatSwitchGameId,
  symbolId: kCatSwitchBonusSymbolId,
  label: 'Cat Switch',
  icon: 'CAT',
);

/// Small registry kept deliberately simple so future games only need metadata
/// plus their own game component.
const List<BonusGameDefinition> kBonusGames = [
  kMouseHuntDefinition,
  kCatSwitchDefinition,
];

BonusGameDefinition? bonusGameForSymbolId(String symbolId) {
  for (final game in kBonusGames) {
    if (game.symbolId == symbolId) return game;
  }
  return null;
}
