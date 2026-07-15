# Reproduction Notes

Target device: ASUS Zenfone 6 / I01WD / ZS630KL.

Final OS: LineageOS 21 Android 14 GSI, `arm64_bvN`, vanilla.

Final image:

`images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img`

Final image SHA256:

`84d363392faa99693d7941eb06ea5a5f98a3d2ffd8c7ec18c494be3be20f1f74`

## What Was Preserved

The final bundle preserves both the original upstream image and the known-good patched image.

The bundle also preserves a stage-base image:

`images/lineage-21.0-20250621-arm64_bvN_no_bpf_reboot_tethering_apex.img`

That stage-base already contains the early boot/no-BPF/reboot/tethering baseline work. The script in this directory is a legacy patch28 rebuild helper. Patch30 is preserved directly as an image and differs from patch29 only by the framework Dialer shim.

## Critical Files Replaced After The Stage Base

The final image differs from the stage-base by replacing these files:

- `/system/framework/framework.jar`
- `/system/framework/services.jar`
- `/system/apex/com.android.btservices.apex`
- `/system/apex/com.android.mediaprovider.apex`
- `/system/apex/com.android.permission.apex`
- `/system/apex/com.android.scheduling.apex`
- `/system/apex/com.android.tethering.apex`
- `/product/etc/build.prop`
- `/system_ext/etc/build.prop`

The replacement payloads are in `payloads/`.

## Shared-Block Rule

The ext image must be unshared before writing replacements:

```bash
e2fsck -fy -E unshare_blocks image.img
```

This is mandatory. Patch26 corrupted unrelated APKs because files were replaced while the image still used shared blocks. The visible symptom was app crashes in Eleven and ThemePicker.

## Rebuild

From this directory:

```bash
./scripts/rebuild_patch28_from_stage_base.sh
```

The rebuilt output is written to:

`work/rebuilt_patch28.img`

This helper is retained for provenance. The current known-good patch30 image is already preserved under `images/`.

## Flash

The known-good phone was flashed on slot `a`:

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot flash system_a images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img
fastboot reboot
```

If testing a future image, prefer the inactive slot if it is known to be usable.

## Runtime Identity After Patch28

Patch28 changes the baked-in display identity:

- `ro.product.model=Zenfone 6`
- `ro.product.product.model=Zenfone 6`
- `ro.product.system_ext.model=Zenfone 6`
- `ro.product.manufacturer=ASUS`

The runtime Settings-backed names were also set on the phone:

```bash
adb shell settings put global device_name "'Zenfone 6'"
adb shell settings put secure bluetooth_name "'Zenfone 6'"
```

## Updating Later

There is no OTA path for this setup. Updating means downloading a newer matching `arm64_bvN` vanilla GSI, adapting the patches, validating it, then flashing it as a new system image.

Avoid Android major-version jumps unless intentionally testing. Android 15/16 GSIs may need different patches and may make rollback less clean if `/data` migrates.

## Patch29 Smart Key Remap

Patch29 changes the Zenfone 6 Smart Key source keylayout used by PHH's keylayout overlay:

- `/system/phh/zf6-googlekey_input.kl`

The file now contains:

```text
key 0x248 CAMERA
```

At boot, PHH copies that source to `/mnt/phh/keylayout/googlekey_input.kl` and bind-mounts the generated keylayout directory over `/system/usr/keylayout`.

## Patch30 Dialer Startup Fix

Patch30 changes only `/system/framework/framework.jar` relative to patch29.

The LineageOS Dialer crashed on startup because `com.android.dialer` called `android.app.role.RoleManager.isRoleHeld(String)`, but the patched framework role stub did not expose that Android 14 API. The crash was:

```text
java.lang.NoSuchMethodError: No virtual method isRoleHeld(Ljava/lang/String;)Z in class Landroid/app/role/RoleManager;
```

Patch30 adds a narrow compatibility method to the `RoleManager` stub. It returns true only when package `com.android.dialer` asks whether it holds `android.app.role.DIALER`, and returns false otherwise. The fix was live-tested on the phone: Android booted, `com.android.dialer/.main.impl.MainActivity` displayed, and no fatal Dialer exception was logged.


