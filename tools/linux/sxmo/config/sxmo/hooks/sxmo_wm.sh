#!/bin/sh
# Surface Duo (Sxmo trial): shadows /usr/bin/sxmo_wm.sh for "dpms" only (sxmo's hooks dir comes first in its PATH).
# sxmo's version thinks the screens are already off as soon as ONE output is off - on the Duo the back screen of a
# folded phone is off (duo-sway-posture), so screen-off was skipped and the front screen stayed lit (with touch off).
# Here: "dpms on" = every screen off; "dpms off" = every screen on except a folded-away back screen; the state is
# "on" (screens off) only when no screen is lit. Everything else: sxmo's own sxmo_wm.sh.
[ "$1" = dpms ] || exec /usr/bin/sxmo_wm.sh "$@"
lit=$(swaymsg -t get_outputs -r | gojq -r '[.[] | select(.active and .power)] | length')
case "$2" in
	"") [ "$lit" = 0 ] && printf on || printf off ;;
	on) swaymsg -q -- output '*' power off ;;
	off)
		back=$(cat "$XDG_RUNTIME_DIR/duo-back-screen" 2> /dev/null)
		for o in $(swaymsg -t get_outputs -r | gojq -r '.[] | select(.active) | .name'); do
			[ "$o" = "$back" ] || swaymsg -q -- output "$o" power on
		done ;;
esac
