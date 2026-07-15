# Zenfone 6 / ZS630KL / I01WD Bootloader Unlock Method

Date proven: 2026-07-14

Device proven on:
- ASUS Zenfone 6, model I01WD / ZS630KL
- Android build observed: `18.0610.2106.156-0`
- Bootloader observed before unlock: `PreR-ES2user-3.0-user`
- UFS device using Qualcomm SM8150 EDL / Firehose

This method works by setting the OEM-unlock-allowed byte in the `frp`
partition directly from EDL, then booting straight to fastboot before
Android can clear it. Once fastboot sees `get_unlock_ability: 1`,
`fastboot flashing unlock` presents the normal on-device confirmation
screen and can commit the unlock.

## Critical Facts

- `frp` is on UFS LUN 0.
- `frp` starts at sector 8584.
- `frp` size is `0x80000` bytes / 524288 bytes / 128 sectors of 4096 bytes.
- ABL reads the final byte of the `frp` partition.
- If the final byte has bit 0 set, fastboot reports:

```text
(bootloader) get_unlock_ability: 1
```

- Android clears this byte back to zero during normal boot if OEM unlocking is
not enabled through the framework/UI.
- Therefore, after patching `frp` in EDL, do not boot Android. Power off from
EDL and manually boot directly to fastboot with Volume Up + Power.

## Required Local Files

Known-good Firehose programmer used:

```text
loaders/i01wd_fhprg.bin
```

EDL client used:

```text
edl
```

Working directory used:

```text
this repository
```

## Reproduction Steps

Start with the phone booted to Android with ADB authorized, or enter EDL by
another known method.

### 1. Enter EDL

From Android:

```bash
adb reboot edl
```

Confirm EDL / Firehose connectivity:

```bash
sudo edl nop \
  --loader=loaders/i01wd_fhprg.bin
```

Expected signs:

```text
Mode detected: sahara
Loader successfully uploaded.
Mode detected: firehose
Nop succeeded.
```

If the device is already in Firehose from a prior command, the output may say:

```text
Mode detected: firehose
```

### 2. Dump Current FRP

```bash
mkdir -p work/edl

sudo edl r frp \
  work/edl/frp_before_unlock_attempt.bin \
  --memory=ufs \
  --lun=0 \
  --loader=loaders/i01wd_fhprg.bin
```

### 3. Create Patched FRP Image

Copy the current FRP dump and change only the final byte to `0x01`.

```bash
cp work/edl/frp_before_unlock_attempt.bin \
  work/edl/frp_unlock_ability1.bin

printf '\001' | dd of=work/edl/frp_unlock_ability1.bin \
  bs=1 \
  seek=524287 \
  conv=notrunc
```

Verify only the final byte changed:

```bash
cmp -l work/edl/frp_before_unlock_attempt.bin \
  work/edl/frp_unlock_ability1.bin

xxd -g1 -s -16 work/edl/frp_unlock_ability1.bin
```

Expected `cmp -l` output if the original final byte was zero:

```text
524288 0 1
```

Expected tail:

```text
0007fff0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01
```

### 4. Write Patched FRP

```bash
sudo edl w frp \
  work/edl/frp_unlock_ability1.bin \
  --memory=ufs \
  --lun=0 \
  --loader=loaders/i01wd_fhprg.bin
```

Read it back and verify:

```bash
sudo edl r frp \
  work/edl/frp_after_unlock_ability1_write.bin \
  --memory=ufs \
  --lun=0 \
  --loader=loaders/i01wd_fhprg.bin

cmp work/edl/frp_unlock_ability1.bin \
  work/edl/frp_after_unlock_ability1_write.bin

xxd -g1 -s -16 work/edl/frp_after_unlock_ability1_write.bin
```

The `cmp` command should print nothing. The final byte should be `01`.

### 5. Power Off From EDL

Do not reset to Android.

```bash
sudo edl reset \
  --resetmode=off \
  --loader=loaders/i01wd_fhprg.bin
```

Expected ending:

```text
INFO: bsp_target_poweroff() 1
USBError(19, 'No such device (it may have been disconnected)')
```

The USB disconnect is expected.

### 6. Manually Boot Directly To Fastboot

Immediately boot to fastboot without allowing Android to start:

```text
Hold Volume Up + Power.
Release Power when the phone vibrates or lights up.
Keep Volume Up held until fastboot appears.
```

This manual step is timing-critical. If Android boots, it clears the FRP byte
and `get_unlock_ability` returns to `0`; repeat from EDL.

### 7. Confirm Unlock Ability

```bash
fastboot devices
fastboot flashing get_unlock_ability
```

Expected:

```text
(bootloader) get_unlock_ability: 1
OKAY
```

### 8. Unlock

```bash
fastboot flashing unlock
```

The command can return quickly:

```text
OKAY [  0.030s]
Finished. Total time: 0.030s
```

The phone may then show an on-screen confirmation prompt. Use the volume keys
to select the unlock/yes option, then press Power to confirm.

The phone will wipe userdata and reboot to Android setup.

### 9. Verify

After the wipe, either complete enough Android setup to re-enable ADB, or boot
to fastboot manually with Volume Up + Power.

Then run:

```bash
fastboot oem device-info
fastboot getvar unlocked
```

Expected final state:

```text
(bootloader) Device unlocked: true
unlocked: yes
```

## Failed Or Non-Essential Paths

These were tried and are not the working unlock mechanism:

- Official ASUS unlock APK path was blocked by dead/changed ASUS MDM endpoints
  and TLS trust problems.
- Installing a user CA did not fix the unlock app path.
- Patching `devinfo` from `false` to `true` did not unlock this bootloader.
- Patching `/dmclient/dm_client_info` inside `ADF` from `UNLOCK[KEY]0` to `1`
  did not unlock this bootloader.
- `fastboot oem reboot-edl`, `fastboot oem edl`, `fastboot reboot edl`, and
  `fastboot oem enter-dload` were unsupported or rejected.
- Firehose reset modes such as `bootloader`/`fastboot` did not reliably enter
  fastboot on this device; they booted Android, which cleared FRP.
- Writing a `misc` BCB command such as `bootonce-bootloader` did not force
  fastboot after EDL reset on this device.

## Recovery / Repeat Notes

If `fastboot flashing get_unlock_ability` shows `0`, Android probably booted
after the FRP patch and cleared the byte. Re-enter EDL, write the patched FRP
again, power off from EDL, and manually boot directly to fastboot.

If the phone is still locked but `get_unlock_ability` is `1`, rerun:

```bash
fastboot flashing unlock
```

Then watch the phone screen for the physical confirmation prompt.

