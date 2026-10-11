import '../models/bonus_game.dart';

const String kMouseHuntGameId = 'mouse_hunt';
const String kMouseBonusSymbolId = 'bonus_mouse';

const BonusGameDefinition kMouseHuntDefinition = BonusGameDefinition(
  id: kMouseHuntGameId,
  symbolId: kMouseBonusSymbolId,
  label: 'Mouse Hunt',
  icon: '🐭',
);

/// Small registry kept deliberately simple so future games only need metadata
/// plus their own game component.
const List<BonusGameDefinition> kBonusGames = [kMouseHuntDefinition];

BonusGameDefinition? bonusGameForSymbolId(String symbolId) {
  for (final game in kBonusGames) {
    if (game.symbolId == symbolId) return game;
  }
  return null;
}
