#!/bin/sh
# Surface Duo (experimental): shadows /usr/bin/sxmo_rotate.sh (sxmo's hooks dir comes first in its PATH). sxmo's own
# version rotates only the focused screen; here both screens rotate together through duo-sway-posture.
case "$1" in
	isrotated) [ "$(duo-rotation status | gojq -r '.orientation // "normal"')" != normal ] ;;
	rotnormal) exec duo-rotation set normal ;;
	rotright) exec duo-rotation set right-up ;;
	rotleft) exec duo-rotation set left-up ;;
	rotinvert) exec duo-rotation set bottom-up ;;
	*) exec duo-rotation menu ;;
esac
