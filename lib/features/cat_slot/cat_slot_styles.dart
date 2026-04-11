import 'package:flutter/material.dart';

class CatSlotStyles {
  CatSlotStyles._();

  // Farben
  static const Color scaffoldBackground = Color(0xFFF8F4FF);
  static const Color reelBackground    = Color(0xBBFFFFFF); // halbtransparent → Background scheint durch
  static const Color reelBorder        = Color(0x44FFFFFF); // weicher weißer Rand
  static const Color reelShadow        = Color(0x33000000);

  // Abstände
  static const double pagePadding       = 24;
  static const double reelSpacing       = 12;
  static const double sectionSpacing    = 28;
  static const double titleSpacing      = 30;

  // Text
  static const double titleFontSize       = 42;
  static const double buttonFontSize      = 24;
  static const double resultFontSize      = 28;
  static const double reelEmojiFontSize   = 56;

  /// Einheitliche sichtbare Symbolfläche für Emojis und Bilder.
  /// Beide werden in diesem quadratischen Bereich zentriert dargestellt.
  static const double symbolDisplaySize   = 62.0;
  /// Emoji-Schriftgröße innerhalb der symbolDisplaySize-Box.
  /// Leicht kleiner als früher damit Emojis nicht größer wirken als Bilder.
  static const double symbolEmojiFontSize = 44.0;

  // Button-Größen
  static const double buttonWidth       = 220;
  static const double buttonHeight      = 62;

  // Reel-Box
  static const double reelWidth         = 110;
  static const double reelSymbolSize    = 80;   // Höhe eines einzelnen Symbols im Band
  static const double reelWindowHeight  = reelSymbolSize * 3; // sichtbares Fenster = 3 Symbole
  static const double reelHeight        = reelWindowHeight;
  static const double reelBorderRadius  = 18;

  // Gesamtbreite der drei Rollen (3 × reelWidth + 2 × reelSpacing)
  static const double reelRowWidth      = reelWidth * 3 + reelSpacing * 2;

  // Button
  static const double buttonBorderRadius = 16;

  // Balance
  static const double balanceFontSize  = 20;
  static const Color  balanceColor     = Color(0xFF7B5EA7);

  // ── Text auf dunklem Hintergrund ─────────────────────────────
  static const Color  darkBgTextColor      = Colors.white;
  static const Color  darkBgTextGlowColor  = Color(0xFFD0AAFF); // helles Lila
  // Shadow-Liste für gut lesbare Schrift auf dunklem Bild
  static const List<Shadow> darkBgTextShadows = [
    Shadow(color: Color(0xFF9B59B6), blurRadius: 12),
    Shadow(color: Color(0xFF6C3483), blurRadius: 28),
    Shadow(color: Color(0x88000000), blurRadius: 4,  offset: Offset(1, 1)),
  ];

  // Reset-Button
  static const Color  resetButtonColor = Color(0xFF4CAF50);

  // Gewinnlinie
  static const Color  winLineColor      = Color(0xFFFFD700); // Gold
  static const double winLineThickness  = 3.0;
  static const double winLineGlowSpread = 18.0;

  // Win-Pulse (Blinken der mittleren Gewinnsymbole)
  static const Color  winPulseColor     = Color(0xFFFFD700); // Gold

  // Win-Overlay
  static const Color  winOverlayBg      = Color(0xCC1A0A3B);
  static const Color  winOverlayText    = Color(0xFFFFD700);
  static const double winOverlayFontSize = 52;

  // Coin-Fly-Animation
  static const double   coinSize         = 36.0;  // Flug-Münzen
  static const double   heroCoinSize     = 130.0; // große Hero-Coin vor dem Flug
  static const int      coinCount        = 7;
  static const Duration coinHeroDuration = Duration(milliseconds: 600);  // Hero einblenden
  static const Duration coinHoldDuration = Duration(milliseconds: 520);  // sichtbare Pause
  static const Duration coinFlyDuration  = Duration(milliseconds: 820);  // Flugdauer pro Münze
  static const int      coinStaggerMs    = 55;    // Versatz zwischen Münzen
}

