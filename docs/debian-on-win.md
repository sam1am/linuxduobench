# Debian 13 + Sxmo (Sway) on the `win` partition (tethered)

How this fork got a full Debian desktop running from the phone's own storage on a second Surface Duo 1, on
2026-11-11, **without writing any boot, firmware or partition-table data**. Read [`CLAUDE.md`](../CLAUDE.md) first:
its rules are what keep this procedure off the path that bricked the original author's phone.

## The idea
- The Debian root lives on the `win` partition (the Windows-on-ARM install, about 100 GB, UFS unit 0). Windows is
  erased; Android (`userdata`, `super`) and every boot partition stay as they are.
- The kernel is never flashed. Each boot is `fastboot --set-active=a` followed at once by `fastboot boot
  duo-debian.img` from a computer (tethered). That slot change does not persist; a cold boot without the computer
  starts Android, as before.
- The boot image's `/init` (this fork's version) mounts `win` as the root (`duo.root=win`) and starts systemd.
- Nothing in the installed system can change slot state: `qbootctl` is not installed and its service is masked.

What it costs: Windows (and whatever is on it). What can go wrong in the worst case: the same as RAM-booting
any kernel, since no step writes outside `win`.

## Requirements
- Surface Duo 1, bootloader already unlocked (unlocking wipes the phone; never relock).
- A Windows-on-ARM dual-boot layout, i.e. a partition **named** `win` on unit 0. Without one there is nowhere to put
  the root (this guide does not create partitions; editing the GPT is forbidden by `CLAUDE.md`).
- A host with `adb`, `fastboot`, `ssh`, `zstd` and Docker (an Apple-silicon Mac runs the arm64 build natively; on
  x86 use qemu-user binfmt).
- A full partition backup taken first (below).

## 1. Back up every partition you are allowed to read
RAM-boot the shell image (step 3 builds it, or use the release image with your key added), then dump each UFS unit and
the small unit-0 partitions over SSH, verifying SHA-256 on both ends. `tools/host/serial-dump.py` does the same over
the USB serial console (chunked, verified, retried) when the network link is not available. Keep `partitions.txt`
(name, unit, start, size of every partition) with the dump. Resolve every partition **by name**; the `sdX` letters
change between boots.

## 2. Build the kernel and the Debian root (on the host, in Docker)
```sh
docker volume create duo-build
docker run --rm -it --privileged -v duo-build:/root -v "$PWD":/repo debian:trixie bash
# inside:
NO_EFI=1 /repo/tools/linux/kernel/build.sh /repo           # -> /root/build-duo, ends KERNEL_BUILD_DONE
/repo/tools/host/make-sensor-debs.sh /repo                  # -> /root/sensor-debs, ends SENSOR_DEBS_DONE
/repo/tools/linux/sxmo/wvkbd/make-wvkbd.sh /repo            # -> /root/wvkbd-out, ends WVKBD_DONE (the keyboard)
/repo/tools/host/make-debian-root.sh /repo /root/build-duo /repo/keys.pub /root/duo-debian-root.tar.zst
```
`make-debian-root.sh` runs debootstrap (trixie arm64), installs the desktop (Sxmo on Sway, `tools/linux/sxmo`) and the
Duo services, copies the kernel
modules to `/lib/duo/<release>`, installs only `firmware-5.bin` for Wi-Fi, sets up SSH (keys only; `root` and a
desktop user `user`) and packs a tarball of about 1.2 GB. Stages are resumable. The touch daemon `iptsd` is not in
Debian; build it first into `/root/iptsd-out` (static meson build of linux-surface iptsd, `--wrap-mode=forcefallback`).

## 3. Make two boot images
Both are the release RAM image with this fork's `/init`, your SSH keys and a different command line
(`tools/host/repack-ram-image.py` replaces the init and keys; `tools/linux/abl/make-abl-image.sh` builds from scratch).
- **shell** - stays in the RAM shell, radios off, everything read-only:
  `duo.wifi=0 duo.sensors=0 duo.nobt=1 duo.nolpm=1 duo.nocamera=1 duo.novenus=1 duo.nosound=1 duo.nohaptics=1`
