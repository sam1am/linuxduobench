#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Surface Duo: install the developer keyboard (maliit-keyboard's English layout + Esc/Tab/Ctrl/Alt/arrows row and
# programming symbols on long press) and a taller keyboard profile for the extra row.
#   usage (root, on the phone or with ROOT=<debian root>):  sh install.sh
# The package's Keyboard_en.qml is diverted (dpkg-divert), so upgrades of maliit-keyboard keep this one; undo:
#   rm <dir>/Keyboard_en.qml <dir>/DevKey.qml <dir>/ModKey.qml && dpkg-divert --rename --remove <dir>/Keyboard_en.qml
set -e
S=$(cd "$(dirname "$0")" && pwd); R=${ROOT:-}
D=/usr/lib/aarch64-linux-gnu/maliit/keyboard2/languages/en
run() { if [ -n "$R" ]; then chroot "$R" "$@"; else "$@"; fi; }
[ -f "$R$D/Keyboard_en.qml" ] || { echo "no maliit-keyboard English layout at $R$D"; exit 1; }
run dpkg-divert --quiet --local --rename --divert $D/Keyboard_en.qml.distrib --add $D/Keyboard_en.qml
for f in Keyboard_en.qml DevKey.qml ModKey.qml; do install -m644 "$S/$f" "$R$D/$f"; done
# one more row: a taller keyboard (default.json has 0.30 / 0.39 of the screen height)
P=/usr/share/maliit/keyboard2/devices
sed -e 's/"keyboardHeightPortrait": *[0-9.]*/"keyboardHeightPortrait": 0.36/' \
    -e 's/"keyboardHeightLandscape": *[0-9.]*/"keyboardHeightLandscape": 0.45/' "$R$P/default.json" > "$R$P/duo.json"
printf "[org.maliit.keyboard.maliit]\ndevice='duo'\n" > "$R/usr/share/glib-2.0/schemas/90-duo-maliit.gschema.override"
run glib-compile-schemas /usr/share/glib-2.0/schemas
echo "developer keyboard installed ($D, profile $P/duo.json)"
