#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build a Debian 13 (trixie) arm64 root filesystem for the Surface Duo and pack it as a tarball. Runs INSIDE a
# privileged Debian trixie arm64 container (Docker on an Apple-silicon Mac); nothing here touches a phone.
# The published repo has no "prepare" script, so this reconstructs it from what is published: the package set in
# tools/linux/debian/duo-debian-setup.sh, tools/linux/system/install.sh, duo-files.list and the kernel build's modules.
#   usage: make-debian-root.sh <repo> <kernel build dir> <authorized_keys> <out.tar.zst> [root dir]
# Stages are marked in <root>/.duo-stage-* so a failed run continues where it stopped.
set -e
REPO=$1; K=$2; KEYS=$3; OUT=$4; R=${5:-/root/debian-root}; L=$REPO/tools/linux
[ -d "$L/system" ] && [ -s "$KEYS" ] && [ -n "$OUT" ] || { sed -n 2,9p "$0"; exit 1; }
# STOP_AFTER=packages: only the Debian base + packages (needs no kernel build yet)
export DEBIAN_FRONTEND=noninteractive LANG=C
command -v debootstrap > /dev/null || { apt-get -q update > /dev/null; apt-get -q -y install debootstrap zstd > /dev/null; }
stage() { [ -f $R/.duo-stage-$1 ]; }
done_() { touch $R/.duo-stage-$1; echo "== stage $1 done"; }

if ! stage base; then
	rm -rf $R; mkdir -p $R
	debootstrap --arch=arm64 --variant=minbase \
		--include=systemd-sysv,udev,dbus,kmod,ca-certificates,apt-utils,locales trixie $R http://deb.debian.org/debian > /root/debootstrap.log 2>&1 \
		|| { tail -5 /root/debootstrap.log; exit 1; }
	done_ base
fi
cat > $R/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
mnt() { for m in proc sys dev dev/pts; do mountpoint -q $R/$m || mount --bind /$m $R/$m; done; }
umnt() { for m in dev/pts dev sys proc; do umount -l $R/$m 2>/dev/null || true; done; }
trap umnt EXIT; mnt
printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod 755 $R/usr/sbin/policy-rc.d
rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf   # (the finished root has a symlink here)
# our own /etc files (nftables.conf, ...) are placed before their packages: never stop at a conffile prompt
printf 'Dpkg::Options { "--force-confdef"; "--force-confold"; };\n' > $R/etc/apt/apt.conf.d/90duo-confold

if ! stage packages; then
	chroot $R apt-get -q update > /dev/null
	# the system under the Duo layer: what duo-debian-setup.sh assumes is already there
	chroot $R apt-get -q -y --no-install-recommends install \
		sudo openssh-server network-manager python3 e2fsprogs util-linux-extra mount procps iputils-ping less nano curl \
		gnupg dbus-user-session polkitd rtkit upower udisks2 \
		pipewire-audio pipewire-pulse wireplumber alsa-utils xwayland fonts-noto-core fonts-noto-color-emoji \
		plasma-mobile plasma-mobile-tweaks plasma-workspace kwin-wayland plasma-nm plasma-pa powerdevil \
		konsole dolphin kate qml6-module-qtquick-virtualkeyboard maliit-keyboard xdg-user-dirs \
		qml6-module-org-kde-kirigamiaddons-formcard qml6-module-org-kde-kirigamiaddons-components \
		qml6-module-org-kde-kirigamiaddons-delegates qml6-module-org-kde-kirigamiaddons-labs-components \
		qml6-module-org-kde-kirigamiaddons-settings qml6-module-org-kde-kirigamiaddons-datetime \
		qml6-module-qt-labs-platform qt6-svg-plugins qt6-image-formats-plugins kimageformat6-plugins \
		> /root/apt-base.log 2>&1 || { tail -8 /root/apt-base.log; exit 1; }
		# (Debian's plasma-mobile does not depend on the Kirigami Addons modules its home screen imports, and with
		#  --no-install-recommends Qt has no SVG decoder: without these the shell shows only "Type ... unavailable")
	done_ packages
