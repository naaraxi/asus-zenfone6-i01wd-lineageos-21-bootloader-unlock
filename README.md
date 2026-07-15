# Asus ZenFone6 I01WD - LineageOS 21 + bootloader unlock

This repository documents a proven bootloader unlock method for the ASUS ZenFone 6 / I01WD / ZS630KL and provides a known-good LineageOS 21 Android 14 GSI image that was patched and validated on the device.

The unlock method was proven on 2026-07-14 on a ZenFone 6 running ASUS WW firmware `18.0610.2106.156-0`. The ROM image was validated on 2026-07-15.

## Status

- Device: ASUS ZenFone 6 / I01WD / ZS630KL
- Bootloader unlock: works by setting the OEM-unlock-allowed byte in `frp` from EDL, then booting directly to fastboot
- Final OS image: LineageOS 21 Android 14 GSI, `arm64_bvN`, vanilla
- Final patched image: `images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img.zst`
- Raw image SHA256 after decompression: `84d363392faa99693d7941eb06ea5a5f98a3d2ffd8c7ec18c494be3be20f1f74`

## Warnings

This process intentionally writes phone partitions and unlocks the bootloader. Unlocking wipes userdata. Mistakes can brick the phone.

Do not boot Android after writing the patched `frp` byte. Android can clear the byte before fastboot sees it. After the EDL write, power off from EDL and manually boot straight to fastboot with Volume Up + Power.

The included Firehose programmer is the one used for this device. Do not assume it is safe for other ASUS or Qualcomm devices.

## Repository Contents

- `README.md`: main tutorial.
- `scripts/patch_frp_unlock_ability.sh`: patches a dumped 524288-byte FRP image by setting only the final byte to `0x01`.
- `scripts/edl_unlock_frp.sh`: guided EDL dump/patch/write/poweroff helper.
- `scripts/flash_lineageos21_patch30.sh`: decompresses and flashes the known-good LineageOS 21 GSI image.
- `loaders/i01wd_fhprg.bin`: known-good SM8150/UFS Firehose programmer used during the unlock.
- `images/vbmeta_flags3_empty_64k.img`: vbmeta image used during GSI flashing.
- `images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img.zst`: compressed final patched system image.
- `docs/`: detailed reproduction notes, validation notes, and field notes.

This repository intentionally does not include private mitmproxy CA keys, virtualenvs, raw partition dumps, APK decompilation trees, or Ghidra projects.

## Required Tools

On a Debian/Ubuntu host:

```bash
sudo apt update
sudo apt install -y adb fastboot python3 python3-venv git git-lfs zstd xxd coreutils
```

Install an EDL client. The successful run used the Python `edl` tool from the `bkerler/edl` project. One common setup is:

```bash
python3 -m venv edl-venv
edl-venv/bin/pip install --upgrade pip
edl-venv/bin/pip install edl
export EDL="$PWD/edl-venv/bin/edl"
```

If your distribution package or local checkout exposes `edl` differently, set `EDL=/path/to/edl` when running the helper script.

## Bootloader Unlock Tutorial

Start with the phone booted to Android with ADB authorized, or enter EDL by another known method.

### 1. Enter EDL

```bash
adb reboot edl
```

Confirm EDL / Firehose connectivity:

```bash
sudo "${EDL:-edl}" nop --loader="$PWD/loaders/i01wd_fhprg.bin"
```

Expected signs:

```text
Mode detected: sahara
Loader successfully uploaded.
Mode detected: firehose
Nop succeeded.
```

### 2. Dump, Patch, Write FRP

The helper script performs the exact successful sequence:

```bash
EDL="${EDL:-edl}" ./scripts/edl_unlock_frp.sh
```

It will:

1. Read the current `frp` partition.
2. Copy it to `work/edl/frp_unlock_ability1.bin`.
3. Set only byte offset `524287` to `0x01`.
4. Write the patched image back to `frp`.
5. Read `frp` back and compare.
6. Request EDL poweroff.

The important partition facts are:

- `frp` is on UFS LUN 0.
- `frp` size is `0x80000` bytes / 524288 bytes.
- ABL reads the final byte of `frp`.
- If bit 0 of the final byte is set, fastboot reports `get_unlock_ability: 1`.

To do the patch manually instead:

```bash
mkdir -p work/edl

sudo "${EDL:-edl}" r frp work/edl/frp_before_unlock.bin \
  --memory=ufs \
  --lun=0 \
  --loader="$PWD/loaders/i01wd_fhprg.bin"

./scripts/patch_frp_unlock_ability.sh \
  work/edl/frp_before_unlock.bin \
  work/edl/frp_unlock_ability1.bin

sudo "${EDL:-edl}" w frp work/edl/frp_unlock_ability1.bin \
  --memory=ufs \
  --lun=0 \
  --loader="$PWD/loaders/i01wd_fhprg.bin"
```

