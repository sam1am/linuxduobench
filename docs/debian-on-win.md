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
| Works | Not yet |
|---|---|
| Plasma Mobile on both screens, smooth | Auto-rotation (sensors: no libssc packages in Debian yet) |
| Touch on both screens, on-screen keyboard | Turning off the back screen when folded (hinge sensor) |
| Wi-Fi scan + connect, Chromium browsing | Keyboard haptics (vibration does not fire) |
| Brightness control | Desktop icons (Plasma Mobile shows apps in its drawer instead) |
| Quick settings, app drawer, window close | Speaker, camera, modem, Bluetooth: untested on this install |
| SSH over USB (ECM, `169.254.66.1`) | |

Layout notes: the top panel and app drawer appear on both screens, the navigation bar only on the right one; pulling
quick settings down on the right screen opens them on the left. Apps open on one screen.

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
