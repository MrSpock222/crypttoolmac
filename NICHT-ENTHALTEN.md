# Abweichungen von der Windows-Version

(Früher: „nicht enthaltene Funktionen“. Seit Version 1.3.0 sind alle CT1-Funktionen vorhanden;
der Dateiname bleibt aus Gründen stabiler Links erhalten.)

Vergleich der macOS-Version mit CrypTool 1.4.x für Windows (**englische** Fassung; bis Version 1.4.0
war die macOS-Version deutsch – diese steht weiter als Release v1.4.0 bereit).

**Alle 201 Menüeinträge** von CT1 (Text-, Hex-, Diagramm- und 3D-Fenster) gibt es auf dem Mac
mit demselben Namen an derselben Stelle, und **alle sind funktionsfähig** – es gibt keinen
Menüpunkt mehr, der nur einen „nicht enthalten“-Hinweis zeigt.

Dieses Dokument beschreibt daher nur noch **Abweichungen im Verhalten** (Abschnitt 1) und
nachgebaute externe Programme (Abschnitt 2 ff.).

---

## 1. Verfahren, die nachgebaut wurden – und wie genau sie CT1 entsprechen

Für den Unterricht wichtig: Bei **deterministischen** Angriffen ist das Ergebnis mathematisch
eindeutig. Gleiche Eingaben (N, e, c, …) liefern auf Mac und Windows dasselbe Ergebnis,
**unabhängig vom Rechenweg** – denn gesucht ist jeweils *die* eine Lösung (der Faktor, die
Nachricht, der Schlüssel).

### Gitterbasierte Angriffe auf RSA

Nativ nachgebaut mit LLL-Gitterreduktion und Coppersmith/Howgrave-Graham (Rechenkern in `CTBigNum`,
getestet in `CTLatticeTests`). Jeder Dialog hat „Generate example“ und „Start“. Die Einträge
gibt es wie in CT1 unter *Indiv. Procedures ▸ RSA Cryptosystem* **und** *Analysis ▸ Asymmetric Encryption*.

| Menüeintrag | Verfahren | Ergebnis = CT1? |
|---|---|---|
| Factoring with a Hint... | Coppersmith (höchst-/niederstwertige Bits), nötig: ⌈n/4⌉+1 Bit von p | ja (eindeutiger Faktor) |
| Attack on Stereotyped Messages... | Coppersmith bei kleinem e, unbekannter Teil < N^(1/e) | ja (eindeutige Nachricht) |
| Attack on Small Secret Keys... | Gitterverfahren nach Blömer/May (Boneh/Durfee); Wiener als schneller Vorlauf für δ < 0,25 | ja |

**Kleiner geheimer Schlüssel – gleiches Verfahren wie CT1:** Seit Version 1.4.0 ist das
*Gitterverfahren nach Blömer/May* (Boneh/Durfee, δ < 0,292) nativ umgesetzt – dasselbe Verfahren
wie in CT1 (bivariate Coppersmith-Nullstellensuche mit Resultante). Für sehr kleines d (δ < 0,25)
wird zuerst das schnelle Kettenbruchverfahren (Wiener) versucht; es liefert exakt denselben
Schlüssel. Das gefundene d, p, q ist in jedem Fall identisch mit CT1 (es ist Bobs eindeutiger
Schlüssel).

*Leistungshinweis:* CT1 nutzt die stark optimierte Fließkomma-LLL der NTL-Bibliothek. Die
macOS-Version verwendet eine exakte Ganzzahl-LLL. Sie rechnet die teuren Zeilen-Updates auf
mehreren Prozessorkernen und teilt über einen gemeinsamen Kehrwert; das macht sie etwa 4- bis 5-mal
schneller als bis Version 1.4.0 (256-Bit-N, m = 4: rund 5 s statt 20 s), die reduzierte Basis ist
dabei bitgenau dieselbe (`CTLatticeTests` vergleicht mit der schlichten Fassung). Für δ nahe 0,29
oder sehr große N können die nötigen großen Gitter trotzdem lange dauern (der Dialog weist darauf
hin, m lässt sich einstellen).

