#!/bin/sh
# configversion: 27538f7293527f58c6f44839c69aeb85
# Surface Duo (Sxmo trial): the Apps menu lists every installed app (Debian + Flatpak), not only the ones sxmo knows
# by name. Lines: "label ^ 0 ^ command" (duo-apps).
command -v foot > /dev/null && printf '%s ^ 0 ^ %s\n' "Terminal (foot)" "foot $SHELL"
exec duo-apps
