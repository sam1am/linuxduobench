#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# The Duo's desktop: Sxmo on Sway, set up for two independent screens (2026-11-13; replaces Plasma Mobile).
# Installs into a Debian root (ROOT, default /) for the desktop user (DUO_USER, default user, uid 10000):
#   bin/*     -> /usr/local/bin   (duo-sway-posture, duo-stack, duo-overview, duo-gesture, ... and the device profile)
#   config/*  -> ~/.config        (sway config, sxmo profile + hooks, foot, mako, keyboard look, rotation mode)
#   the device's sxmo hooks dir   (qcom,sm8150-mtp -> sxmo's three-button-touchscreen hooks)
#   the patched keyboard          (WVKBD=<path to a wvkbd-mobintl built by wvkbd/make-wvkbd.sh>; optional)
# The packages (sxmo-utils, sway, ...) are installed by make-debian-root.sh. Re-running overwrites our files only.
#   usage: ROOT=/path/to/root [WVKBD=/root/wvkbd-out/wvkbd-mobintl] sh tools/linux/sxmo/install.sh
set -e
D=$(cd "$(dirname "$0")" && pwd)
ROOT=${ROOT:-}; U=${DUO_USER:-user}; H=$ROOT/home/$U
for f in "$D"/bin/*; do install -m755 "$f" "$ROOT/usr/local/bin/${f##*/}"; done
# sxmo looks for hooks of the device named by the first device-tree compatible (this kernel: qcom,sm8150-mtp)
mkdir -p "$ROOT/usr/share/sxmo/default_hooks"
ln -sfn three_button_touchscreen "$ROOT/usr/share/sxmo/default_hooks/qcom,sm8150-mtp"
(cd "$D/config" && find . -type f ! -name '._*' ! -name '.DS_Store') | while read -r f; do
	mkdir -p "$H/.config/$(dirname "$f")"
	case "$f" in ./duo/rotation-mode) [ -e "$H/.config/$f" ] && continue ;; esac   # the user's own choice stays
	cp "$D/config/$f" "$H/.config/$f"
done
chmod 755 "$H"/.config/sxmo/hooks/*.sh
# sxmo's own idle suspend stays off: duo-lid is the only way to sleep (closed for 30 s)
mkdir -p "$H/.cache/sxmo"; : > "$H/.cache/sxmo/sxmo.nosuspend"
if [ -n "$WVKBD" ] && [ -x "$WVKBD" ]; then
	install -m755 "$WVKBD" "$ROOT/usr/local/bin/wvkbd-mobintl"   # ahead of Debian's /usr/bin one in PATH
	echo "sxmo: patched wvkbd installed"
else
	echo "sxmo: WARNING no patched wvkbd (wvkbd/make-wvkbd.sh): the stock keyboard has no long press or haptics"
fi
if [ -n "$ROOT" ]; then
	chroot "$ROOT" chown -R "$U:$U" "/home/$U/.config" "/home/$U/.cache"
else
	chown -R "$U:$U" "$H/.config" "$H/.cache"
fi
echo "sxmo: Duo desktop installed for $U ($(ls "$D/bin" | wc -l) tools)"