### Side-Channel Attack on "Textbook RSA" (nach Ulrich Kühn)

Der Angriffsalgorithmus ist **1:1 aus CT1 portiert** (`SideChannelAttack.cpp`: Binärsuche über z,
`computeZ`, finale Berechnung (N/(z+1)) mod 2^b). Bei gleichem öffentlichem Schlüssel (N, e),
gleichem abgefangenen Chiffrat c und gleicher signifikanter Bitlänge erzeugt der Mac dieselbe
Folge von Challenges, dieselben Server-Antworten und denselben rekonstruierten Sessionkey wie CT1.

Eingaben: Bobs (N, e), der private Schlüssel d (den in CT1 der Server in seiner PSE hält – hier
wird er eingegeben, damit das Orakel rechnen kann; Trudy „kennt“ ihn nicht), das abgefangene
Chiffrat c und die signifikante Bitlänge (Default 128, Bedingung L(N) > 3·b+3).

**Was nicht 1:1 reproduzierbar ist:** CT1s *mitgelieferte* Demo verwendet Bobs fest installierten
Schlüssel `[SideChannelAttack][Bob][RSA-512][1152179494][PIN=1234]` und die Dateien
`letterFromAliceToBob-DECRYPTED-en.txt` / `…-ENCRYPTED-en.hex`. Dieser Schlüssel liegt im
proprietär verschlüsselten SECUDE-PSE-Format vor und lässt sich nicht auslesen. Die macOS-Version
erzeugt deshalb mit „Generate example“ einen eigenen Bob-Schlüssel samt Sessionkey. Die konkreten
Zahlen der *eingebauten* Windows-Demo lassen sich damit nicht nachstellen – wohl aber jedes
Szenario, bei dem man N, e, d und c selbst vorgibt (dann stimmen die Ergebnisse exakt überein).
Die interaktive Visualisierung (eigene Fenster für Alice, Bob, Trudy, Schritt-für-Schritt-Modus,
Bericht) ist auf dem Mac durch einen kompakten Angriffsdialog mit Schrittprotokoll ersetzt.

---

## 2. Abweichungen, die bei Anleitungen auffallen können

### Vorinstallierte Schlüssel

CT1 enthält nach der Installation den Schlüssel
`[HybridEncryption][Bob][EC-prime239v1][1178702474][PIN=1234]`. Auf dem Mac ist die Schlüsselliste
beim ersten Start **leer**.

Wenn eine Anleitung diesen Schlüssel braucht, legt man ihn selbst an:
Digital Signatures/PKI ▸ PKI ▸ Generate/Import Keys... → EC, `prime239v1`,
Last name `HybridEncryption`, First name `Bob`, Key identifier `PIN=1234`, PIN `1234`.
Das ist ein neues Schlüsselpaar. Dateien, die unter Windows für CT1-Bob verschlüsselt wurden, lassen
sich damit nicht entschlüsseln. CT1-Schlüsseldateien (`.pse`, SECUDE-Format) können nicht importiert
werden.

### AES (self extracting)

Encrypt/Decrypt ▸ Symmetric (modern) ▸ AES (self extracting)... öffnet das Fenster
„AES-Tool 2.7“ wie in CT1. Bei „self extracting“ entsteht aber eine **`.command`-Datei**
(Doppelklick entschlüsselt im Terminal) statt einer Windows-`.exe`.
Entschlüsseln lassen sich `.aes`-Dateien, selbstextrahierende `.exe`-Dateien aus CT1 und `.command`-Dateien.

### Recent Files

CT1 zeigt die zuletzt geöffneten Dateien nummeriert direkt im Menü „File“.
Der Mac zeigt sie im Untermenü File ▸ Recent Files (mit „Clear Menu“).

### Sprache

