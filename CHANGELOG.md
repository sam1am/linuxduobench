# Changelog

This fork's changes on top of [brysonwf/linuxduobench](https://github.com/brysonwf/linuxduobench). Setup guide:
[docs/debian-on-win.md](docs/debian-on-win.md). Safety rules: [CLAUDE.md](CLAUDE.md).

## duo-debian-2026.11.12

Debian 13 + Plasma Mobile installed on a second Surface Duo 1 (on the `win` partition, booted tethered), and the
two-screen phone experience built on top of it. No boot partition, partition table or lock state was ever written.

### Safety and setup
- Researched how the original phone was bricked and wrote the CLAUDE.md safety rules (never lock, no AVB keys, no boot-partition writes, no slot changes, partitions by name only).
- Took a full partition backup and checked it with checksums.
- Fixed the boot script so it mounts the EFI partition read-only and never deletes files there.
- Removed `qbootctl` (it changes boot slots) from every Debian install path and masked its service.
- Added a CLAUDE.md rule: never address a partition by its `sdX` letter, because the letters change between boots.
- Wrote the hazards issue text for the upstream repo.

### Getting Debian running
- Switched USB networking from NCM to ECM so macOS can connect; NCM remains a boot option (`duo.usbnet=ncm`).
- Added a boot option for this phone's `vendor_a` location (`duo.vendor_sector`), which differs from the original author's phone.
- Added a boot option to stop the watchdog depending on USB (`duo.nousbwdt=1`), so Debian can run unplugged.
- Wrote host tools: boot-image repacker, serial command runner, and chunked, checksum-verified partition dumper.
- Built the 6.19 kernel in Docker on an Apple-silicon Mac (with an option, `NO_EFI=1`, to skip the failing EFI image build).
- Wrote `make-debian-root.sh`, which builds the Debian 13 + Plasma Mobile system in resumable stages.
- Built the iptsd touch daemon as a static binary.
- Wrote `format-win.sh` (formats the Windows partition only after checking it is the right one) and fixed its silent-exit bug.
- Wrote `install-debian-root.sh`, which unpacks the system onto the phone and verifies the file count.
- Formatted `win` as ext4, installed Debian and booted it tethered.
- Added Kirigami Addons and Qt image plugins to the build after Plasma showed only QML errors and blank icons.
- Wrote the guide `docs/debian-on-win.md`.

### Sensors and rotation
- Backported libssc 0.4.4 and iio-sensor-proxy 3.9 with Qualcomm sensor support from Debian sid (`make-sensor-debs.sh`).
- Wrote `duo-ssc-read`, a reader for the hinge-angle and posture sensors.
- Patched iio-sensor-proxy so a sensor requested during its startup still turns on; this was why rotation never worked after boot.
- Made rotation wait for an orientation to hold for 0.7 s, with no rotating while the hinge is below 60° or for 1.5 s after opening.

### Two-screen behaviour
- Wrote `duo-posture`, which rotates both screens together, stacks them in landscape and keeps the hinge gap.
- Folding back switches off the screen facing away and its touch input.
- The screen to keep is chosen by a held finger, then the learned tilt, then the last-used screen.
- Turning the folded phone over swaps the screens.
- Swiping along the top of a screen toward the hinge moves that screen's app to the other screen.
- Wrote the `duo-dualscreen` KWin script for per-screen app moves and shortcuts; it works around Plasma Mobile's block on moving windows.
- Removed the side-edge swipes, which felt backwards.
- Added a status bar and navigation bar to the left screen (`duo-left-panels`, runs once).
- Made each screen's navigation-bar X close the app on that screen.
- Integrated [hingeboard](https://github.com/brysonwf/hingeboard): in landscape it becomes the keyboard on the lower screen and the normal keyboard is turned off.

### Keyboard and haptics
- Added a developer keyboard row (Esc, Tab, sticky Ctrl and Alt, arrows, `-`, `/`) and programming symbols on long-press.
- Made the keyboard taller (36% of the screen) so the extra row keeps the key size.
- Kernel patch 0091: fixed vibration motor clicks being dropped (they now last at least 40 ms).
- Kernel patch 0092: made clicks at least 80% strength for 60 ms.

### Power, lid and sleep
- Wrote `duo-lid`: the hinge acts as a laptop lid, so closing turns the screens off, and the phone sleeps after 30 s closed.
- Made opening the phone wake both screens.
- Set Plasma never to suspend on idle, and systemd never to suspend on the lid by itself.
- Confirmed s2idle suspend works with the storage at its current power level.
- Wrote a sleep hook that stops the sensor helper before sleep and recovers the sensor processor after if needed.
- Turned off the Bluetooth serial port's wakeup during sleep (it was waking the phone instantly) and log what woke the phone.
- Allowed suspend again (hibernate stays off).
- Added `duo-reset`, the safe reset command for Debian.

### Display
- Wrote `duo-kwin-outputs` so the right screen is no longer dimmed in software, and secured it so it runs as the user.
- Documented recovering the brightness-slider snow with a screen off/on cycle (the root cause is not fixed).

### Apps
- Installed Discover with Flathub only, and kept it from updating Debian system packages.

### Known issues and open work
- Dragging the brightness slider glitches the left panel (DSI0 FIFO underflow); the root cause is in the display driver.
- Waking by opening the phone needs a kernel change; today the power key or a touch wakes it.
- KWin screenshots trigger GPU memory faults.
- Untethered boot through WOA's UEFI would mean breaking the "never flash `boot_a`" rule.
- Camera and a boot dongle (ESP32-S3, Raspberry Pi Zero 2 W or Flipper) are still open.
