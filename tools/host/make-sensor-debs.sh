#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Sensors for Debian trixie on the Surface Duo, built on the HOST in a Debian trixie arm64 container (like
# make-debian-root.sh): trixie packages no libssc and builds iio-sensor-proxy without SSC support, so the SLPI sensors
# (accelerometer -> auto-rotate, light, proximity, compass) never reach the desktop. This backports sid's source
# packages (Debian's own packaging, no sid binaries): libssc 0.4.4 and iio-sensor-proxy 3.9 (-Dssc-support=enabled on
# arm64), and builds tools/linux/sensors/duo-ssc-read (hinge angle / posture reader) against that libssc.
#   usage (in the container): make-sensor-debs.sh <repo> [out=/root/sensor-debs]
# make-debian-root.sh installs everything in <out> when it exists.
set -e
REPO=$1; OUT=${2:-/root/sensor-debs}; B=/root/bp
[ -f "$REPO/tools/linux/sensors/duo-ssc-read.c" ] || { sed -n 3,9p "$0"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
echo "deb-src http://deb.debian.org/debian sid main" > /etc/apt/sources.list.d/sid-src.list
apt-get -q update > /dev/null
apt-get -q -y --no-install-recommends install dpkg-dev devscripts equivs gcc pkg-config libglib2.0-dev > /dev/null 2>&1
rm -rf $B; mkdir -p $B; cd $B
apt-get -q source libssc iio-sensor-proxy > /dev/null 2>&1
# a claim that arrives while the sensors are still being opened (duo-sway-posture: it waits for the proxy) never
# started the sensor: no rotation after boot. Ours, as a local version (+duo1).
(cd iio-sensor-proxy-* && patch -p1 < $REPO/tools/linux/sensors/iio-sensor-proxy-3.9-early-claim.patch &&
	DEBEMAIL=duo@localhost dch --local +duo "Start sensors that were claimed while they were being opened." > /dev/null 2>&1)
for p in libssc-* iio-sensor-proxy-*; do
	[ -d $p ] || continue
	(cd $p && mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control > ../bd-$p.log 2>&1) || { tail -15 bd-$p.log; exit 1; }
	(cd $p && dpkg-buildpackage -b -us -uc -j$(nproc) > ../build-$p.log 2>&1) || { tail -30 build-$p.log; exit 1; }
	case $p in libssc-*) apt-get -q -y --no-install-recommends install ./libssc2_*.deb ./libssc-dev_*.deb ./gir1.2-ssc*.deb > /dev/null 2>&1 ;; esac
done
mkdir -p $OUT; rm -f $OUT/*
cp libssc2_*.deb libssc-bin_*.deb iio-sensor-proxy_*.deb $OUT/
cc -O2 -Wall -o $OUT/duo-ssc-read $REPO/tools/linux/sensors/duo-ssc-read.c $(pkg-config --cflags --libs libssc gio-2.0)
ls $OUT; echo SENSOR_DEBS_DONE
