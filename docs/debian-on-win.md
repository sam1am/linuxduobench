# Debian 13 + Plasma Mobile on the `win` partition (tethered)

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
/repo/tools/host/make-debian-root.sh /repo /root/build-duo /repo/keys.pub /root/duo-debian-root.tar.zst
```
`make-debian-root.sh` runs debootstrap (trixie arm64), installs Plasma Mobile and the Duo services, copies the kernel
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
Plasma Mobile comes up on both screens after about a minute. To return to Android, `devmem 0x0c264000 w 0` as root.

## Status (2026-11-11, one phone)
| Works | Built, needs a hands-on test |
|---|---|
| Plasma Mobile on both screens, smooth | Auto-rotation of both screens (landscape stacks them) |
| Touch on both screens, on-screen keyboard | Back screen off when folded back (hinge sensor) |
| Wi-Fi scan + connect, Chromium browsing | Keyboard haptics (driver fix verified on the I2C bus) |
| Brightness control, light sensor (lux) | Swipe from a side edge to move an app to the other screen |
| Quick settings, app drawer, window close | |
| Status + navigation bar on both screens | **Not yet:** camera, speaker/modem/Bluetooth untested |
| Sensors: accel, hinge angle, posture, hall, light, proximity | |
| SSH over USB (ECM, `169.254.66.1`) | |

The home screen (Folio) starts with an empty page; apps are in the drawer (swipe up) and in each screen's dock.

## The two-screen layer
Everything below is installed by `make-debian-root.sh` (sensor packages from `tools/host/make-sensor-debs.sh`).
- **Sensors.** Trixie has no libssc and builds iio-sensor-proxy without SSC support. `make-sensor-debs.sh` backports
  sid's libssc 0.4.4 and iio-sensor-proxy 3.9 (Debian's own packaging; held with `apt-mark`) and builds
  `duo-ssc-read` (`tools/linux/sensors/`), a generic SSC reader for the sensors libssc has no class for:
  `duo-ssc-read hinge_angle posture` prints `hinge_angle 188.857 0.000 178.144` (degrees; 0 closed, 180 flat,
  ~355 back to back).
- **duo-posture** (systemd user unit in the Plasma session, `/usr/libexec/duo/duo-posture`):
  - rotates both screens together from iio-sensor-proxy's orientation; landscape stacks them (the screen on the upper
    edge on top), upside down swaps them, the 33 px hinge gap is kept. Plasma's rotation quick setting (auto-rotate
    policy "Never") locks it.
  - folded back (hinge >= 330 deg): switches the screen facing away off and disables its touchscreen in KWin, so the
    hand on the back does nothing; apps move to the front screen. Which screen stays on, in order: **the one you hold
    a finger on while folding** (exactly one screen touched), the tilt of the accelerometer's half with the mapping
    learned from earlier finger picks, the screen used last time; with none of these both stay on until the first
    touch. Turning the folded phone over (tilt reversed for 0.7 s) swaps the screens. Unfolding (<= 310 deg)
    restores both. Stopping the service restores both screens. State: `~/.local/state/duo-posture.json`.
  - **swipe along the top of a screen towards the hinge** (start in the top 5 %, at least 40 % of the width, within
    2 s; both screens open, portrait): that screen's app moves to the other screen.
  - log: `journalctl --user -u duo-posture`.
- **Laptop keyboard when stacked** ([hingeboard](https://github.com/brysonwf/hingeboard), vendored in
  `tools/linux/hingeboard/`): with the phone rotated so the screens are one above the other, duo-posture runs
  hingeboard on the **lower** screen (apps on the lower screen move up first) and switches maliit off, so typing on
  the upper screen never opens a keyboard over it. Back to portrait (or folded) = hingeboard stops, maliit returns.
  Its Exit key closes it until the next time the screens are stacked; never: `touch
  ~/.config/duo-posture-no-hingeboard`.
- **KWin script `duo-dualscreen`** (`/usr/share/kwin/scripts/`): the moves behind the top swipe (`DuoMoveFromDSI-1/2`:
  the app on top of that screen goes across), and Meta+Shift+Right/Left/O for the focused app. Plasma Mobile shows
  apps maximised without title bars, so there is nothing to drag; this is the replacement. (Side-edge swipes, the
  first version, felt backwards and are gone.)
- **Navigation bar per screen** (`tools/linux/debian/plasma-mobile-perscreen/install.sh`, a diverted + patched
  `NavigationPanelComponent.qml`): each screen's X closes the most recently used app on that screen, not the
  focused app on either screen.
- **Sensor proxy fix** (`tools/linux/sensors/iio-sensor-proxy-3.9-early-claim.patch`, 3.9-1+duo1): KWin and
  duo-posture claim the accelerometer the moment the proxy appears, while it is still opening the sensors; such a
  claim never started the sensor (orientation and tilt stayed "undefined" = no rotation), and the same race gave the
  old `'rarray' failed` / `'sensor_device' failed` assertions and 0 lux. The proxy now starts a sensor that was
  claimed while it was being opened. (KWin's own "Window to Next
  Screen" is refused under Plasma Mobile's `InteractiveWindowMoveEnabled=false`; the script uses
  `sendClientToScreen`, which works. Moves only complete while the screens are on: with both DPMS-off KWin renders
  nothing and apps never commit their new size.)
- **Developer keyboard** (`tools/linux/debian/maliit-dev/`): maliit's English layout gets a top row with Esc, Tab,
  sticky Ctrl and Alt (tap = applies to the next key and lights up; Ctrl then c = Ctrl+C, Ctrl then ← = Ctrl+Left)
  and the four arrows, plus `-` and `/`. Long press: `-` = `_ = + *`, `/` = `\ | ~ \``, `,` = `; : ' " ( ) [ ] { } < >`,
  `.` = `? ! @ # $ % ^ & *`; the top letter row keeps the digits. Keys go through maliit's `keysequence` action
  (`QKeySequence::fromString`). The package's layout is diverted (`dpkg-divert`), and a `duo` keyboard profile makes
  the keyboard 36 % of the screen height (was 30 %) so the extra row keeps the key size.
