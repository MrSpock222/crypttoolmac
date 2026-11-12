# AGENTS

**Zu Beginn jeder Session HANDOFF.md lesen; PROJECT_STATE.md gezielt über dessen Inhaltsverzeichnis.**

Dauerhafte Regeln (je mit Grund). Nur ergänzen, was einen konkreten, wiederholbaren Fehler verhindert.

- **Nur Xcode Command Line Tools, kein Xcode** → kein XCTest/swift-testing. Tests sind ausführbare Targets:
  `swift run -c release --scratch-path .build-release <Target>` (CTBigNumTests, CTLatticeTests, CTClassicTests,
  CTModernTests, CTAnalysisTests). Grund: klassische Testläufe schlagen sonst fehl.
- **`@CTState` statt `@State`** (Typealias in `Sources/CrypTool/Support/SwiftUICompat.swift`); kein `#Preview`/Makros.
  Grund: SwiftUI-Macros sind unter CLT nicht verfügbar, Build bricht sonst ab.
- **Immer `/usr/bin/grep -a`**, nie das Shell-`grep` (kaputter Wrapper). CT1-Quelltext ist CP1252/CRLF →
  mit `iconv -f cp1252 -t utf-8` lesen. Grund: sonst leere/falsche Treffer und zerstörte Umlaute.
- **App-Bundle mit `scripts/build-app.sh`** bauen (arm64, ad-hoc signiert); reines `swift build` ergibt kein
  lauffähiges `.app`. Grund: Resources/Icon/Signatur fehlen sonst.
- **Nie `build/` oder `graphify-out/` committen** (stehen in `.gitignore`); kein blindes `git add -A`.
  Grund: große Artefakte, Versehen vermeiden.
- **Krypto-Verfahren ergebnistreu halten:** Änderungen an `Lattice`/`Coppersmith`/`BloemerMay`/`SideChannel`
  (CTBigNum) nur, wenn Verfahren **und** Ergebnisse gegenüber CT1 unverändert bleiben; danach `CTLatticeTests`
  grün halten. Grund: Gleichheit der Ergebnisse mit der Windows-Version ist Projektziel.
- **`NICHT-ENTHALTEN.md` nicht umbenennen** (stabiler Link aus README und GitHub-Releases).
- **READMEs klein und deutsch** halten (Projektkonvention, nur das Wichtigste).
