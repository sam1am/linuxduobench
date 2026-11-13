#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Build the Duo's on-screen keyboard: Debian trixie's wvkbd 0.15 + wvkbd-0.15-duo.patch (long-press alternates on the
# letters, a highlight that outlasts fast taps, da7280 haptics; see duo.c in the patch). Runs INSIDE a Debian trixie
# arm64 container (as make-debian-root.sh), never on the phone.
#   usage: make-wvkbd.sh <repo> [out dir, default /root/wvkbd-out]   -> <out>/wvkbd-mobintl, ends WVKBD_DONE
set -e
REPO=$1; OUT=${2:-/root/wvkbd-out}
P=$REPO/tools/linux/sxmo/wvkbd/wvkbd-0.15-duo.patch
[ -f "$P" ] || { sed -n 2,6p "$0"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
grep -q deb-src /etc/apt/sources.list.d/debian.sources 2> /dev/null ||
	sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
apt-get -q update > /dev/null
apt-get -q -y build-dep wvkbd > /dev/null 2>&1
apt-get -q -y install build-essential dpkg-dev > /dev/null 2>&1
W=$(mktemp -d); cd "$W"
apt-get -q source wvkbd=0.15-1 > /dev/null 2>&1
cd wvkbd-0.15
patch -p1 < "$P"
make > /tmp/wvkbd-build.log 2>&1 || { tail -20 /tmp/wvkbd-build.log; exit 1; }
mkdir -p "$OUT"; install -m755 wvkbd-mobintl "$OUT/wvkbd-mobintl"
rm -rf "$W"
echo "WVKBD_DONE $OUT/wvkbd-mobintl"