- **duo-left-panels** (user unit, once): a status bar and navigation bar on the left screen too.
- **Haptics:** kernel patch 0091 keeps every effect on for at least `min_play_ms`: a 10 ms keyboard click was a
  start + stop that the driver collapsed into "stop" before the motor ever moved. 0092: the clicks are also weak
  (37 %), so any non-zero rumble plays at least `min_rumble_pct` strong; defaults 60 ms and 80 %. Tune live as root:
  `echo 100 > /sys/module/da7280/parameters/min_play_ms`, `echo 100 > .../min_rumble_pct`.
- **duo-reset:** resets the phone from Debian (no busybox `devmem` there): `systemd-run --on-active=3
  /usr/libexec/duo/duo-reset`.

## Fixes found on the way (already in this fork)
- **"Type HomeScreen unavailable" ... "module org.kde.kirigamiaddons.formcard is not installed":** Debian's
  `plasma-mobile` does not depend on the Kirigami Addons QML modules its home screen imports. `make-debian-root.sh`
  now installs them, plus `qml6-module-qt-labs-platform`.
- **Blank icons / "Unsupported image format" for `.svgz`:** with `--no-install-recommends` Qt has no SVG decoder;
  `qt6-svg-plugins`, `qt6-image-formats-plugins` and `kimageformat6-plugins` are now installed.
- **macOS hosts:** the USB network needs ECM (now the default; `duo.usbnet=ncm` for NCM) and appears only while the
  Mac is unlocked.
- **The original `/init`** mounted `esp` read-write and deleted files there; this fork mounts it read-only.
- **busybox tar** on the phone cannot set symlink times and exits non-zero; the install script checks the entry count
  instead. (The root carries no file capabilities, so nothing is lost.)