Expected `cmp -l` output if the original final byte was zero:

```text
524288 0 1
```

Expected final bytes:

```text
0007fff0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01
```

### 3. Power Off From EDL

Do not reset or boot to Android.

```bash
sudo "${EDL:-edl}" reset \
  --resetmode=off \
  --loader="$PWD/loaders/i01wd_fhprg.bin"
```

An ending like this is expected:

```text
INFO: bsp_target_poweroff() 1
USBError(19, 'No such device (it may have been disconnected)')
```

### 4. Boot Directly To Fastboot

Immediately boot to fastboot without allowing Android to start:

```text
Hold Volume Up + Power.
Release Power when the phone vibrates or lights up.
Keep Volume Up held until fastboot appears.
```

This step is timing-critical. If Android boots, it clears the FRP byte and `get_unlock_ability` returns to `0`; repeat from EDL.

### 5. Confirm Unlock Ability

```bash
fastboot devices
fastboot flashing get_unlock_ability
```

Expected:

```text
(bootloader) get_unlock_ability: 1
OKAY
```

### 6. Unlock

```bash
fastboot flashing unlock
```

The phone may show an on-screen confirmation prompt. Use the volume keys to select the unlock/yes option, then press Power to confirm.

The phone will wipe userdata and reboot.

### 7. Verify Unlock

Boot back to fastboot and run:

```bash
fastboot oem device-info
fastboot getvar unlocked
```

Expected final state:

```text
(bootloader) Device unlocked: true
unlocked: yes
```

## Flash LineageOS 21 GSI Patch30

Put the phone in fastboot mode with the bootloader already unlocked.

The helper script decompresses the image if needed, verifies hashes, flashes vbmeta and system, wipes userdata, and reboots:

```bash
SLOT=a ./scripts/flash_lineageos21_patch30.sh
```

Manual equivalent:

```bash
zstd -d -f images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img.zst \
  -o images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img

sha256sum -c SHA256SUMS --ignore-missing

fastboot --set-active=a
fastboot flash vbmeta_a images/vbmeta_flags3_empty_64k.img
fastboot flash system_a images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img
fastboot -w
fastboot reboot
```

If your device is using slot `b`, set `SLOT=b` and flash `system_b` / `vbmeta_b`.

## What Patch30 Contains

Patch30 is the known-good LineageOS 21 GSI state from this bring-up:

- Base: LineageOS 21 Android 14 GSI `arm64_bvN`, vanilla.
- Boot/no-BPF/reboot/tethering/APEX compatibility fixes from the bring-up.
- Device name/model/manufacturer changed from generic TrebleDroid values to `Zenfone 6` / `ASUS`.
- ZenFone 6 Smart Key mapped to `CAMERA`.
- Dialer startup fixed by adding `RoleManager.isRoleHeld(String)` compatibility behavior to the patched framework role stub.

See:

- `docs/lineageos21_gsi_reproduction.md`
- `docs/validation.md`
- `docs/field_notes.md`

## Validated Functionality

Validated on the phone:

- Boot and reboot persistence.
- Wi-Fi and browser.
- Bluetooth scan/pair/connect.
- Rear camera, camera switch, flip camera motor, photo save.
- Fingerprint enrollment and unlock, including wake.
- USB/ADB.
- Hotspot association from another phone.
- Sensors, display, brightness, rotation, buttons.
- Speaker, microphone recording, recorder playback.
- Charging/battery stats, vibration, lock/security basics.
- Files, storage, Gallery, Eleven Music, ThemePicker.
- Phone/Dialer after patch30.
- GNSS/GPS outdoors.

Partial or not solved:

- NFC was inconclusive: another phone could read the ZenFone as ISO 14443-4/isodep, nfcb, but the ZenFone did not visibly react.
- Browser geolocation timed out, likely due to no GApps/network location provider.
- SIM/mobile data was not solved in this session.
- IMS/VoLTE was not tested.

## Failed Unlock Paths

These were tried and are not the working unlock mechanism:

- Official ASUS unlock APK path was blocked by dead/changed ASUS MDM endpoints and TLS trust problems.
- Installing a user CA did not fix the unlock app path.
- Patching `devinfo` from `false` to `true` did not unlock this bootloader.
- Patching `/dmclient/dm_client_info` inside `ADF` from `UNLOCK[KEY]0` to `1` did not unlock this bootloader.
- `fastboot oem reboot-edl`, `fastboot oem edl`, `fastboot reboot edl`, and `fastboot oem enter-dload` were unsupported or rejected.
- Firehose reset modes such as `bootloader`/`fastboot` did not reliably enter fastboot on this device; they booted Android, which cleared FRP.

## Checksums

Run:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

For the compressed image, `SHA256SUMS` records the hash of the `.zst` file and the raw decompressed `.img`.


## Final notes

Screw you, ASUS