fi

[ "${STOP_AFTER:-}" = packages ] && { echo "PACKAGES_DONE"; exit 0; }
[ -f "$K/include/config/kernel.release" ] || { echo "no kernel build in $K"; exit 1; }
REL=$(cat $K/include/config/kernel.release)
if ! stage modules-$REL; then
	# kernel modules, laid out as the services expect: /lib/duo/<release>/{*.ko,venus/,camera/}
	M=$R/lib/duo/$REL; rm -rf $R/lib/duo $R/lib/modules; mkdir -p $M/venus $M/camera
	cpk() { d=$1; shift; for m in "$@"; do [ -f $K/$m.ko ] && cp $K/$m.ko $d/ || echo "WARNING: no ${m##*/}.ko"; done; }
	cpk $M drivers/power/supply/qcom_smbx sound/soc/codecs/snd-soc-rt5663 sound/soc/qcom/snd-soc-sdm845 \
		drivers/input/misc/da7280 drivers/leds/led-class-flash drivers/leds/flash/leds-qcom-flash \
		drivers/power/reset/qcom-pon drivers/net/ipa/ipa
	cpk $M/venus drivers/media/mc/mc drivers/media/v4l2-core/videodev drivers/media/common/videobuf2/videobuf2-common \
		drivers/media/common/videobuf2/videobuf2-v4l2 drivers/media/v4l2-core/v4l2-mem2mem \
		drivers/media/common/videobuf2/videobuf2-memops drivers/media/common/videobuf2/videobuf2-dma-contig \
		drivers/media/platform/qcom/venus/venus-core drivers/media/platform/qcom/venus/venus-dec \
		drivers/media/platform/qcom/venus/venus-enc
	cpk $M/camera drivers/media/v4l2-core/v4l2-async drivers/media/v4l2-core/v4l2-fwnode drivers/media/v4l2-core/v4l2-cci \
		drivers/media/common/videobuf2/videobuf2-dma-sg drivers/clk/qcom/camcc-sm8150 drivers/i2c/busses/i2c-qcom-cci \
		drivers/media/platform/qcom/camss/qcom-camss drivers/media/i2c/dw9719
	# every module of the build as well, for modprobe (most drivers are built in)
	make -s -C $K ARCH=arm64 INSTALL_MOD_PATH=$R INSTALL_MOD_STRIP=1 DEPMOD=true modules_install > /root/modinst.log 2>&1 || tail -3 /root/modinst.log
	rm -f $R/lib/modules/$REL/build $R/lib/modules/$REL/source; chroot $R depmod $REL || true
	echo "modules: $(find $M -name '*.ko' | wc -l) in /lib/duo/$REL, $(find $R/lib/modules/$REL -name '*.ko*' | wc -l) in /lib/modules"
	chroot $R chown -R root:root /lib/duo; done_ modules-$REL
