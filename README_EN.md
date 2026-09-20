# Rooting the Xiaomi Duokan E-reader Pro 2 (Moaan / RK3566) — no official firmware, no disassembly

> A full root guide for the **Xiaomi Duokan E-reader Pro 2** (Moaan MiDuoKanReader Pro II,
> RK3566, Android 11, 32-bit userspace on a 64-bit kernel), using **Android DSU (Dynamic
> System Update)** to boot a temporary rooted GSI and dump the boot partition —
> **no stock firmware required, no testpoint, and no bootloader partition is modified
> until you hold a verified backup.**

The same approach applies to other Moaan-family e-readers (Duokan 1st gen / Pro /
inkPalm 5 / inkPad / Mix 7) — just pick the correct **GSI architecture** for your
device (see the pitfall below).

> ⚠️ **Disclaimer**: this guide writes a modified image to the `boot` partition.
> Complete the full-partition backup (step 5) before any write. You do this at your own risk.

## Why this device is hard

- **No official firmware** available (OTA server returns nothing) — a bad write has no software recovery
- **Rockchip Loader mode read wall**: only the first 32 MB of flash is readable (`ReadLBA: Disable`), boot lives past 40 MB
- **MaskROM unusable** on this hardware (USB stack hangs)
- **Recovery rejects third-party signed sideload zips** (including AOSP testkey — verified by test)
- `user` build with `release-keys`, no SD card slot

## The idea

> If you can't read the boot partition, boot a system that *already has root* and read it from there.

Android's built-in **DSU** installs a GSI into a loop device under `/data` — **no read-only
partition is touched** — and reboots into it. A userdebug GSI gives you `adb root` (uid 0),
from which you `dd` the boot partition. Then you patch it with Magisk and flash it back.

## ★ The biggest pitfall: GSI architecture

The GSI arch field must match your device **exactly**:

| GSI arch | Device | How to tell |
|---|---|---|
| `arm` | 32-bit **kernel** + 32-bit userspace | `CONFIG_ARM64=n` in `/proc/config.gz` |
| **`arm32_binder64`** (a.k.a. `a64`) | **64-bit kernel + 32-bit userspace** | `CONFIG_ARM64=y`, abilist has no arm64 |
| `arm64` | 64-bit kernel + 64-bit userspace | abilist contains arm64-v8a |

The Pro 2 is **`arm32_binder64` (a64)**. **Using the `arm` GSI fails to boot every time**,
and the failure looks like "DSU doesn't work on Rockchip" — it doesn't; the architecture
was wrong. Don't use `uname -m` to determine kernel bitness; read `/proc/config.gz`.

GSI used (phh treble, Android 11 to match VNDK 30, ships with root):
```
https://github.com/phhusson/treble_experimentations/releases/download/v313/
  system-roar-arm32_binder64-ab-vanilla.img.xz
```

## Steps (see the Chinese README for full detail)

1. **Prepare the image**: decompress xz → img, pad to 512-byte alignment, gzip it
   (DSU only accepts compressed extensions; a bare `.img` throws `UnsupportedFormatException`)
2. **Open the hidden DSU gate** (the confirmation dialog silently does nothing without it):
   ```bash
   adb shell setprop persist.sys.fflag.override.settings_dynamic_system true
   ```
3. **Trigger DSU install**:
   ```bash
   adb shell am start-activity \
     -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
     -a android.os.image.action.START_INSTALL \
     -d file:///storage/emulated/0/Download/<gsi>.img.gz \
     --el KEY_SYSTEM_SIZE <sparse raw size> --el KEY_USERDATA_SIZE 8589934592
   ```
   Confirm on device, wait ~10 min, then tap **Restart** in the completion notification.
4. **The GSI boots with a black screen** (no e-ink driver) — `adb` still works:
   ```bash
   adb root                      # userdebug GSI → uid=0
   adb shell sh /data/local/tmp/dump_partitions.sh    # dd boot_a/b, vbmeta, dtbo, misc
   adb pull /data/local/tmp/boot_b.img .
   ```
5. **Patch with Magisk CLI** (no UI needed):
   ```bash
   ./scripts/make_magisk_kit.sh Magisk-v30.7.apk magisk_kit
   adb push magisk_kit /data/local/tmp/magisk_kit
   adb shell 'cd /data/local/tmp/magisk_kit && chmod -R 755 . && \
     BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true sh boot_patch.sh /data/local/tmp/boot_b.img'
   adb pull /data/local/tmp/magisk_kit/new-boot.img
   ```
6. **Flash back and verify**:
   ```bash
   adb shell dd if=/data/local/tmp/magisk_kit/new-boot.img of=/dev/block/by-name/boot_b bs=4M
   adb reboot        # stock system boots with Magisk
   adb install Magisk-v30.7.apk   # the manager app
   ```
   Tip: when granting root, **Magisk must be in the foreground**, otherwise the request is
   auto-denied ("occluded by another app").

## Recovery

The stock `boot_a` / `boot_b` / `vbmeta` / `dtbo` / `misc` images are backed up in step 4.
If a flashed boot fails, the device drops into fastboot on its own (A/B boot-failure
fallback) → `fastboot flash boot_b <stock image>` → `fastboot continue`.
Before OTA updates, restore the stock image in Magisk first.

## Credits

- [qwerty12/inkPalm-5-EPD105-root](https://github.com/qwerty12/inkPalm-5-EPD105-root) —
  pioneered the Moaan-family approach; the Magisk CLI patching flow follows it
- [Moann Mix 7 root notes (tenpurro)](https://blog.tenpurro.xyz/posts/moaan-mix-7-root) —
  same Rockchip + Android 11 + 4.19 stack; proved a GSI boots headless with adb alive
- [Ximin's Duokan-series root guide](https://ximin.top/blog/140.html)
- [Magisk](https://github.com/topjohnwu/Magisk) ·
  [phh treble GSI](https://github.com/phhusson/treble_experimentations) ·
  [Andy Yan GSI builds](https://sourceforge.net/projects/andyyan-gsi/)
