#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# DESTROYS the Windows install: formats the partition NAMED "win" (UFS unit 0) as ext4 for the Debian root.
# Runs ON THE PHONE in the RAM shell, fed over SSH from the host:
#   ssh root@169.254.66.1 sh < tools/host/format-win.sh
# Optional: EXPECT_SECTORS=<size of win in 512-byte sectors, from your own partition dump> as an extra guard:
#   ssh root@169.254.66.1 EXPECT_SECTORS=209187776 sh < tools/host/format-win.sh
# The target is found by partition name, never by sdX letter (letters change between boots; see CLAUDE.md), and it
# must still be the Windows NTFS volume "MainOS". Anything unexpected stops it before mkfs runs.
set -e
# (the trailing `true`: the loop's last grep fails, which with set -e would end the script silently here)
P=$(for d in /sys/class/block/sd*; do grep -q "^PARTNAME=win\$" $d/uevent && echo ${d##*/}; done; true)
[ "$(echo "$P" | wc -w)" = 1 ] || { echo "STOP: partition 'win' not found exactly once ($P)"; exit 1; }
[ -z "$EXPECT_SECTORS" ] || [ "$(cat /sys/class/block/$P/size)" = "$EXPECT_SECTORS" ] || { echo "STOP: size mismatch"; exit 1; }
[ "$(blkid -o value -s PARTLABEL /dev/$P)" = win ] || { echo "STOP: PARTLABEL mismatch"; exit 1; }
[ "$(blkid -o value -s TYPE /dev/$P)" = ntfs ] && [ "$(blkid -o value -s LABEL /dev/$P)" = MainOS ] \
	|| { echo "STOP: /dev/$P is not the Windows NTFS volume (already formatted?)"; exit 1; }
grep -q "^/dev/$P " /proc/mounts && { echo "STOP: /dev/$P is mounted"; exit 1; }
echo "formatting /dev/$P (PARTNAME=win, NTFS MainOS)"
mkfs.ext4 -F -q -L duo-debian /dev/$P
blkid /dev/$P
echo FORMAT_DONE
