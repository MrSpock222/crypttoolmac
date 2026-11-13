# PROJECT_STATE – CrypTool für macOS

Stabiler Ist-Zustand. Verlauf steht im Git-Log, nicht hier.

## Inhaltsverzeichnis
1. [Zweck](#1-zweck)
2. [Architektur](#2-architektur)
3. [Setup, Build, Tests](#3-setup-build-tests)
4. [Funktionsstand](#4-funktionsstand)
5. [Wichtige Entscheidungen und fragile Stellen](#5-wichtige-entscheidungen-und-fragile-stellen)

---

## 1. Zweck
Native Apple-Silicon-Portierung des Windows-Lernprogramms **CrypTool 1** (https://github.com/cryptool-org/cryptool1).
Ziel: im Unterricht neben der Windows-Version nutzbar – gleiche Funktionen, gleiche Menüs/Dialoge,
gleiche Online-Hilfe, gleiche Verfahren und Ergebnisse. **Englischsprachig**, Texte wie die englische
CT1-Fassung (bis einschließlich Release v1.4.0 deutsch).

## 2. Architektur
Swift Package (`Package.swift`, swift-tools 5.9, macOS 14). Reine AppKit/SwiftUI-App ohne Xcode-Projekt.
Bundle-ID `local.crypttoolmac.CrypTool`.

Module unter `Sources/`:
- `CTCommon` – Grundtypen, `TextCoding` (Windows-1252), Alphabet/Optionen.
- `CTBigNum` – Langzahl (`BigUInt`/`BigInt`), Zahlentheorie, RSA/ECC, PRNGs. **Krypto-Angriffe:**
  `Lattice.swift` (exakte Ganzzahl-LLL, δ-Parameter; große Zeilen-Updates parallel, Divisionen über
  `SharedExactDivisor.swift`), `Coppersmith.swift` (Howgrave-Graham +
  Nullstellensuche), `DurandKerner.swift`, `SideChannel.swift` (Kühn), `BloemerMay.swift` (Boneh/Durfee,
  bivariate Resultante über `BivPoly`).
- `CTCipherC` – C-Referenzimplementierungen (AES-Kandidaten u. a.).
- `CTModern`, `CTClassic`, `CTAnalysis` – moderne/klassische Verfahren, Analyse.
- `CrypTool` – App: NSDocument-Architektur, Menüs, Dialoge, Hilfe.
  - `App/` – `MainMenu.swift` (CT1-Menüstruktur), `CTAction.swift` (Kommandos), `ActionRouter.swift`
    + `Features/FeatureRouter.swift` (Dispatch; `notIncluded` ist jetzt **leer**), `AppDelegate.swift`,
    `DocumentWindowController.swift` (Kontextmenüs, `CT1ContextMenu`), `CTDocument(Controller).swift`,
    `HexEditorView.swift`.
  - `Support/` – `SwiftUICompat.swift` (`@CTState`), `WindowPresenter.swift` (`tool`/`sheet`,
    `DialogScaffold`), `AboutDialog.swift`, `OptionsWindows.swift`.
  - `Help/` – `HelpCenter`, `HelpWindow`, `HelpBook`, `HelpTopics.swift` (Aktion→HTML-Seite, erschöpfend).
  - `Features/CT1Attacks/LatticeAttackViews.swift` – Dialoge der RSA-Angriffe.
- `Resources/` – `Help/en` (englische CT1-Hilfe, per `scripts/import-ct1-help.py` erzeugt), `Examples`
  (gemeinsame CT1-Beispiele + englische `original.txt`/`fake.txt`), `Words` (cracklib), `Docs`
  (`CT-Book-en.pdf`, `CrypTool1-Presentation-en.pdf`, authors.txt), `Images` (`CrypToolStartLogo-en.png`),
  `Reference` (`english.txt` = Standard, `deutsch.txt`), `Info.plist` (Entwicklungssprache `en`).
- `scripts/` – `build-app.sh`, `check-help.py`, `import-ct1-help.py`, `make-icon.swift`.
- `Tests/` – ausführbare Testläufer (siehe unten).

## 3. Setup, Build, Tests
Voraussetzung: macOS, **Xcode Command Line Tools genügen** (kein Xcode). Keine Umgebungsvariablen nötig.
- App-Bundle: `scripts/build-app.sh` → `build/CrypTool.app` (arm64, ad-hoc signiert). `--dmg` erzeugt zusätzlich
  `build/CrypTool.dmg`; `CONFIG=debug` optional.
- Schnell kompilieren (ohne Bundle): `swift build --scratch-path .build-app --product CrypTool`.
- Tests (ausführbare Targets, da unter CLT kein XCTest): `swift run -c release --scratch-path .build-release <Target>`
  mit Target ∈ {CTBigNumTests, CTLatticeTests, CTClassicTests, CTModernTests, CTAnalysisTests}.
- Hilfe-Prüfskript: `python3 -I scripts/check-help.py Resources/Help/en Sources/CrypTool/Help/HelpTopics.swift`
  (2 Warnungen zu fehlenden Ankern im Original-Readme sind bekannt, 0 Fehler erwartet).
- Hilfe neu erzeugen: `python3 -I scripts/import-ct1-help.py <cryptool1-Checkout> Resources/Help/en`
  (Sprache = Name des Zielordners, `en` oder `de`).
- Release: `gh release create vX.Y.Z build/CrypTool.dmg build/CrypTool-macOS-arm64.zip …` (zip via
  `ditto -c -k --keepParent build/CrypTool.app build/CrypTool-macOS-arm64.zip`).

## 4. Funktionsstand
✅ **getestet und funktioniert**
- Alle 5 Testläufer grün (siehe HANDOFF.md für Zahlen), Hilfe-Prüfskript 0 Fehler.
- Alle 201 CT1-Menüpunkte vorhanden und funktionsfähig; Menü-Klick-Sweep (früher, deutsche Fassung) ohne Absturz.
- Englische Fassung: Menüleiste stimmt Punkt für Punkt mit `IDR_TEXTTYPE` (englisch) überein (Skriptvergleich
  + Start der App geprüft); App startet mit „How to Start“ und `Startingexample-en.txt`.
- RSA-Angriffe (Dialoge live geprüft): Faktorisieren mit teilweise bekanntem p (MSB/LSB), stereotype
  Nachrichten, Seitenkanalangriff (Kühn), kleine geheime Schlüssel (Wiener + Blömer/May).
- Über-Dialog, Kontextmenüs, Hilfe (CT-Buch/Präsentation-PDF), „Zuletzt geöffnete Dateien“.

⚠️ **implementiert, aber ungetestet / mit Vorbehalt**
- **Englische Dialoge sind nicht einzeln am Bildschirm geprüft** (nur Kompilat, Tests, Menüleiste, ein Dialog).
  Längere englische Texte können in festen Breiten abgeschnitten sein (Flussdiagramm-Schaltflächen PKI,
  Tabellenspalten Signaturangriff, Animationszeilen).
- Blömer/May für δ nahe 0,29 oder sehr große N: korrekt, aber auch mit der beschleunigten exakten LLL langsam
  (Dialog warnt, `m` einstellbar). Ergebnis stets identisch zu CT1.
- Dritter RSA-Dialog („kleine geheime Schlüssel“) wurde live nur teilweise geprüft (Bildschirm-Ruhezustand
  während eines Testlaufs); Rechenkern ist per Unit-Test bestätigt.

❌ **bekannter Fehler / Lücke**
- Keine funktionalen Fehler bekannt. Einschränkung: CT1s eingebauter Seitenkanal-Bob-Schlüssel liegt im
  proprietären SECUDE-PSE-Format vor und ist nicht auslesbar → exakte Zahlen der *eingebauten* Windows-Demo
  nicht reproduzierbar (eigenes Beispiel bzw. eigene Eingaben nötig). Siehe `NICHT-ENTHALTEN.md`.

## 5. Wichtige Entscheidungen und fragile Stellen
- **Sprache:** App ist englisch; jeder Text mit Original stammt wörtlich aus der englischen CT1-Quelle
  (`CrypTool.rc` englischer Abschnitt per Ressourcen-ID, NumberShark-/AES-Tool-`.rc`, `NT.exe`, `*_en.aml`,
  englische SWF/Java-Texte), auch mit deren Eigenheiten/Tippfehlern. Texte ohne Original sind übersetzt.
  Sprachabhängiges Verhalten wie im englischen CT1: Referenzdatei `english.txt` als Standard, Zahlenformat
  „1,234.5“, englische Dokument-Feldnamen (Details: `NICHT-ENTHALTEN.md`, Abschnitt „Sprache“).
- **Kein Laufzeit-Sprachumschalter:** Texte stehen als Literale im Code. Deutsch gibt es nur noch im
  Git-Verlauf/Release v1.4.0.
- **Verfahrenstreue:** Angriffe sind 1:1 aus CT1 portiert; Ergebnisse (eindeutige Faktoren/Schlüssel/Nachricht)
  stimmen mit Windows überein. Begründung und Grenzen in `NICHT-ENTHALTEN.md`.
- **LLL:** bewusst exakt-ganzzahlig (reproduzierbar) statt NTL-Fließkomma → langsamer, aber ergebnisgleich.
  Nicht „optimieren“, wenn dadurch Ergebnisse/Verfahren abweichen. Die vorhandene Beschleunigung (parallele
  Zeilen-Updates, gemeinsamer Kehrwert) ändert nur die Rechenzeit; `CTLatticeTests` vergleicht die Basis
  bitgenau mit einer schlichten Referenz-LLL – dieser Test muss grün bleiben.
- **CLT-Umgebung:** `@State`-Macro fehlt → `@CTState` nutzen; kein XCTest → Testläufer als Executables.
- **CT1-Quellen** sind CP1252/CRLF; Shell-`grep` ist ein kaputter Wrapper → `/usr/bin/grep -a`.
- `NICHT-ENTHALTEN.md` ist stabiler Link (von README referenziert, in Releases verlinkt) – Dateiname nicht ändern.
