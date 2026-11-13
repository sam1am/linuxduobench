#!/bin/sh
# Surface Duo (Sxmo trial): shadows /usr/bin/sxmo_dmenu.sh (sxmo's hooks dir comes first in its PATH).
# Before a menu opens, the tap-outside layer (duo-menu-scrim) is put up and we wait until it is on screen; only then
# does bemenu start, so the menu always lies above it (both use the same layer: the later one is on top).
case "$1" in
	isopen|close) exec /usr/bin/sxmo_dmenu.sh "$@" ;;
esac
f=$XDG_RUNTIME_DIR/duo-scrim.fifo s=$XDG_RUNTIME_DIR/duo-scrim.shown
scrim() { [ -p "$f" ] && timeout 1 sh -c 'echo "$1" > "$2"' _ "$1" "$f"; }
if [ -p "$f" ]; then
	rm -f "$s"; scrim show
	i=0; while [ ! -e "$s" ] && [ $i -lt 40 ]; do sleep 0.01; i=$((i + 1)); done
fi
/usr/bin/sxmo_dmenu.sh "$@"
rc=$?
scrim hide
exit $rc
