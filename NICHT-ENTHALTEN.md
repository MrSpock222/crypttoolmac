# Abweichungen von der Windows-Version

(Früher: „nicht enthaltene Funktionen“. Seit Version 1.3.0 sind alle CT1-Funktionen vorhanden;
der Dateiname bleibt aus Gründen stabiler Links erhalten.)

Vergleich der macOS-Version (1.3.0) mit CrypTool 1.4.x für Windows (deutsch).

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
getestet in `CTLatticeTests`). Jeder Dialog hat „Beispiel erzeugen“ und „Starten“. Die Einträge
gibt es wie in CT1 unter *Einzelverfahren ▸ RSA-Kryptosystem* **und** *Analyse ▸ Asymmetrische Verfahren*.

| Menüeintrag | Verfahren | Ergebnis = CT1? |
|---|---|---|
| Faktorisieren mit teilweise bekanntem p … | Coppersmith (höchst-/niederstwertige Bits), nötig: ⌈n/4⌉+1 Bit von p | ja (eindeutiger Faktor) |
| Angriff auf stereotype Nachrichten … | Coppersmith bei kleinem e, unbekannter Teil < N^(1/e) | ja (eindeutige Nachricht) |
| Angriff auf kleine geheime Schlüssel … | Kettenbruchverfahren nach Wiener | ja, wo anwendbar (s. u.) |

**Einzige echte Methodenabweichung – kleiner geheimer Schlüssel:** CT1 nutzt das *Gitterverfahren
nach Blömer/May* (δ = log(d)/log(N) < 0,290). Die macOS-Version nutzt das *Kettenbruchverfahren
nach Wiener* (δ < 0,25). Das gefundene d, p, q ist identisch (es ist Bobs eindeutiger privater
Schlüssel) – nur der abgedeckte δ-Bereich ist etwas kleiner. Für Unterrichtsbeispiele mit kleinem d
stimmen die Ergebnisse überein; der Dialog weist auf den Unterschied hin.

### Seitenkanalangriff auf „Textbook-RSA“ (nach Ulrich Kühn)

Der Angriffsalgorithmus ist **1:1 aus CT1 portiert** (`SideChannelAttack.cpp`: Binärsuche über z,
`computeZ`, finale Berechnung (N/(z+1)) mod 2^b). Bei gleichem öffentlichem Schlüssel (N, e),
gleichem abgefangenen Chiffrat c und gleicher signifikanter Bitlänge erzeugt der Mac dieselbe
Folge von Challenges, dieselben Server-Antworten und denselben rekonstruierten Sessionkey wie CT1.

Eingaben: Bobs (N, e), der private Schlüssel d (den in CT1 der Server in seiner PSE hält – hier
wird er eingegeben, damit das Orakel rechnen kann; Trudy „kennt“ ihn nicht), das abgefangene
Chiffrat c und die signifikante Bitlänge (Default 128, Bedingung L(N) > 3·b+3).

**Was nicht 1:1 reproduzierbar ist:** CT1s *mitgelieferte* Demo verwendet Bobs fest installierten
Schlüssel `[SideChannelAttack][Bob][RSA-512][1152179494][PIN=1234]` und die Dateien
`letterFromAliceToBob-DECRYPTED-de.txt` / `…-ENCRYPTED-de.hex`. Dieser Schlüssel liegt im
proprietär verschlüsselten SECUDE-PSE-Format vor und lässt sich nicht auslesen. Die macOS-Version
erzeugt deshalb mit „Beispiel erzeugen“ einen eigenen Bob-Schlüssel samt Sessionkey. Die konkreten
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
Digitale Signaturen/PKI ▸ PKI ▸ Schlüssel erzeugen/importieren … → EC, `prime239v1`,
Name `HybridEncryption`, Vorname `Bob`, Schlüsselkennung `PIN=1234`, PIN `1234`.
Das ist ein neues Schlüsselpaar. Dateien, die unter Windows für CT1-Bob verschlüsselt wurden, lassen
sich damit nicht entschlüsseln. CT1-Schlüsseldateien (`.pse`, SECUDE-Format) können nicht importiert
werden.

### AES (selbstextrahierend)

Ver-/Entschlüsseln ▸ Symmetrisch (modern) ▸ AES (selbstextrahierend) … öffnet das Fenster
„AES-Tool 2.7“ wie in CT1. Bei „selbstextrahierend“ entsteht aber eine **`.command`-Datei**
(Doppelklick entschlüsselt im Terminal) statt einer Windows-`.exe`.
Entschlüsseln lassen sich `.aes`-Dateien, selbstextrahierende `.exe`-Dateien aus CT1 und `.command`-Dateien.

### Zuletzt geöffnete Dateien

CT1 zeigt die zuletzt geöffneten Dateien nummeriert direkt im Menü „Datei“.
Der Mac zeigt sie im Untermenü Datei ▸ Zuletzt geöffnete Dateien (mit „Liste leeren“).

