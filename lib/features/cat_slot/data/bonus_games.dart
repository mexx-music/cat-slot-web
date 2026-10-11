import '../models/bonus_game.dart';

const String kMouseHuntGameId = 'mouse_hunt';
const String kMouseBonusSymbolId = 'bonus_mouse';
const String kGoldenCatGameId = 'golden_cat_challenge';
const String kGoldenCatBonusSymbolId = 'bonus_golden_cat';
const String kFishingCatGameId = 'fishing_cat';
const String kFishingCatBonusSymbolId = 'bonus_fishing_cat';
const String kTreeClimberGameId = 'tree_climber';
const String kTreeClimberBonusSymbolId = 'bonus_tree_climber';

const BonusGameDefinition kMouseHuntDefinition = BonusGameDefinition(
  id: kMouseHuntGameId,
  symbolId: kMouseBonusSymbolId,
  label: 'Mouse Hunt',
  icon: '🐭',
);

const BonusGameDefinition kGoldenCatDefinition = BonusGameDefinition(
  id: kGoldenCatGameId,
  symbolId: kGoldenCatBonusSymbolId,
  label: 'Golden Cat Challenge',
  icon: 'GOLD',
);

const BonusGameDefinition kFishingCatDefinition = BonusGameDefinition(
  id: kFishingCatGameId,
  symbolId: kFishingCatBonusSymbolId,
  label: 'Fishing Cat',
  icon: 'FISH',
);

const BonusGameDefinition kTreeClimberDefinition = BonusGameDefinition(
  id: kTreeClimberGameId,
  symbolId: kTreeClimberBonusSymbolId,
  label: 'Tree Climber',
  icon: 'TREE',
);

/// Small registry kept deliberately simple so future games only need metadata
/// plus their own game component.
const List<BonusGameDefinition> kBonusGames = [
  kMouseHuntDefinition,
  kGoldenCatDefinition,
  kFishingCatDefinition,
  kTreeClimberDefinition,
];

BonusGameDefinition? bonusGameForSymbolId(String symbolId) {
  for (final game in kBonusGames) {
    if (game.symbolId == symbolId) return game;
  }
  return null;
}
