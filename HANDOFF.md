# HANDOFF

## Stand
- Branch: `main`, synchron mit `origin/main`. Letzte Code-Commits: `0c07858` (englische Fassung, v2.0.0) und
  „Dialoggrößen begrenzt …“ (App = **v2.0.1**; v1.4.0 = letzte deutsche Fassung).
- Tests: **alle grün** (für den Release-Stand gelaufen, 2026-11-13).

## Tests (einmal gelaufen)
`swift run -c release --scratch-path .build-release <Target>`:
- CTBigNumTests → 3080 bestanden, 0 fehlgeschlagen ✅
- CTLatticeTests → 17 bestanden, 0 fehlgeschlagen ✅ (5 neue: LLL bitgenau gegen Referenz, exakte Division)
- CTClassicTests → 18373 Prüfungen, 0 Fehler ✅ (Anzahl schwankt: zufällige Textlängen in `main.swift`)
- CTModernTests → 2416 passed, 0 failed ✅
- CTAnalysisTests → 428 passed, 0 failed ✅
- `python3 -I scripts/check-help.py Resources/Help/en Sources/CrypTool/Help/HelpTopics.swift` → 0 errors,
  2 warnings (fehlende Anker im Original-Readme) ✅
- `scripts/build-app.sh` baut; App gestartet: englische Menüleiste, „How to Start“, `Startingexample-en.txt`.

## Erledigt in diesem Chat (v2.0.0)
- Alle UI-Texte englisch, wo vorhanden wörtlich aus den englischen Originalen (CrypTool.rc per Ressourcen-ID,
  NumberShark/AES-Tool, `NT.exe`, `*_en.aml`, englische SWF/Java-Texte). Menü = englisches `IDR_TEXTTYPE`.
- Ressourcen: `Help/en` statt `Help/de`, `CT-Book-en.pdf`/`CrypTool1-Presentation-en.pdf`,
  `CrypToolStartLogo-en.png`, `original.txt`/`fake.txt`; `import-ct1-help.py` kennt jetzt `en` und `de`.
- Verhalten wie englisches CT1: Referenzdatei `english.txt` als Standard, Zahlenformat „1,234.5“;
  Schroedel-Analyse wie CT1 mit Windows-Regionsformat „Deutsch (Deutschland)“ (`germanLocale: true`,
  Entscheidung des Nutzers: CT1 englisch, Region zählt → ein).
- LLL: Zeilen-Updates parallel + gemeinsamer Kehrwert (`SharedExactDivisor.swift`); Blömer/May ca. 4–5× schneller
  (256-Bit-N, m=4: ~20 s → ~5 s), reduzierte Basis bitgleich.
- Doku: README, `NICHT-ENTHALTEN.md` (Abschnitt „Sprache“), `PROJECT_STATE.md`.

## Vorherige Chats (committet + gepusht)
- `972a344` v1.1.1 – Parität (Menü „Speichern als …“, Kontextmenüs, Über-Dialog, CT-Buch/Präsentation-PDF,
  „Zuletzt geöffnete Dateien“), neue `NICHT-ENTHALTEN.md`.
- `60351bf` v1.2.0 – Gitterbasierte RSA-Angriffe: `Lattice.swift`, `Coppersmith.swift`, `DurandKerner.swift`,
  `LatticeAttackViews.swift`, `CTLatticeTests`.
- `2497edc` v1.3.0 – Seitenkanalangriff: `SideChannel.swift`.
- `9ea4410` v1.4.0 – `BloemerMay.swift` (Boneh/Durfee), `Lattice.reduce` mit δ-Parameter.

## Offene Probleme (mit bisherigen Versuchen)
- **Dialoggrößen (in v2.0.1 behoben):** Dialoge wurden breiter als der Bildschirm (lange
  Beschreibungstexte, bestand schon in der deutschen Fassung). Zentral behoben über `IdealWidthCap`; dazu
  abgeschnittene/vertauschte Texte in 8 Dialogen korrigiert (Homophone, Permutation, Solitaire, Schlüsselerzeugung,
  Primzahlerzeugung, Diffie-Hellman, Challenge-Response, Number Shark) und einmalige Umstellung der gespeicherten
  Referenzdatei auf `english.txt`. Geprüft mit `scripts/audit-layout.sh` (134 Dialoge) und gerenderten Bildern.
  Offen: Zustände nach Bedienung, NT-Seiten, Animationsschritte sind nicht angesehen.
- Dialoge der Gitterangriffe/Seitenkanal sind vereinfacht gegenüber CT1 (fehlende Felder/Statuszeilen) –
  nur Texte angeglichen, Struktur unverändert. Histogramm-Fenstertitel ohne Zeichenzahl („Histogram of <…>“).
- Blömer/May bleibt für δ≈0,29 / große N langsam (512-Bit-N, m=4: ~28 s). Fließkomma-LLL nicht umgesetzt.
- Automatische Erstzuordnung DE→EN hatte einzelne Fehlpaare (abweichendes Dialoglayout, falscher Kontext);
  alle Bereiche wurden gegengeprüft, Restfehler bei selten genutzten Dialogen sind möglich.

## Nächste Schritte (in Reihenfolge)
1. Dialoge in Benutzung durchklicken (Ergebnis-/Folgedialoge, NT-Lernprogramm, Animationen) und abgeschnittene
   Texte korrigieren; `scripts/audit-layout.sh` nach Textänderungen erneut laufen lassen.
2. Optional: Dialogstruktur der Gitterangriffe an CT1 angleichen; `PROJECT_STATE.md` kürzen, falls > ~400 Zeilen.

## Deployment
- GitHub-Releases **v1.0.0–v1.4.0** (deutsch) und **v2.0.0, v2.0.1** (englisch, v2.0.1 = Latest) veröffentlicht
  (je `CrypTool.dmg` + `CrypTool-macOS-arm64.zip`).
- `main` ist gepusht. Kein Server/Backend. Lokal unversioniert: `build/` (Bundle/DMG) und `graphify-out/` – bewusst
  in `.gitignore`, nicht einchecken.

## Offene Entscheidungen (nur durch Nutzer)
- Soll in eine schnellere (Fließkomma-)LLL investiert werden (größerer Aufwand)?

## Dateien außerhalb des Repos
- **CT1-Quelltext** (Referenz): https://github.com/cryptool-org/cryptool1 – Klon lag in
  `/private/tmp/claude-501/-Users-rudi-Documents-GitHub-crypttoolmac/b82b4504-ba6e-4567-a96d-297690f55a9c/scratchpad/upstream/cryptool1`
  (flüchtig; bei Bedarf neu klonen).
- Hilfsskripte der Umstellung (DE→EN-Tabelle aus der `.rc`, Prüf- und Suchskripte) lagen im Session-Scratchpad
  (flüchtig, nicht essenziell). Keine `.env`/Schlüssel/Modelle nötig.
