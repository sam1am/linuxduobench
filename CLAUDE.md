# Surface Duo 1 safety rules (read before touching the phone)

This repo's original author permanently bricked their Surface Duo 1 on 2026-11-08. There is **no recovery** once the
phone stops RAM-booting: fastboot cannot write the boot storage unit, and no Microsoft-signed EDL (9008) loader is
public. A partition backup cannot be restored in that state. These rules are absolute. If a task seems to require
breaking one, stop and ask the user; a general "go ahead" is not approval.

Details: `docs/brick-record.md`, `docs/bootloader-facts.md`.

## NEVER (no exceptions, no "just once", not even with a backup)

1. **Never lock.** No `fastboot flashing lock`, `flashing lock_critical`, or any relock step.
2. **Never touch AVB keys.** No `fastboot flash avb_custom_key`, no `erase avb_custom_key`, no self-signed vbmeta.
3. **Never write, erase, format or discard any of these partitions** (named by GPT partition name and UFS unit):
   - UFS unit 4, the boot unit (all of it): `boot_*`, `vbmeta_*`, `dtbo_*`, `abl_*`, `tz_*`, `hyp_*`, `aop_*`,
     `keymaster_*`, `modem_*`, `dsp_*`, `bluetooth_*`, `cmnlib*`, `devcfg_*`, `qupfw_*`, `uefisecapp_*`, `sftpfw_*`,
     `devinfo`, `apdp`, `uefivarstore`, `logfs`, `secdata`
   - UFS units 1 and 2 (`xbl_*`, `xbl_config_*`), unit 3 (`ddr`, `sfpd`), unit 5 (`modemst1`, `modemst2`, `fsg`, `fsc`)
   - on unit 0: `ssd`, `persist`, `frp`, `misc`, `metadata`
   - on unit 6: `super`, `vbmeta_system_*`
   This applies from fastboot, from Android, from TWRP and from a running Linux (`dd`, `cat >`, `mkfs`, `blkdiscard`,
   `wipefs`, `fastboot flash`, `fastboot erase`).
   **Never address a partition by its `sdX` letter.** The letters change between boots: on 2026-11-11 the boot unit
   was `sde` on one boot and `sdf` on the next. Before any write, resolve the target by partition name
   (`PARTNAME=` in `/sys/class/block/*/uevent`), then confirm with `blkid` that its `PARTLABEL` and current
   filesystem type are what you expect, in the same command that does the write.
4. **Never change slot state from an OS.** No `qbootctl` (any option), no `bootctl`, no `sgdisk`/`sfdisk`/`parted`/
   `gdisk` attribute edits, no UFS `bBootLunEn` changes. Never let `qbootctl.service` run in an installed system.
   The only slot command allowed is `fastboot --set-active=a` immediately before `fastboot boot` (it does not persist).
5. **Never edit any partition table** (GPT) on any UFS unit. No creating, deleting, resizing or renaming partitions.
6. **Never flash a boot image.** Linux is started only with `fastboot boot <img>` (RAM, tethered). No untethered boot.
7. **Never run `fastboot flash`, `fastboot erase`, `fastboot format`, `fastboot -w` or `fastboot oem ...`** (other
   than read-only `oem device-info`) without the user approving that exact command.
8. **Never mount the read-only partitions read-write.** `modem_a`, `dsp_a`, `persist`, `super`/`vendor_a` are mounted
   `-o ro` only. `rmtfs` runs with `-r` only.

## Known brick paths (all avoided by the rules above)

- Writing `boot_a` + self-signed `vbmeta_a`, flipping only boot slot flags with `sgdisk`, enrolling a custom AVB key,
  locking, then unlocking (this repo's author; cause never isolated, so the whole class is forbidden).
- Writing `xbl` / `xbl_config` / `abl`, or writing both A/B slots blindly.
- Relocking with any modified partition.
- Restoring a verification-on `vbmeta` over a modified `super`.
- Writing a patched boot image to the inactive slot after an OTA.
- Wiping or editing the GPT; partitioning mistakes with `parted`.
- Mixed slot state (only some A/B pairs switched).

## Allowed without asking

- Read-only queries: `adb shell getprop`, `fastboot getvar`, `fastboot devices`, `fastboot oem device-info`.
- `adb reboot bootloader`, `fastboot --set-active=a` followed at once by `fastboot boot <img>`, `fastboot reboot`.
- Reading any partition (`dd if=... of=<file on the Mac>`); mounting with `-o ro`.

## Needs the user's explicit approval each time

- Anything that destroys data: reformatting or writing the `win`, `esp` or `userdata` partitions
  (unit 0; found by name, never by letter). Say what will be lost and wait for a yes.

## This phone

- Surface Duo 1, bootloader 2022.815.527, unlocked, Windows-on-ARM partition layout (`esp`, `win` of about 99.7 GiB and a 4 GiB
  `userdata`, all on UFS unit 0). Android and Windows are expendable but wiping needs approval first.
- Plan: Debian root on the `win` partition (`duo.root=win`), always booted tethered. Android stays intact as the
  fallback.
- The upstream RAM image's `/init` mounts `esp` read-write and writes crash logs there; use the patched init in this
  fork (ESP is mounted read-only).

## Operating rules on the running Linux

- Reset only with `devmem 0x0c264000 w 0`; `reboot` hangs this phone.
- Never read display registers (`0x0ae0xxxx`) with the display off; never touch the apps SMMU (`0x15000000`).
- Before charger or battery work read `/sys/class/power_supply/bq27742-*/temp`; stop outside 15-35 °C.
- Never toggle UFS power-management sysfs knobs at runtime.