### Sprache

Nur Deutsch. CT1 gibt es zusätzlich auf Englisch, Polnisch, Serbisch, Spanisch, Französisch und
Griechisch. Die Beispieldateien `Startingexample-el/es/fr/pl/rs.txt` fehlen deshalb;
„Startbeispiel (deutsch)“ und „Starting example (English)“ sind vorhanden.

### Tastenkürzel

<kbd>Strg</kbd> wird zu <kbd>⌘</kbd> (z. B. <kbd>⌘</kbd><kbd>C</kbd>). Die Kontexthilfe liegt wie in CT1 auf
<kbd>F1</kbd> (auf Mac-Tastaturen je nach Einstellung <kbd>fn</kbd>+<kbd>F1</kbd>).

### Fenster

CT1 zeigt alle Dokumente innerhalb eines Hauptfensters. Auf dem Mac ist jedes Dokument ein eigenes Fenster.
Fenster ▸ Überlappend anordnen, Nichtüberlappend anordnen und Alle schließen funktionieren wie in CT1.
„Symbole anordnen“ holt alle Fenster nach vorne. Minimierte Fenster liegen im Dock.

### Hilfe

Statt des Windows-Hilfeprogramms (CHM) gibt es ein eigenes Hilfefenster mit denselben deutschen Seiten,
Inhaltsverzeichnis und Volltextsuche (<kbd>⌘</kbd><kbd>F</kbd>). Hilfe ▸ Index zeigt die Seite „CrypTool-Hilfeindex“.
CT-Buch und Präsentation öffnen dieselben PDF-Dateien wie CT1, aber in Vorschau statt im Acrobat Reader.

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
| Ver-/Entschlüsseln ▸ Symmetrisch (modern) ▸ AES (selbstextrahierend) … | `AESTool.exe` | nativer Nachbau, siehe Abschnitt 2 |
| Einzelverfahren ▸ Visualisierung von Algorithmen ▸ Caesar … / Vigenère … / Nihilist … / DES … | ANIMAL (Java, `animal.bat`) | native Animationen |
| Einzelverfahren ▸ Visualisierung von Algorithmen ▸ AES ▸ Rijndael-Animation … | Flash (`Rijndael-Animation.exe`) | nativer Nachbau |
| Einzelverfahren ▸ Visualisierung von Algorithmen ▸ AES ▸ Rijndael-Inspektor … | Flash (`Rijndael-Inspector.exe`) | nativer Nachbau |
| Einzelverfahren ▸ Visualisierung von Algorithmen ▸ AES ▸ Rijndael-Flussvisualisierung … | Java | nativer Nachbau |
| Einzelverfahren ▸ Visualisierung von Algorithmen ▸ Enigma … | Flash (`Enigma_de.exe`) | nativer Nachbau |
| Einzelverfahren ▸ Protokolle ▸ Sichere E-Mail mit S/MIME … | Java | nativer Nachbau |
| Einzelverfahren ▸ Zahlentheorie interaktiv ▸ Lernprogramm für Zahlentheorie … | Authorware (`ZT.exe`) | nativer Nachbau, Seitentexte aus `ZT.exe` übernommen |
| Einzelverfahren ▸ Zahlentheorie interaktiv ▸ Punktaddition auf Elliptischen Kurven … | Java (`eccdemo.jar`) | nativer Nachbau |
| Einzelverfahren ▸ Zahlentheorie interaktiv ▸ Generischer t-adic-NAF-Schlüsselgenerator … | `t-adicNAF.hta` | nativer Nachbau |
| Einzelverfahren ▸ Lernspiele ▸ Der Zahlenhai | `Zahlenhai.exe` | nativer Nachbau |
| Hilfe ▸ CT-Buch, Hilfe ▸ Präsentation | PDF im Acrobat Reader | dieselben PDFs in Vorschau |

---

## 4. Nur in der macOS-Version

Diese Einträge gibt es in CT1 nicht. Sie stören Anleitungen nicht.

- Datei ▸ Beispieldateien (Untermenü mit den CT1-Beispieldateien; in CT1 über Datei ▸ Öffnen …)
- Ansicht ▸ Schriftart ▸ Schrift vergrößern / Schrift verkleinern
- Einzelverfahren ▸ Visualisierung von Algorithmen ▸ Caesar-Scheibe …
- Hilfe ▸ Kontexthilfe (<kbd>F1</kbd>), Hilfe ▸ CrypTool-Webseite, Hilfe ▸ Lizenz
- Von macOS automatisch hinzugefügt: Bearbeiten ▸ Automatisch ausfüllen, Diktat starten …,
  Emoji & Symbole, die macOS-Einträge im Menü Fenster und „Alle schließen“ (mit <kbd>⌥</kbd>) im Menü Datei