- **debian** - boots the root on `win`: `duo.root=win duo.nousbwdt=1 duo.dual=1`

Both also need `duo.vendor_sector=<sector of vendor_a inside super>` if your phone differs from the original author's
(11369472). Read it from the liblp metadata at the start of your `super` dump; ours was 11322400.

## 4. Format `win` (destroys Windows)
Boot the shell image (`adb reboot bootloader`, `fastboot --set-active=a`, `fastboot boot duo-shell.img`), wait for SSH
on `169.254.66.1`, then:
```sh
ssh root@169.254.66.1 EXPECT_SECTORS=<win size from your partitions.txt> sh < tools/host/format-win.sh
```
It finds the partition by name and checks that it is still the NTFS volume `MainOS` and not mounted before running
`mkfs.ext4 -L duo-debian`. It ends with `FORMAT_DONE`.

## 5. Install the root
```sh
tools/host/install-debian-root.sh duo-debian-root.tar.zst -i ~/.ssh/<your key>
```
It mounts the partition named `win` (only if it is the empty `duo-debian` ext4), streams and unpacks the tarball,
compares the entry count, syncs and unmounts. Expect `INSTALL_DONE` after about two minutes. While it syncs, the
phone's console may print "task sync blocked for more than N seconds"; that is the UFS absorbing 3.7 GB and passes.

## 6. Boot Debian
Leave the shell with `devmem 0x0c264000 w 0` (it cold-boots into Android), then:
```sh
adb reboot bootloader
fastboot --set-active=a && fastboot boot duo-debian.img
ssh root@169.254.66.1        # or the desktop user: ssh user@169.254.66.1
```
Sxmo comes up on both screens after about a minute. To return to Android, `devmem 0x0c264000 w 0` as root.

## Status (2026-11-13, one phone)
The desktop is **Sxmo on Sway** (Plasma Mobile until 2026-11-13: too heavy, and its shell assumes one screen). With
only the Sxmo session running the phone uses about 0.8 GB of RAM (Plasma: about 5 GB with the same apps).

| Works | Not yet / untested |
|---|---|
| Both screens independent: own bar, workspace, touch, gestures, keyboard | Speaker tuning (EQ / loudness) |
| One app per screen + overview (switch, close, bring across) | Camera, modem, Bluetooth audio |
| Rotation: auto, manual, semi-auto (tap a button to confirm) | hingeboard under Sway (not installed) |
| Fold back: the touched screen turns off, apps stay where they are | |
| Keyboard with long-press symbols and haptics (patched wvkbd) | |
| Wi-Fi, Chromium, Discover (Flatpak), Dolphin, foot | |
| Per-screen brightness, screen off on idle / power key / closing | |
| Sensors: accel, hinge angle, posture, hall, light, proximity; SSH over USB | |
| Speaker + microphones (PipeWire), volume keys with an on-screen bar | |

## The two-screen layer
Everything below is installed by `make-debian-root.sh` (sensor packages from `tools/host/make-sensor-debs.sh`).
- **Sensors.** Trixie has no libssc and builds iio-sensor-proxy without SSC support. `make-sensor-debs.sh` backports
  sid's libssc 0.4.4 and iio-sensor-proxy 3.9 (Debian's own packaging; held with `apt-mark`) and builds
  `duo-ssc-read` (`tools/linux/sensors/`), a generic SSC reader for the sensors libssc has no class for:
  `duo-ssc-read hinge_angle posture` prints `hinge_angle 188.857 0.000 178.144` (degrees; 0 closed, 180 flat,
  ~355 back to back).
