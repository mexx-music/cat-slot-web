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
- Mouse Hunt 2.0 besitzt eine sichtbare Jagdkatze mit Idle-, Alert-, Pounce-,
  Catch-, Miss- und Celebrate-Zuständen. Treffer werden erst am sichtbaren
  Fangzeitpunkt gewertet; schnelle Mehrfachtaps sind während des Sprungs
  gesperrt.
- Katze, Mäuse, Pfotenstaub und Raumdekoration werden vollständig mit
  Flutter-Zeichenoperationen erzeugt. Es wurden keine externen oder
  urheberrechtlich fremden Grafikassets eingebunden.
- `HunterCatAppearance` trennt Aussehen und Spielmechanik. Damit können
  spätere Katzen-Sets eigene Farben und Accessoires liefern, ohne die
  Mouse-Hunt-Logik zu verändern; Version 2.0 verwendet die Standardkatze.
- Testwerte: 10 PurrCoins je normaler Maus, 50 für die goldene Maus und
  20 PurrCoins Teilnahmebonus. Maximal sind 170 PurrCoins pro Runde möglich.
- Normale Katzen-Auszahlungen bleiben innerhalb der Nicht-Bonus-Spins
  unverändert. Der Bonus-Gate reduziert ihren Gesamtrücklauf von 0,232 auf
  0,22272 PurrCoins pro Spin; zusammen mit den sichtbaren Golden-Cat-Symbolen
  liegt er rechnerisch bei rund 0,21715. Mouse Hunt addiert abhängig vom
  Geschick zwischen 0,8 und maximal 6,8 PurrCoins pro Spin im Langzeitmittel.

### Golden Cat Challenge

- Das stabile Symbol `bonus_golden_cat` kann an jeder der neun sichtbaren
  Rollenpositionen erscheinen. Drei sichtbare Symbole starten die
  **Golden Cat Challenge** direkt – Reihe, Diagonale oder freie Verteilung
  spielen keine Rolle.
- Bei einem oder zwei Symbolen wächst der sichtbare Sammler von 0/3 bis 2/3.
  Dieser Fortschritt wird lokal über `shared_preferences` gespeichert und
  bleibt nach einem Neustart erhalten. Beim Überschreiten von drei wird genau
  eine Runde gestartet und der Rest modulo drei weitergeführt.
- Ein direkter Dreier startet genau eine Runde und verbraucht oder verdoppelt
  den bereits vorhandenen Sammelfortschritt nicht.
- Ein zentrales Katzenbild wechselt framegenau zwischen normaler und goldener
  Katze. Der große `JETZT!`-Button wertet exakt den vom Flutter-Ticker zuletzt
  gezeichneten Zustand aus; es gibt keine nachträgliche Zufallsentscheidung.
- Nach einem Treffer kann der Spieler 50, 100, 250, 500 oder 1.000 PurrCoins
  sichern oder die nächste Stufe riskieren. Nach Level 5 besteht ausdrücklich
  die Wahl zwischen 1.000 Coins und Level 6. Ein Treffer in Level 6 zahlt
  automatisch insgesamt 2.500 Coins aus.
- Die sechs Multiplikatoren ×1/×2/×5/×10/×20/×50 und die tatsächlichen
  Bildwechselintervalle 700/550/400/300/220/160 ms liegen zentral in
  `GoldenCatEconomy`. Eine sechsteilige Leiste zeigt den Fortschritt.
- Ein Fehltreffer verwirft nur den ungesicherten Bonus. Das bestehende Guthaben
  wird nie belastet. Doppeltaps zählen pro Stufe höchstens einmal.
- Bei App-Pause friert die laufende Risikostufe ein und startet nach Rückkehr
  auf derselben Stufe mit einem eindeutigen normalen Katzenbild neu.
- Vorhandene Katzenbilder des aktiven Sets werden wiederverwendet und für die
  Goldkatze warm eingefärbt, mit Leuchten und Medaillon ergänzt. Das bildlose
  Standardset verwendet eine eigene Flutter-Illustration statt Emojis.
- Die reproduzierbare 200.000-Spin-Simulation ergibt ungefähr eine Golden-Cat-
  Runde je 38 Spins (2,6 %) und Mouse Hunt weiterhin etwa je 25 Spins (4 %).
- Bei zufälligem Timing und konsequentem Risiko über alle sechs Stufen beträgt
  der mathematische Golden-Cat-Mittelwert 39,0625 Coins je Challenge
  beziehungsweise rund 1,02 je Spin. Ein geübter Spieler kann deutlich mehr
  erreichen; im theoretischen perfekten Fall wären es 2.500 je Challenge
  beziehungsweise rund 65 Coins je Spin. Die
  Test-Gewinnleiter ist daher bewusst zentral konfigurierbar und vor einer
  Echtgeld- oder kompetitiven Nutzung neu zu balancieren.
