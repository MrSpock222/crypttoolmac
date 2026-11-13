#!/bin/bash
# Misst die Größe aller Dialoge, ohne ein Fenster zu zeigen (Entwicklerhilfe).
#
#   scripts/build-app.sh && scripts/audit-layout.sh [Ausgabedatei]
#
# Ausgabe je Dialog: Menüpunkt, Art (sheet/tool), Titel, ideal=<Wunschgröße ohne Umbruch>,
# size=<tatsächliche Startgröße>. Auffällig sind size-Breiten über ~1000 und -Höhen über ~800.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="build/CrypTool.app/Contents/MacOS/CrypTool"
OUT="${1:-/dev/stdout}"
[ -x "$BIN" ] || { echo "Erst scripts/build-app.sh ausführen." >&2; exit 1; }
start=0
: > "${OUT}.tmp.$$"
while :; do
    out="$(CT_LAYOUT_AUDIT=$start "$BIN" 2>/dev/null || true)"
    printf '%s\n' "$out" >> "${OUT}.tmp.$$"
    if printf '%s\n' "$out" | /usr/bin/grep -aq '^DONE'; then break; fi
    last="$(printf '%s\n' "$out" | /usr/bin/grep -a '^ITEM' | tail -1 | cut -f2)"
    [ -n "$last" ] || { echo "Prüflauf ohne Ergebnis abgebrochen." >&2; break; }
    start=$((last + 1))
done
cat "${OUT}.tmp.$$" > "$OUT"
rm -f "${OUT}.tmp.$$"