Nur Englisch, mit den Texten der englischen CT1-Fassung (Menüs, Dialoge, Ausgaben, Hilfe). CT1 gibt
es zusätzlich auf Deutsch, Polnisch, Serbisch, Spanisch, Französisch und Griechisch. Die
Beispieldateien `Startingexample-el/es/fr/pl/rs.txt` fehlen deshalb; die englischen und deutschen
Beispiele sind vorhanden (File ▸ Example Files).

Was sich wie beim englischen CT1 gegenüber der deutschen Fassung ändert:

- **Referenzdatei:** Standard ist `english.txt` statt `deutsch.txt` (Options ▸ Text Options...). Das
  beeinflusst statistische Analysen (z. B. Caesar/Vigenère); für deutsche Texte dort „German“ wählen.
- **Zahlenformat:** Tausendertrennzeichen „,“ und Dezimalpunkt (CT1 nimmt die Trennzeichen aus den
  Sprachressourcen).
- **Start- und Beispieldateien:** `Startingexample-en.txt`; Signaturangriff mit `original.txt` / `fake.txt`.
- **Dokumentformate:** Signierte bzw. hybrid verschlüsselte Dokumente tragen die englischen
  Feldnamen. Mit der deutschen Fassung (bis 1.4.0 oder deutsches CT1) erzeugte Dokumente werden –
  wie zwischen deutschem und englischem CT1 – nicht erkannt.
- **Zahlenhai:** Spielstände liegen unter `Number Shark` (englischer Name); alte Spielstände der
  deutschen Fassung werden nicht gefunden.

Unabhängig von der CT1-Sprache: Die Vigenère-Analyse nach Schroedel bewertet in CT1 unbekannte Digramme
anders, wenn in *Windows* das Regionsformat „Deutsch (Deutschland)“ eingestellt ist
(`GetThreadLocale() == 1031`). Die macOS-Version rechnet wie CT1 mit diesem Regionsformat (Sonderregel
ein). Wer CT1 mit einem anderen Regionsformat nutzt (z. B. Englisch oder „Deutsch (Österreich)“), kann in
dieser einen Analyse andere Bewertungen sehen.

Bekannte Eigenheiten des englischen Originals wurden übernommen (z. B. Fenstertitel
„Automatic Caesar Analysis of <…>, key: <Key: <D>>“, einzelne Tippfehler in Originaltexten).
Texte ohne englisches Original (reine Mac-Zusätze, Hinweise in den nachgebauten Dialogen) sind
sinngemäß übersetzt.

### Tastenkürzel

<kbd>Strg</kbd> wird zu <kbd>⌘</kbd> (z. B. <kbd>⌘</kbd><kbd>C</kbd>). Die Kontexthilfe liegt wie in CT1 auf
<kbd>F1</kbd> (auf Mac-Tastaturen je nach Einstellung <kbd>fn</kbd>+<kbd>F1</kbd>).

### Fenster

CT1 zeigt alle Dokumente innerhalb eines Hauptfensters. Auf dem Mac ist jedes Dokument ein eigenes Fenster.
Window ▸ Cascade, Tile und Close All funktionieren wie in CT1.
„Arrange Icons“ holt alle Fenster nach vorne. Minimierte Fenster liegen im Dock.

### Hilfe

Statt des Windows-Hilfeprogramms (CHM) gibt es ein eigenes Hilfefenster mit denselben englischen Seiten,
Inhaltsverzeichnis und Volltextsuche (<kbd>⌘</kbd><kbd>F</kbd>). Help ▸ Index zeigt die Indexseite der Hilfe.
CT Book und Presentation öffnen dieselben PDF-Dateien wie das englische CT1, aber in Vorschau statt im Acrobat Reader.

### Einstellungen und Ablageorte

