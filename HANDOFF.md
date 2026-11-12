# HANDOFF

## Stand
- Branch: `main`, synchron mit `origin/main`.
- Letzter Code-Commit: `9ea4410` „Blömer/May-Gitterverfahren für kleine geheime Schlüssel“ (App = v1.4.0).
- Tests: **alle grün** (Details unten).

## Tests (einmal gelaufen)
`swift run -c release --scratch-path .build-release <Target>`:
- CTBigNumTests → 3080 bestanden, 0 fehlgeschlagen ✅
- CTLatticeTests → 12 bestanden, 0 fehlgeschlagen ✅
- CTClassicTests → 18923 Prüfungen, 0 Fehler ✅
- CTModernTests → 2416 passed, 0 failed ✅
- CTAnalysisTests → 428 passed, 0 failed ✅
- `python3 -I scripts/check-help.py Resources/Help/de Sources/CrypTool/Help/HelpTopics.swift` → 0 errors, 0 warnings ✅

## In diesem Chat geändert
Nur Doku in diesem Abschluss-Commit (kein Anwendungscode). Vorher in diesem Chat (bereits committet+gepusht):
- `972a344` v1.1.1 – Parität (Menü „Speichern als …“, Kontextmenüs, Über-Dialog, CT-Buch/Präsentation-PDF,
  „Zuletzt geöffnete Dateien“), neue `NICHT-ENTHALTEN.md`.
- `60351bf` v1.2.0 – Gitterbasierte RSA-Angriffe: `Lattice.swift`, `Coppersmith.swift`, `DurandKerner.swift`,
  `LatticeAttackViews.swift`, `CTLatticeTests`.
- `2497edc` v1.3.0 – Seitenkanalangriff: `SideChannel.swift`.
- `9ea4410` v1.4.0 – `BloemerMay.swift` (Boneh/Durfee), `Lattice.reduce` mit δ-Parameter.

## Offene Probleme (mit bisherigen Versuchen)
- **Englisch-Umstellung noch nicht gemacht** (eigentlicher nächster Auftrag, s. u.). Nicht begonnen, da der
  Abschluss-Auftrag „keinen Anwendungscode mehr ändern“ vorschreibt.
- **Blömer/May-Performance:** exakte Ganzzahl-LLL ist bei δ≈0,29 / großen N langsam (~30 s bei 128-Bit-N).
  Versucht: δ=0,99, Prüfung aller reduzierten Zeilen, dichteres Raster, m/t einstellbar. Eine schnellere
  Fließkomma-/XD-LLL (wie NTL) wäre nötig, wurde als zu großer/riskanter Eingriff **nicht** umgesetzt.
  Ergebnis bleibt identisch zu CT1; nur Laufzeit betroffen.

## Nächste Schritte (in Reihenfolge)
1. **UI auf Englisch umstellen, Benennung exakt wie englische CT1-Originalversion** (inkl. Menü-/Button-Reihenfolge).
   - Lesen: PROJECT_STATE.md §2 und §5; Dateien `Sources/CrypTool/App/MainMenu.swift` (Menütexte),
     `Sources/CrypTool/App/CTAction.swift`, alle Dialoge in `Sources/CrypTool/Features/**` und
     `Sources/CrypTool/Support/*.swift` (Titel/Buttons), `Sources/CrypTool/Help/HelpTopics.swift` + `HelpBook.swift`.
   - Referenz (exakte englische Strings): CT1-Quelltext, `CrypTool/CrypTool.rc` (englische STRINGTABLE und
     IDR_*-MENÜs) sowie `CrypTool/hlp_en/` für die englische Hilfe. Repo neu klonen:
     `git clone https://github.com/cryptool-org/cryptool1` (CP1252/CRLF → `iconv -f cp1252`, `/usr/bin/grep -a`).
   - Erst `MainMenu.swift` Menüpunkt für Menüpunkt auf die englischen `.rc`-Texte mappen, dann Dialoge/Buttons,
     dann Hilfe (englischen Hilfebaum über `scripts/import-ct1-help.py` prüfen/importieren, danach
     `scripts/check-help.py`), zuletzt `swift build` + `scripts/build-app.sh` + Tests.
   - Jede unklare/mehrdeutige Benennung in NICHT-ENTHALTEN.md bzw. als Codekommentar „unklar/zu prüfen“ festhalten.
2. Erlaubte Optimierungen (nur wenn Verfahren **und** Ergebnisse unverändert): LLL/`BloemerMay` Laufzeit/Speicher.
   Vor/nach jeder Optimierung `CTLatticeTests` laufen lassen (müssen identisch grün bleiben).
3. Optional: `PROJECT_STATE.md` kürzen, falls > ~400 Zeilen (aktuell darunter – noch nichts nötig).

## Deployment
- GitHub-Releases **v1.0.0–v1.4.0** veröffentlicht (je `CrypTool.dmg` + `CrypTool-macOS-arm64.zip`), v1.4.0 = Latest.
- `main` ist gepusht. Kein Server/Backend. Lokal unversioniert: `build/` (Bundle/DMG) und `graphify-out/` – bewusst
  in `.gitignore`, nicht einchecken.

## Offene Entscheidungen (nur durch Nutzer)
- Englisch **ersetzt** Deutsch vollständig, oder zweisprachig? (CT1 ist pro Sprache ein eigener Build –
  Annahme: reine Englisch-Variante gewünscht. Bis zur Klärung: **unklar/zu prüfen**.)
- Soll in eine schnellere LLL investiert werden (größerer Aufwand)?

## Dateien außerhalb des Repos
- **CT1-Quelltext** (Referenz für englische Strings + Korrektheitsabgleich): von
  https://github.com/cryptool-org/cryptool1 neu klonen. War im Session-Scratchpad abgelegt (flüchtig, weg).
- UI-Testhelfer (winshot/click/listmenu/sweep.applescript) lagen im Scratchpad (flüchtig); bei Bedarf neu bauen,
  nicht essenziell. Keine `.env`/Schlüssel/Modelle nötig.
