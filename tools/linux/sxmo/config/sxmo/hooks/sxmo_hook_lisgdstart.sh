#!/bin/sh
# configversion: 23bd844c97427f09e21a2f55520acd00
# Surface Duo (experimental): one lisgd per touchscreen, each with its own panel's rotation, and every gesture tagged
# with the screen it came from (duo-gesture OUT ACTION). Restarted by duo-sway-posture after each rotation.
# Based on /usr/share/sxmo/default_hooks/sxmo_hook_lisgdstart.sh (same gestures, same order).

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

LISGD_THRESHOLD="${SXMO_LISGD_THRESHOLD:-125}"
LISGD_THRESHOLD_PRESSED="${SXMO_LISGD_THRESHOLD_PRESSED:-60}"

dev_of() {   # /dev/input/eventN of an iptsd virtual touchscreen
	for n in /sys/class/input/event*; do
		[ "$(cat "$n/device/name" 2> /dev/null)" = "IPTSD Virtual Touchscreen $1" ] && { echo "/dev/input/${n##*/}"; return; }
	done
}

orient_of() {   # lisgd -o for this output's current sway transform
	case "$(swaymsg -t get_outputs -r | gojq -r --arg o "$1" '.[] | select(.name == $o) | .transform')" in
		90) echo 1 ;; 180) echo 2 ;; 270) echo 3 ;; *) echo 0 ;;
	esac
}

run() {   # $1 = output, $2 = digitizer id
	d=$(dev_of "$2"); [ -n "$d" ] || { echo "no touchscreen $2" >&2; return; }
	g="setsid -f duo-gesture $1"
	lisgd -d "$d" -o "$(orient_of "$1")" -t "$LISGD_THRESHOLD" -T "$LISGD_THRESHOLD_PRESSED" \
	-g "1,DRUL,BR,*,$g bottomrightcorner" \
	-g "1,DLUR,BL,*,$g bottomleftcorner" \
	-g "1,ULDR,TL,*,$g topleftcorner" \
	-g "1,URDL,TR,*,$g toprightcorner" \
	-g "1,LR,L,S,$g backleft" \
	-g "1,RL,R,S,$g backright" \
	-g "1,LR,L,M,$g backleft" \
	-g "1,RL,R,M,$g backright" \
	-g "1,LR,B,L,$g rightbottomedge" \
	-g "1,RL,B,L,$g leftbottomedge" \
	-g "1,LR,L,*,$g rightleftedge" \
	-g "1,RL,R,*,$g leftrightedge" \
	-g "1,DU,L,*,P,$g upleftedge" \
	-g "1,UD,L,*,P,$g downleftedge" \
	-g "1,LR,T,*,P,$g righttopedge" \
	-g "1,RL,T,*,P,$g lefttopedge" \
	-g "1,DU,B,*,$g upbottomedge" \
	-g "1,UD,B,*,$g downbottomedge" \
	-g "1,UD,T,*,$g downtopedge" \
	-g "1,DU,T,*,$g uptopedge" \
	-g "2,UD,T,*,$g twodowntopedge" \
	-g "2,UD,B,*,$g twodownbottomedge" \
	-g "1,DU,R,*,P,$g uprightedge" \
	-g "1,UD,R,*,P,$g downrightedge" \
	-g "1,LR,R,S,$g rightrightedge_short" \
	-g "1,RL,L,S,$g leftrightedge_short" \
	-g "1,RL,*,L,$g longoneleft" \
	-g "1,LR,*,L,$g longoneright" \
	-g "1,DU,*,L,$g longoneup" \
	-g "1,UD,*,L,$g longonedown" \
	-g "1,RL,*,M,$g mediumoneleft" \
	-g "1,LR,*,M,$g mediumoneright" \
	-g "1,DU,*,M,$g mediumoneup" \
	-g "1,UD,*,M,$g mediumonedown" \
	-g "1,RL,*,*,$g oneleft" \
	-g "1,LR,*,*,$g oneright" \
	-g "1,DU,*,*,$g oneup" \
	-g "1,UD,*,*,$g onedown" \
	-g "1,DRUL,*,*,$g upleft" \
	-g "1,URDL,*,*,$g downleft" \
	-g "1,DLUR,*,*,$g upright" \
	-g "1,ULDR,*,*,$g downright" \
	-g "2,RL,*,*,$g twoleft" \
	-g "2,LR,*,*,$g tworight" \
	-g "2,DU,*,*,$g twoup" \
	-g "2,UD,*,*,$g twodown" \
	-g "3,RL,*,*,$g threeleft" \
	-g "3,LR,*,*,$g threeright" \
	-g "3,DU,*,*,$g threeup" \
	-g "3,UD,*,*,$g threedown" &
	pids="$pids $!"
}

pids=
trap 'kill $pids 2> /dev/null; exit 0' TERM INT HUP
run DSI-1 045E:0C02
run DSI-2 045E:0C01
[ -n "$pids" ] || exit 1
wait   # both ended: the service starts them again
