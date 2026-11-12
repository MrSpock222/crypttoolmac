# Nicht enthaltene Funktionen und Abweichungen

Vergleich der macOS-Version (1.2.0) mit CrypTool 1.4.x für Windows (deutsch).

Alle 201 Menüeinträge von CT1 (Text-, Hex-, Diagramm- und 3D-Fenster) gibt es auf dem Mac
mit demselben Namen an derselben Stelle. Nur 1 Eintrag führt noch zu einem Hinweis (Abschnitt 1).

---

## 1. Nicht enthaltene Funktionen

Nicht nachgebaut ist nur der **Seitenkanalangriff auf „Textbook-RSA“**.

Der Menüeintrag bleibt **aktiv** (nicht ausgegraut), damit man in einer Anleitung dieselben
Klicks machen kann. Ein Klick zeigt:

1. ein Hinweisfenster

   > **Nicht enthalten**
   >
   > Diese Funktion von CrypTool 1 ist in der macOS-Version nicht enthalten.
   >
   > Die Beschreibung aus der CT1-Online-Hilfe wird jetzt angezeigt.
   >
   > [OK]

2. danach das Hilfefenster „CrypTool-Hilfe – *Seitentitel*“ mit der Original-Hilfeseite aus CT1.

| Menüeintrag | Angezeigte Hilfeseite |
|---|---|
| Analyse ▸ Asymmetrische Verfahren ▸ Seitenkanalangriff auf "Textbook-RSA" … | „Seitenkanalangriff auf "Textbook-RSA"“ (`hid_einzelverfahren_sidechannelattack_on_hybridencryption.html`) |

Weitere Hinweise:

- Klickt man vorher in der Symbolleiste auf das Fragezeichen (Kontexthilfe), erscheint direkt die Hilfeseite, ohne Hinweisfenster.
- Es fehlen auch alle Dialoge dieser Funktion, z. B. „Vorbereitungen durchführen“,
  die Fenster von Alice, Bob und Trudy und der Bericht.
- Die weiteren Hilfeseiten dazu (z. B. „Hinweise zur Durchführung des Seitenkanalangriffs“) lassen sich
  über Index und Suche öffnen. Sie beschreiben aber die Windows-Funktion.
- Diese Dateien gehören nur zum Seitenkanalangriff und fehlen:
  `letterFromAliceToBob-DECRYPTED-de.txt`, `letterFromAliceToBob-ENCRYPTED-de.hex` und der Schlüssel
  `[SideChannelAttack][Bob][RSA-512][1152179494][PIN=1234]`.

### Gitterbasierte Angriffe auf RSA – jetzt enthalten

Die drei gitterbasierten Angriffe sind seit Version 1.2.0 nativ nachgebaut (LLL-Gitterreduktion
und Coppersmith/Howgrave-Graham, Rechenkern in `CTBigNum`). Jeder Dialog hat „Beispiel erzeugen“,
um passende Parameter zu füllen, und „Starten“.

| Menüeintrag | Verfahren |
|---|---|
| … ▸ Gitterbasierte Angriffe auf RSA ▸ Faktorisieren mit teilweise bekanntem p … | Coppersmith (höchst- oder niederstwertige Bits von p), nötig: ⌈n/4⌉+1 Bit von p |
| … ▸ Gitterbasierte Angriffe auf RSA ▸ Angriff auf stereotype Nachrichten … | Coppersmith bei kleinem e (z. B. 3), unbekannter Teil < N^(1/e) |
| … ▸ Gitterbasierte Angriffe auf RSA ▸ Angriff auf kleine geheime Schlüssel … | Kettenbruchverfahren nach Wiener |

Die Einträge gibt es wie in CT1 sowohl unter *Einzelverfahren ▸ RSA-Kryptosystem* als auch unter
*Analyse ▸ Asymmetrische Verfahren*.

**Unterschied beim Angriff auf kleine geheime Schlüssel:** CT1 verwendet das Gitterverfahren nach
Blömer/May (δ = log(d)/log(N) < 0,290). Die macOS-Version verwendet das Kettenbruchverfahren nach
Wiener; es ist einfacher und immer zuverlässig, deckt aber nur δ < 0,25 ab. Für Unterrichtsbeispiele
mit kleinem d genügt das; der Dialog weist darauf hin.

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
