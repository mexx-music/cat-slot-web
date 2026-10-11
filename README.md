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

## Bonusspiele

- Drei stabile `bonus_mouse`-Symbol-IDs starten kostenlos **Mouse Hunt**.
- Die unabhängige Auslösechance beträgt 4 % pro Spin (im Mittel 1:25).
- Mouse Hunt dauert 15 Sekunden und enthält elf ruhige Maus-Begegnungen,
  darunter genau eine goldene Maus.
- Testwerte: 10 PurrCoins je normaler Maus, 50 für die goldene Maus und
  20 PurrCoins Teilnahmebonus. Maximal sind 170 PurrCoins pro Runde möglich.
- Normale Katzen-Auszahlungen bleiben innerhalb der Nicht-Bonus-Spins
  unverändert. Der Bonus-Gate reduziert ihren Gesamtrücklauf von 0,232 auf
  0,22272 PurrCoins pro Spin; der Bonus addiert abhängig vom Geschick zwischen
  0,8 und maximal 6,8 PurrCoins pro Spin im Langzeitmittel.

## Wallet-Hinweis

Die aktuelle Wallet ist weiterhin sitzungsgebunden und wird bei einem echten
App-Neustart nicht dauerhaft gespeichert. Bonus-Runden verwenden innerhalb der
laufenden Sitzung eindeutige Transaktions-IDs, sodass Lifecycle- und doppelte
UI-Callbacks keine Belohnung zweimal gutschreiben können. Für dauerhafte,
geräteübergreifend sichere Guthabenstände fehlt noch ein persistentes Wallet-
Repository beziehungsweise eine serverseitige, idempotente Transaktionsquelle;
eine rein lokale Speicherung wäre manipulierbar und wurde deshalb nicht als
„sichere“ Persistenz ausgegeben.

## Qualitätssicherung

```text
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug --no-codesign
```

Die Widget-Tests prüfen kompakte Smartphones, Tablet-Layout, den vollständigen
Spin-Ablauf und Mouse Hunt einschließlich Überspringen und App-Unterbrechung.
Simulations- und Auszahlungstests sichern Bonusfrequenz und bestehende
Gewinnwerte gegen unbeabsichtigte Änderungen ab.
