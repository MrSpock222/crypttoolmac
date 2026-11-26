# CrypTool für macOS

Native Version von [CrypTool 1](https://github.com/cryptool-org/cryptool1) für Macs mit Apple Silicon – ohne Emulation.
Menüs, Dialoge und Online-Hilfe entsprechen der englischen Windows-Version, damit beide im Unterricht nebeneinander genutzt werden können
(bis Version 1.4.0 deutsch).

## Installation

1. `CrypTool.dmg` unter [Releases](../../releases) herunterladen.
2. `CrypTool` in den Ordner *Programme* ziehen.
3. Beim ersten Start warnt macOS, weil die App nicht von Apple beglaubigt ist: App einmal öffnen, dann
   *Systemeinstellungen → Datenschutz & Sicherheit* → bei CrypTool *Dennoch öffnen* klicken (nur einmal nötig).
   Alternativ im Terminal: `xattr -dr com.apple.quarantine /Applications/CrypTool.app`

Voraussetzung: Mac mit Apple Silicon, macOS 14 oder neuer.
Neue Versionen meldet die App selbst (*CrypTool → Check for Updates...*).

## Selbst bauen

```bash
scripts/build-app.sh        # erzeugt build/CrypTool.app (Xcode Command Line Tools genügen)
```

## Hinweise

Inoffizielle Portierung. Was fehlt oder anders ist: [NICHT-ENTHALTEN.md](NICHT-ENTHALTEN.md).

## Lizenz

Apache License 2.0, wie CrypTool 1 (© CrypTool-Team, [cryptool.org](https://www.cryptool.org)). Siehe [LICENSE](LICENSE) und [NOTICE](NOTICE).
