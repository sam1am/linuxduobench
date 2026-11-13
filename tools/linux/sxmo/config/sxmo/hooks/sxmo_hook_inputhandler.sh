#!/bin/sh
# Surface Duo: power button = screen on/off, like a phone without a lock screen. sxmo's own handler sends a press from
# "screen off" to "lock" (screen on but touch off, dark again 8 s later), which felt like a broken, very short screen
# timeout. Volume keys = volume (sxmo's three-button profile uses them for its menu and the keyboard; on the Duo
# those are gestures); sxmo shows its volume bar. Everything else: sxmo's three-button handler.
case "$1" in
volup_one) exec sxmo_audio.sh vol up 5 ;;
volup_two|volup_three) exec sxmo_audio.sh vol up 10 ;;
voldown_one) exec sxmo_audio.sh vol down 5 ;;
voldown_two|voldown_three) exec sxmo_audio.sh vol down 10 ;;
powerbutton_one|powerbutton_two)
	if grep -q unlock "$SXMO_STATE" 2> /dev/null; then
		exec sxmo_hook_screenoff.sh
	else
		exec sxmo_hook_unlock.sh
	fi ;;
esac
exec /usr/share/sxmo/default_hooks/three_button_touchscreen/sxmo_hook_inputhandler.sh "$@"