| | CT1 (Windows) | macOS |
|---|---|---|
| Einstellungen | Windows-Registry (Hilfeseite „Persistente Einstellungen“ beschreibt `regedit`) | macOS-Einstellungen, Domain `local.crypttoolmac.CrypTool` |
| Schlüssel | Ordner `pse` im Installationsordner | `~/Library/Application Support/CrypTool/keys.json` |
| Beispieldateien | Ordner `examples` im Installationsordner | `~/Library/Application Support/CrypTool/examples` |

### Dateien aus dem CT1-Installationsordner, die fehlen

- `Bc` (GNU bc für Windows mit Beispielskripten). macOS hat `bc` bereits eingebaut (Terminal: `bc -l`).
- `sage` (SageMath-Beispielskripte zum CT-Buch).
- Beispieldateien und Schlüssel des Seitenkanalangriffs (siehe Abschnitt 1).

---

## 3. Externe Programme aus CT1, die nachgebaut wurden

Diese Menüpunkte haben in CT1 ein eigenes Programm gestartet (Flash, Java, Authorware, HTA oder EXE).
Auf dem Mac öffnen sie ein natives Fenster mit derselben Funktion. Java, Flash oder Wine braucht man nicht.

| Menüeintrag | CT1 startete | macOS |
|---|---|---|
| Encrypt/Decrypt ▸ Symmetric (modern) ▸ AES (self extracting)... | `AESTool.exe` | nativer Nachbau, siehe Abschnitt 2 |
| Indiv. Procedures ▸ Visualization of Algorithms ▸ Caesar... / Vigenère... / Nihilist... / DES... | ANIMAL (Java, `animal.bat`) | native Animationen, Texte aus den englischen Skripten (`*_en.aml`) |
| Indiv. Procedures ▸ Visualization of Algorithms ▸ AES ▸ Rijndael Animation... | Flash (`Rijndael-Animation.exe`) | nativer Nachbau, Texte aus der englischen Animation |
| Indiv. Procedures ▸ Visualization of Algorithms ▸ AES ▸ Rijndael Inspector... | Flash (`Rijndael-Inspector.exe`) | nativer Nachbau |
| Indiv. Procedures ▸ Visualization of Algorithms ▸ AES ▸ Rijndael Flow Visualization... | Java | nativer Nachbau |
| Indiv. Procedures ▸ Visualization of Algorithms ▸ Enigma... | Flash (`Enigma_en.exe`) | nativer Nachbau |
| Indiv. Procedures ▸ Protocols ▸ Secure E-Mail with S/MIME... | Java | nativer Nachbau |
| Indiv. Procedures ▸ Number Theory - Interactive ▸ Learning Tool for Number Theory... | Authorware (`NT.exe`) | nativer Nachbau, Seitentexte aus `NT.exe` übernommen |
| Indiv. Procedures ▸ Number Theory - Interactive ▸ Point Addition on Elliptic Curves... | Java (`eccdemo.jar`) | nativer Nachbau |
| Indiv. Procedures ▸ Number Theory - Interactive ▸ Generic t-adic NAF Key Generator... | `t-adicNAF.hta` | nativer Nachbau |
| Indiv. Procedures ▸ Educational Games ▸ Number Shark | `NumberShark.exe` | nativer Nachbau |
| Help ▸ CT Book, Help ▸ Presentation | PDF im Acrobat Reader | dieselben PDFs in Vorschau |

---

## 4. Nur in der macOS-Version

Diese Einträge gibt es in CT1 nicht. Sie stören Anleitungen nicht.

- File ▸ Example Files (Untermenü mit den CT1-Beispieldateien; in CT1 über File ▸ Open...)
- View ▸ Font ▸ Increase Font Size / Decrease Font Size
- Indiv. Procedures ▸ Visualization of Algorithms ▸ Caesar Disk...
- Help ▸ Context Help (<kbd>F1</kbd>), Help ▸ CrypTool Website, Help ▸ License
- Von macOS automatisch hinzugefügt: Edit ▸ AutoFill, Start Dictation…, Emoji & Symbols,
  die macOS-Einträge im Menü Window und „Close All“ (mit <kbd>⌥</kbd>) im Menü File