fi
if ! stage duo; then
	# the files of duo-files.list + the system layer
	grep -v '^#' $L/debian/duo-files.list | while IFS=: read s d; do [ -n "$s" ] || continue
		mkdir -p "$R/$(dirname "$d")"; tr -d '\r' < "$L/$s" > "$R/$d"; case $d in usr/local/sbin/*) chmod 755 "$R/$d";; esac; done
	sh $L/system/install.sh --init=systemd --root=$R --desktop=plasma
	# inputs duo-debian-setup.sh takes from /tmp
	cp $L/debian/opensnitch-rules.sh $L/debian/waydroid-nft.conf $L/modem/duo-gps.c $R/tmp/
	tr -d '\r' < $L/debian/duo-debian-setup.sh > $R/tmp/duo-debian-setup.sh
	chroot $R dpkg --force-confdef --force-confold --configure -a > /dev/null 2>&1 || true
	chroot $R sh /tmp/duo-debian-setup.sh 2>&1 | tee /root/duo-setup.log | tail -15
	grep -q '^setup done' /root/duo-setup.log || { echo "duo-debian-setup did not finish"; exit 1; }
	done_ duo
fi

if ! stage fork; then
	# --- this fork's layout: Debian is the whole `win` partition (duo.root=win), booted tethered ---
	# no /mnt/duo-part here (that exists only with duo.rootdir): a failing fstab mount would stop the boot
	sed -i '\|^/mnt/duo-part |d' $R/etc/fstab 2>/dev/null || true
	# CLAUDE.md rule 4: nothing may change slot state from the OS
	chroot $R systemctl mask qbootctl.service > /dev/null 2>&1 || true
	[ ! -e $R/usr/bin/qbootctl ] || { echo "qbootctl is installed - refusing"; exit 1; }
	# Wi-Fi: only the host firmware file out of firmware-atheros (its generic board-2.bin crashes the Duo's Wi-Fi)
	if [ ! -e $R/lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin ]; then
		chroot $R sh -c 'cd /tmp && rm -rf fwa && mkdir fwa && cd fwa && apt-get -q download firmware-atheros > /dev/null 2>&1 &&
			dpkg-deb -x firmware-atheros_*.deb x && mkdir -p /lib/firmware/ath10k/WCN3990/hw1.0 &&
			cp x/usr/lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin* /lib/firmware/ath10k/WCN3990/hw1.0/ && echo "wifi firmware: firmware-5.bin"; rm -rf /tmp/fwa'
	fi
	# touch daemon (not packaged in Debian): built by make-iptsd.sh into /root/iptsd-out
	if [ -x /root/iptsd-out/iptsd ]; then mkdir -p $R/opt/duo/bin; cp /root/iptsd-out/iptsd* $R/opt/duo/bin/; echo "iptsd: installed"
	else echo "WARNING: no /root/iptsd-out/iptsd - touch will not work until it is added"; fi
	# sensors (make-sensor-debs.sh): libssc + iio-sensor-proxy with SSC support (held: trixie's own has none) and the
	# hinge/posture reader; then the two-screen layer: duo-posture (user unit) and the KWin dual-screen script
	S=/root/sensor-debs
	if [ -f $S/duo-ssc-read ] && ls $S/libssc2_*.deb > /dev/null 2>&1; then
		mkdir -p $R/tmp/sd; cp $S/*.deb $R/tmp/sd/
		chroot $R sh -c 'apt-get -q update > /dev/null && apt-get -q -y --no-install-recommends install /tmp/sd/*.deb > /dev/null 2>&1 &&
			apt-mark hold libssc2 libssc-bin iio-sensor-proxy > /dev/null' || { echo "sensor packages failed"; exit 1; }
		install -m755 $S/duo-ssc-read $R/usr/local/bin/duo-ssc-read; echo "sensors: libssc + iio-sensor-proxy (SSC) + duo-ssc-read"
	else echo "WARNING: no $S (make-sensor-debs.sh) - no rotation, hinge or light sensor on the desktop"; fi
	for u in duo-posture duo-left-panels; do
		install -D -m644 $L/debian/$u.service $R/usr/lib/systemd/user/$u.service
		chroot $R systemctl --global enable $u.service > /dev/null 2>&1
	done
	rm -rf $R/usr/share/kwin/scripts/duo-dualscreen; mkdir -p $R/usr/share/kwin/scripts
	cp -r $L/debian/kwin-duo-dualscreen $R/usr/share/kwin/scripts/duo-dualscreen
	find $R/usr/share/kwin/scripts/duo-dualscreen -name '._*' -delete
	printf '[Plugins]\nduo-dualscreenEnabled=true\n' > $R/etc/xdg/kwinrc
	ln -sf /usr/libexec/duo/duo-reset $R/usr/local/sbin/duo-reset
	# developer keyboard: Esc/Tab/Ctrl/Alt/arrows row + programming symbols on long press (maliit, diverted layout)
	ROOT=$R sh $L/debian/maliit-dev/install.sh
	# each screen's navigation bar closes the app on its own screen
	ROOT=$R sh $L/debian/plasma-mobile-perscreen/install.sh
	# closing the phone = a laptop lid (duo-lid, enabled by install.sh): Plasma turns the screens off, logind ignores it
	install -D -m644 $L/debian/50-duo-lid.conf $R/etc/systemd/logind.conf.d/50-duo-lid.conf
	install -D -m644 $L/debian/powerdevilrc $R/etc/xdg/powerdevilrc
	# s2idle: hexagonrpcd stopped before, the SLPI recovered (if needed) and the sensors restarted after
	mkdir -p $R/usr/lib/systemd/system-sleep
	ln -sf /usr/libexec/duo/duo-sensors-resume $R/usr/lib/systemd/system-sleep/duo-sensors
	# app store: Discover with Flatpak + Flathub only. Debian builds Discover's PackageKit (system package) backend
	# into plasma-discover; it is diverted away so Discover never upgrades the system (held/diverted Duo packages).
	# No fwupd backend: nothing offers firmware updates on this phone.
	chroot $R apt-get -q -y --no-install-recommends install plasma-discover plasma-discover-backend-flatpak flatpak \
		> /dev/null 2>&1 || { echo "Discover/Flatpak packages failed"; exit 1; }
	D=/usr/lib/aarch64-linux-gnu/qt6/plugins; mkdir -p $R$D/discover-disabled
	chroot $R dpkg-divert --quiet --local --rename --divert $D/discover-disabled/packagekit-backend.so \
		--add $D/discover/packagekit-backend.so
	chroot $R flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	# hingeboard (tools/linux/hingeboard): the laptop keyboard on the lower screen when the screens are stacked
	chroot $R apt-get -q -y --no-install-recommends install python3-gi python3-gi-cairo python3-cairo python3-evdev \
		gir1.2-gtk-4.0 gir1.2-gtk4layershell-1.0 libgtk4-layer-shell0 > /dev/null 2>&1 || { echo "hingeboard packages failed"; exit 1; }
	for f in hingeboard hingeboard-dictate.py; do install -m755 $L/hingeboard/$f $R/usr/local/bin/$f; done
	echo 'KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' \
		> $R/etc/udev/rules.d/70-hingeboard-uinput.rules
	# SSH: keys only; root for service work, `user` for the desktop
	mkdir -p $R/root/.ssh $R/home/user/.ssh; cp "$KEYS" $R/root/.ssh/authorized_keys; cp "$KEYS" $R/home/user/.ssh/authorized_keys
	chmod 700 $R/root/.ssh $R/home/user/.ssh; chmod 600 $R/root/.ssh/authorized_keys $R/home/user/.ssh/authorized_keys
	chroot $R chown -R user:user /home/user
	mkdir -p $R/etc/ssh/sshd_config.d
	printf 'PasswordAuthentication no\nPermitRootLogin prohibit-password\n' > $R/etc/ssh/sshd_config.d/10-duo.conf
	echo 'user ALL=(ALL) NOPASSWD: ALL' > $R/etc/sudoers.d/duo-user; chmod 440 $R/etc/sudoers.d/duo-user
	echo 'en_US.UTF-8 UTF-8' > $R/etc/locale.gen; chroot $R locale-gen > /dev/null; echo 'LANG=en_US.UTF-8' > $R/etc/default/locale
	printf '127.0.0.1 localhost\n127.0.1.1 duo-debian\n' > $R/etc/hosts
	done_ fork
fi
rm -f $R/usr/sbin/policy-rc.d; chroot $R apt-get clean; rm -rf $R/tmp/* $R/var/lib/apt/lists/*_Packages
rm -f $R/etc/resolv.conf; ln -s /run/NetworkManager/resolv.conf $R/etc/resolv.conf
umnt; trap - EXIT
echo "enabled duo units: $(ls $R/etc/systemd/system/multi-user.target.wants 2>/dev/null | grep -c duo)"
tar --numeric-owner --xattrs --exclude='./.duo-stage-*' -C $R -cf - . | zstd -T0 -6 -q -o "$OUT" -f
echo "ROOT_DONE $(du -sh $R | cut -f1) unpacked, $(du -h "$OUT" | cut -f1) packed, kernel $REL"
