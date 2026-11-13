#!/bin/sh
# Surface Duo (experimental): shadows /usr/bin/sxmo_autorotate.sh (it polls a sensor this phone does not expose and
# rotates one screen). The rotation modes live in duo-rotation; this just opens its menu.
exec duo-rotation menu