- **The desktop** (`tools/linux/sxmo/`, installed by `tools/linux/sxmo/install.sh`): Debian's Sxmo (sxmo-utils) on
  Sway, configured for two independent screens. `bin/` goes to `/usr/local/bin`, `config/` to the user's `~/.config`
  (`sxmo/sway` is the Sway config; `sxmo/hooks/` override sxmo's hooks; sxmo's device profile is
  `sxmo_deviceprofile_qcom,sm8150-mtp.sh`, named after this kernel's first device-tree compatible).
  - **Each screen on its own:** own bar, one workspace (left 1, right 2), touchscreen mapped to its panel, its own
    gestures (one lisgd per touchscreen; `duo-gesture` focuses the screen a gesture came from before acting), its own
    keyboard and brightness. The only cross-screen action: moving an app (two-finger swipe towards the other screen,
    the Duo menu, or the overview). Log of every gesture: `journalctl -t duo-gesture`.
  - **One app per screen** (`duo-stack`): the others wait in sway's scratchpad, remembered per screen; a new app takes
    its screen, closing one brings back the previous. **Overview** (`duo-overview`, swipe up from the right half of
    the bottom edge): cards of this screen's apps (tap = show, ✕ = close), the other screen's apps (tap = bring here),
    an app grid button, CPU / memory / storage.
  - **Gestures:** down from the top = the Duo menu (open app, overview, sxmo's system menu, rotation, move / close the
    app); up from the left half of the bottom = keyboard; short swipe in from a side edge = back (closes the overview,
    a menu, the keyboard, then Alt+Left / Esc in the app); long swipe in from a side edge = next / previous app;
    along the top edge = that panel's brightness. The bottom-edge swipes are read by `duo-sway-posture` from the
    touchscreens directly (lisgd cannot tell where along an edge a swipe began); every attempt is logged.
  - **Menus** close on a tap outside them (`duo-menu-scrim`, put up before bemenu by the `sxmo_dmenu.sh` hook so it is
    always under the menu).
  - **Rotation** (`duo-sway-posture`, `duo-rotation menu` or the bottom-right corner swipe): *auto* follows the phone
    (0.7 s settle), *manual* never rotates by itself, *semi-auto* shows a small rotate button in the bottom-right
    corner as you now hold the phone (tap within 6 s). Both screens rotate together; landscape stacks them.
  - **Folded back** (hinge >= 330 deg): the screen facing away is powered off (its apps stay), its touch and gestures
    are ignored. Which one: **the screen you touch** (or keep a finger on while folding) goes off; otherwise the tilt
    mapping learned from earlier folds, or the screen used last. Unfolding (<= 310 deg) turns it on again.
  - **Power key** = screen on / off (sxmo's lock stage, screen on with touch off for 8 s, is skipped). Idle: screens
    off after about 2 minutes. Screen on/off goes through the `sxmo_wm.sh` hook (sxmo's own thought the screens were
    off when only the folded-away one was).
  - **Keyboard:** wvkbd with `wvkbd/wvkbd-0.15-duo.patch` (built by `wvkbd/make-wvkbd.sh` in the container, installed
    as `/usr/local/bin/wvkbd-mobintl` ahead of Debian's): long press on a letter gives its number / symbol (shown in
    the key's corner), a pressed key stays lit 90 ms (6 ms taps were never drawn), a click from the haptic motor on
    every press. Look and size: `~/.config/duo/keyboard-args` (heights are logical px: portrait 250, landscape 210).
  - **Theme:** near-black with cyan / magenta accents, JetBrains Mono, a horizon-grid wallpaper (`make-wall.py`).
- **Closing the phone** (`duo-lid`, a system service): screens off at once, **sleep (s2idle) after 30 s closed**
  (`DUO_LID_SLEEP=<s>` in the unit, 0 = never; wake: power key or a touch). The hinge angle drives a virtual lid (uinput
  `SW_LID`; closed at <= 10 deg, open at >= 25); sway's lid binding turns the screens off and on again.
  logind ignores the lid (`/etc/systemd/logind.conf.d/50-duo-lid.conf`).
- **Suspend (s2idle), tested 2026-11-12:** works with UFS at the kernel's `spm_lvl` 3 (64 MB write + read-back
  after resume OK; Wi-Fi reconnects). The SLPI's sensor process crashed when hexagonrpcd was frozen during the sleep,
  so the systemd-sleep hook `duo-sensors-resume` stops hexagonrpcd before (no crash then) and recovers the SLPI after
  if it crashed anyway. Wakes: the power key, the touchscreen (spi0.0), the RTC. **Opening the phone does not wake it
  yet:** the hinge sensor's reports arrive over the SLPI's glink channel, whose interrupt does not count as a wakeup
  in s2idle (a kernel change; every other sensor stream would then have to stop before sleep). Idle suspend is off
  (`~/.cache/sxmo/sxmo.nosuspend`; the 2026-11-08 "freeze" was Plasma idle-suspending with nothing to wake it).
  Test hooks: `systemctl kill --kill-whom=main -s USR1 duo-lid` = closed for 10 s, `USR2` = open.
- **App store:** Discover (KDE's store, without Plasma) with Flatpak + Flathub only (3,100 arm64 apps on 2026-11-12).
  Debian's Discover also carries a PackageKit backend for system packages; it is diverted to
  `.../qt6/plugins/discover-disabled/` so Discover never upgrades Debian packages (the held / diverted Duo ones).
  System updates stay with apt. Undo: `dpkg-divert --rename --remove .../qt6/plugins/discover/packagekit-backend.so`.
- **Sensor proxy fix** (`tools/linux/sensors/iio-sensor-proxy-3.9-early-claim.patch`, 3.9-1+duo1): a client that
  claims the accelerometer the moment the proxy appears, while it is still opening the sensors, never got the sensor
  started (orientation and tilt stayed "undefined" = no rotation), and the same race gave the old `'rarray' failed` /
  `'sensor_device' failed` assertions and 0 lux. The proxy now starts a sensor that was claimed while being opened.
- **Haptics:** kernel patch 0091 keeps every effect on for at least `min_play_ms`: a 10 ms keyboard click was a
  start + stop that the driver collapsed into "stop" before the motor ever moved. 0092: the clicks are also weak
  (37 %), so any non-zero rumble plays at least `min_rumble_pct` strong; defaults 60 ms and 80 %. Tune live as root:
  `echo 100 > /sys/module/da7280/parameters/min_play_ms`, `echo 100 > .../min_rumble_pct`. The driver never ends an
  effect by itself: a client must send the stop (our wvkbd sends start + stop; the driver stretches it to the minimum).
- **duo-reset:** resets the phone from Debian (no busybox `devmem` there): `systemd-run --on-active=3
  /usr/libexec/duo/duo-reset`.

## Fixes found on the way (already in this fork)
- **No sound (2026-11-13), two causes.** (1) The UCM file is named for the card's DMI long name
  `MicrosoftCorporation-SurfaceDuo-1930`, but booted this way the card has no DMI and is called `Surface-Duo`: ALSA
  found no UCM, PipeWire offered only "Off" / "Pro Audio" and played into a dummy sink. The file is now installed under
  both names (`duo-files.list`). (2) The speaker amp's DAC stayed off: the WSA8815 autosuspends 3 s after probing and its
  registers go cache-only; the card's first DAPM power-up of "RDAC" (bit 7 of 0x311c) then failed with -EBUSY, was
  dropped, and DAPM never retries (always-complete path). `duo-speaker-dac` (boot + after resume) sets that bit when
  DAPM says on and the hardware says off. Checked with the phone's own mics: a 440 Hz tone went from -78 to -40 dBFS.
  The kernel fix (keep the amp resumed while bound) is still to do.
- **SDDM reads every file in `/etc/sddm.conf.d/`:** a backup kept there (`*.conf.plasma`) overrode the real
  autologin file. Keep backups elsewhere.
- **Switching desktops from SSH:** restarting sddm ends only the compositor; the old session's systemd user units
  (Plasma: plasmashell, KWin, PowerDevil) kept running. Log out, or stop those units.
- **logind reads `logind.conf.d` only at start:** sxmo-utils' `HandlePowerKey=ignore` did not apply until a reboot, and
  a short power-key press powered the phone off.
- **macOS hosts:** the USB network needs ECM (now the default; `duo.usbnet=ncm` for NCM) and appears only while the
  Mac is unlocked.
- **The original `/init`** mounted `esp` read-write and deleted files there; this fork mounts it read-only.
- **busybox tar** on the phone cannot set symlink times and exits non-zero; the install script checks the entry count
  instead. (The root carries no file capabilities, so nothing is lost.)
