#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Unpack the Debian root tarball onto the ext4 partition NAMED "win" (made by format-win.sh). Runs on the HOST; the
# phone must be in the RAM shell (duo-shell image) with SSH up.
#   usage: install-debian-root.sh <duo-debian-root.tar.zst> [ssh options...]
#   e.g.   install-debian-root.sh ~/duo-build/duo-debian-root.tar.zst -i ~/.ssh/duo_bench_ed25519
# Writes only to the partition named "win", and only if it carries the label duo-debian and is empty.
set -e
T=$1; shift || true
[ -s "$T" ] || { sed -n 3,7p "$0"; exit 1; }
PH=${DUO_HOST:-root@169.254.66.1}
S() { ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=10 "$@"; }
N=$(zstd -dc "$T" | tar -tf - | wc -l | tr -d ' ')
echo "tarball: $N entries"
S "$@" $PH 'set -e
P=$(for d in /sys/class/block/sd*; do grep -q "^PARTNAME=win\$" $d/uevent && echo ${d##*/}; done; true)
[ "$(echo "$P" | wc -w)" = 1 ] || { echo "STOP: win not found exactly once"; exit 1; }
[ "$(blkid -o value -s PARTLABEL /dev/$P)" = win ] && [ "$(blkid -o value -s TYPE /dev/$P)" = ext4 ] \
	&& [ "$(blkid -o value -s LABEL /dev/$P)" = duo-debian ] || { echo "STOP: /dev/$P is not the duo-debian ext4"; exit 1; }
mkdir -p /mnt/win; grep -q " /mnt/win " /proc/mounts || mount -t ext4 -o rw /dev/$P /mnt/win
[ -z "$(ls -A /mnt/win | grep -v lost+found)" ] || { echo "STOP: /mnt/win is not empty"; umount /mnt/win; exit 1; }
echo "mounted /dev/$P on /mnt/win"'
# (busybox tar returns non-zero because it cannot set symlink times; the entry count below is the real check)
S "$@" $PH 'zstd -dc | tar -x -C /mnt/win; sync' < "$T" || true
S "$@" $PH "cd /mnt/win; n=\$(find . -path ./lost+found -prune -o -print | wc -l); echo \"on phone: \$n entries\";
	cd /; sync; umount /mnt/win; [ \$n = $N ] && echo INSTALL_DONE || echo 'MISMATCH: extract incomplete'"
