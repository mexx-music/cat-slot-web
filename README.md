# CatSlot

CatSlot ist ein kleines, gemütliches Flutter-Spiel mit Katzen-Symbolen,
mehreren visuellen Symbolsets und einer dreistufigen Gewinnanimation.

## Gestaltung

- Responsive Einspalten-Ansicht für Smartphones und Zweispalten-Ansicht für
  Tablets.
- Codebasierte Licht-, Glas- und Pfotendetails ohne zusätzliche große
  Grafikdateien.
- Performantes Endlos-Symbolband mit eigenständigen Repaint-Bereichen.
- Humorvolle Katzenreaktionen auf Gewinne, Fast-Treffer und normale Spins.
- Reduzierte Animationen werden über die Systemeinstellung berücksichtigt.

## Spielregeln

Die bestehende Spielmathematik ist bewusst unverändert:

- Startguthaben: 10 PurrCoins
- Kosten pro Spin: 1 PurrCoin
- Gewinn: drei identische Symbole
- Auszahlungen: 3, 4, 5, 7 oder 10 PurrCoins je nach Symbol

## Qualitätssicherung

```text
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug --no-codesign
```

Die Widget-Tests prüfen kompakte Smartphones, Tablet-Layout und den
vollständigen Spin-Ablauf. Die Auszahlungstests sichern alle bestehenden
Gewinnwerte gegen unbeabsichtigte Änderungen ab.
