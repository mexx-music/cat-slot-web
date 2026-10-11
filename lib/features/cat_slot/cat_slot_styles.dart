import 'package:flutter/material.dart';

class CatSlotStyles {
  CatSlotStyles._();

  // Farben
  static const Color scaffoldBackground = Color(0xFFF8F4FF);
  static const Color reelBackground = Color(
    0xCC0D0722,
  ); // dunkles Glas – Casino-Look
  static const Color reelBorder = Color(0xAAD4AF37); // Antik-Gold
  static const Color reelShadow = Color(0x88000000);
  static const Color goldAccent = Color(0xFFD4AF37); // Vegas-Gold
  static const Color panelBg = Color(0xAA0D0722); // Frosted-Glass-Panel

  // Abstände
  static const double pagePadding = 24;
  static const double reelSpacing = 8;
  static const double sectionSpacing = 28;
  static const double titleSpacing = 30;

  // Text
  static const double titleFontSize = 36;
  static const double buttonFontSize = 24;
  static const double resultFontSize = 28;
  static const double reelEmojiFontSize = 56;

  /// Einheitliche sichtbare Symbolfläche für Emojis und Bilder.
  /// Beide werden in diesem quadratischen Bereich zentriert dargestellt.
  static const double symbolDisplaySize = 76.0;

  /// Emoji-Schriftgröße innerhalb der symbolDisplaySize-Box.
  static const double symbolEmojiFontSize = 54.0;

  // Button-Größen
  static const double buttonWidth = 220;
  static const double buttonHeight = 62;

  // Reel-Box
  static const double reelWidth = 110;
  static const double reelSymbolSize =
      92; // Höhe eines einzelnen Symbols im Band
  static const double reelWindowHeight =
      reelSymbolSize * 3; // sichtbares Fenster = 3 Symbole
  static const double reelHeight = reelWindowHeight;
  static const double reelBorderRadius = 20;

  // Gesamtbreite der drei Rollen (3 × reelWidth + 2 × reelSpacing)
  static const double reelRowWidth = reelWidth * 3 + reelSpacing * 2;

  // Button
  static const double buttonBorderRadius = 16;

  // Balance
  static const double balanceFontSize = 20;
  static const Color balanceColor = Color(0xFF7B5EA7);

  // ── Text auf dunklem Hintergrund ─────────────────────────────
  static const Color darkBgTextColor = Colors.white;
  static const Color darkBgTextGlowColor = Color(0xFFD0AAFF); // helles Lila
  // Shadow-Liste für gut lesbare Schrift auf dunklem Bild
  static const List<Shadow> darkBgTextShadows = [
    Shadow(color: Color(0xFF9B59B6), blurRadius: 12),
    Shadow(color: Color(0xFF6C3483), blurRadius: 28),
    Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(1, 1)),
  ];

  // Reset-Button
  static const Color resetButtonColor = Color(0xFF4CAF50);

  // Gewinnlinie
  static const Color winLineColor = Color(0xFFFFD700); // Gold
  static const double winLineThickness = 3.0;
  static const double winLineGlowSpread = 18.0;

  // Win-Pulse (Blinken der mittleren Gewinnsymbole)
  static const Color winPulseColor = Color(0xFFFFD700); // Gold

  // Win-Overlay
  static const Color winOverlayBg = Color(0xCC1A0A3B);
  static const Color winOverlayText = Color(0xFFFFD700);
  static const double winOverlayFontSize = 52;

  // ── Premium Win-Effekt (Phase 1 + Phase 2) ────────────────────
  /// Kurzer Licht-/Pfotenakzent unmittelbar nach dem letzten Rollenstopp.
  static const Duration winRevealDuration = Duration(milliseconds: 480);

  /// Einblendung des kompakten Panels für größere Gewinne.
  static const Duration winPanelDuration = Duration(milliseconds: 360);

  /// Dauer der Betragszählung im Panel.
  static const Duration winCounterDuration = Duration(milliseconds: 620);

  /// Kleine Gewinne starten den visuellen Coin-Flug automatisch nach dem
  /// kurzen Symbol-Reveal, ohne den Spielfluss durch ein Modal zu blockieren.
  static const Duration smallWinAutoCollectDelay = Duration(milliseconds: 420);

  /// Schwellwerte für die Win-Tier-Anzeige (Beträge in PurrCoins).
  /// Mit der finalen 3/4/5/7/10-Staffelung ergibt das:
  ///   3, 4    → YOU WIN     (🐱, 😺)
  ///   5, 7    → BIG WIN     (😸, 😹)
  ///   10      → MEGA WIN    (😻 – Top-Cat-Combo)
  static const int winTierBig = 5;
  static const int winTierMega = 10;

  /// Sekundärer warmer Gold-Ton für Premium-Glow.
  static const Color winGoldDeep = Color(0xFFB8860B);
  static const Color winGoldLight = Color(0xFFFFF1A8);

  // Coin-Fly-Animation
  static const double coinSize = 34.0;
  static const int coinCount = 5;
  static const Duration coinFlyDuration = Duration(milliseconds: 720);
  static const double coinStaggerFraction = 0.075;

  /// Größe des Impact-Bursts am Credits-Ziel bei Münz-Ankunft.
  static const double coinImpactBurstSize = 78.0;
}
