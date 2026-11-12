# CrypTool für macOS

Native Version von [CrypTool 1](https://github.com/cryptool-org/cryptool1) für Macs mit Apple Silicon – ohne Emulation.
Menüs, Dialoge und Online-Hilfe entsprechen der Windows-Version, damit beide im Unterricht nebeneinander genutzt werden können.

## Installation

1. `CrypTool.dmg` unter [Releases](../../releases) herunterladen.
2. `CrypTool` in den Ordner *Programme* ziehen.
3. Beim ersten Start: Rechtsklick auf die App → *Öffnen* (die App ist nicht von Apple beglaubigt).

Voraussetzung: Mac mit Apple Silicon, macOS 14 oder neuer.

## Selbst bauen

```bash
scripts/build-app.sh        # erzeugt build/CrypTool.app (Xcode Command Line Tools genügen)
```

## Hinweise

Inoffizielle Portierung. Nicht enthalten sind die gitterbasierten Angriffe auf RSA und der Seitenkanalangriff auf Textbook-RSA (die Menüpunkte zeigen die zugehörige CT1-Hilfe).

## Lizenz

Apache License 2.0, wie CrypTool 1 (© CrypTool-Team, [cryptool.org](https://www.cryptool.org)). Siehe [LICENSE](LICENSE) und [NOTICE](NOTICE).
