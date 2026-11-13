#!/bin/sh
# Surface Duo (Sxmo trial): power button = screen on/off, like a phone without a lock screen. sxmo's own handler sends a
# press from "screen off" to "lock" (screen on but touch off, dark again 8 s later), which felt like a broken, very
# short screen timeout. Everything else: sxmo's three-button handler.
case "$1" in
powerbutton_one|powerbutton_two)
	if grep -q unlock "$SXMO_STATE" 2> /dev/null; then
		exec sxmo_hook_screenoff.sh
	else
		exec sxmo_hook_unlock.sh
	fi ;;
esac
exec /usr/share/sxmo/default_hooks/three_button_touchscreen/sxmo_hook_inputhandler.sh "$@"