- Wenn Mouse Hunt und Golden Cat im selben Spin auslösen, wird Mouse Hunt
  zuerst gespielt; Golden Cat bleibt in der Bonus-Warteschlange erhalten.

### Fishing Cat

- Das dritte stabile Bonussymbol `bonus_fishing_cat` erscheint unabhängig auf
  allen neun Positionen. Drei sichtbare Symbole starten **Fishing Cat** direkt;
  einzelne Symbole füllen den eigenen persistenten `ANGELKATZE 0/3`-Sammler.
- Am ruhigen Teich schwimmen vier Ziele pro Versuch in unterschiedlichen
  Tiefen, Größen und Geschwindigkeiten. Der Spieler hat genau fünf Würfe. Der
  große Button startet nur die sichtbare Hakenbahn; ein Fang entsteht aus der
  tatsächlichen Überschneidung von Haken und Ziel – nie aus einer nachträglichen
  Zufallsentscheidung.
- Kleine, bunte, große und goldene Fische, Schatzkiste, alter Stiefel und eine
  seltene Gummiente besitzen eigene Flutter-Zeichnungen. Die Angelkatze reagiert
  mit Idle-, Alert-, Cast-, Pull-, Success-, Surprise- und Celebrate-Zuständen.
- Die zentrale Punktetabelle liegt in `FishingCatEconomy`: kleiner Fisch 20,
  bunter Fisch 50, großer Fisch 100, Goldfisch 250, Stiefel 0, Schatz 150 und
  Gummiente 10 Punkte. Erst das Rundenergebnis rechnet 10 Punkte in einen
  PurrCoin um; Punkte und Wallet-Coins bleiben technisch getrennt.
- Ein Abbruch behält alle bereits erspielten Punkte. Bei einer App-Unterbrechung
  wird ein laufender Wurf sicher verworfen, ohne einen der fünf Versuche zu
  verbrauchen. Bewegungsreduktion entfernt dekorative Bewegung und Wartezeit,
  während die für das Geschicklichkeitsspiel nötige Fischbewegung erhalten
  bleibt.
- Begegnungen werden vor Rundenbeginn aus einem festen Seed erzeugt. Gleicher
  Seed und gleiche Eingabezeit liefern dasselbe Ergebnis. Mehrfachtaps während
  eines Wurfs sind gesperrt, und das persistente Wallet akzeptiert jede
  Bonus-Transaktion höchstens einmal.
- Die reproduzierbare 200.000-Spin-Simulation ergibt etwa 1,73 % Fishing-Cat-
  Runden, also ungefähr eine Runde je 58 Spins. Bei fünf zufällig vollständig
  gefangenen Zielen liegt der Modellmittelwert bei rund 36 PurrCoins pro Runde
  beziehungsweise 0,62 Coin pro Spin. Der theoretische Höchstfang von fünf
  Goldfischen ergibt 125 Coins beziehungsweise rund 2,17 Coins pro Spin.
- Treffen mehrere Bonusarten zusammen, bleibt die feste Reihenfolge erhalten:
  Mouse Hunt, Golden Cat Challenge, Fishing Cat. Keine Runde überschreibt eine
  andere, und normale Katzen-Auszahlungen bleiben unverändert.

## Wallet-Hinweis

Guthaben und die letzten 256 gutgeschriebenen Bonus-Transaktions-IDs werden in
einem gemeinsamen lokalen Wallet-Snapshot gespeichert. Eine Golden-Cat-
oder Fishing-Cat-Auszahlung wird vor Freigabe des Ergebnisbuttons persistiert
und kann nach einem App-Neustart nicht erneut gutgeschrieben werden. Diese
lokale Persistenz
schützt vor UI-Doppelaufrufen und normalen Neustarts, ist aber nicht gegen
manipulierte Geräte oder Neuinstallation abgesichert. Dafür wäre weiterhin
eine serverseitige Transaktionsquelle erforderlich.

## Qualitätssicherung

```text
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug --no-codesign
```

Die Widget-Tests prüfen kompakte Smartphones, Tablet-Layout, den vollständigen
Spin-Ablauf, Mouse Hunt, Golden Cat und Fishing Cat einschließlich Frame-Grenzen,
Treffer/Fehlschlag, allen Auszahlungsstufen, Risiko, automatischer
Maximalauszahlung, Sammler- und Wallet-Persistenz, Bonus-Warteschlange,
schnellen Mehrfachtaps, kleinen sowie großen Displays und App-Unterbrechung.
Simulations- und Auszahlungstests sichern Bonusfrequenz und bestehende
Gewinnwerte gegen unbeabsichtigte Änderungen ab.
