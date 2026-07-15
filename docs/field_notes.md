# Field Notes

These are informal notes from the Zenfone 6 bring-up. They include dead ends and judgement calls that do not belong in the clean reproduction path.

## Starting Point

The phone was a Zenfone 6 / I01WD / ZS630KL on old ASUS firmware with a locked bootloader.

Unlocking the bootloader was the first hard problem. The ASUS unlock app path was investigated with adb, mitmproxy, jadx, apktool, Ghidra, fastboot, and EDL tooling. Network/proxy attempts against the ASUS unlock flow were unreliable. The final successful unlock path was not via a clean server replay; the important long-term artifact for that is the separate unlock reproduction document outside this final LineageOS bundle.

Once unlocked, wiping `/data` through TWRP initially failed with f2fs/encryption/mount-busy errors. Rebooting bootloader/recovery and using fastboot/TWRP carefully eventually got the device to a clean setup state.

## Why A GSI Was Chosen

A device-specific LineageOS port was considered, but the LineageOS 21 GSI became usable faster than expected. Core hardware worked after patching: Wi-Fi, Bluetooth, camera motor, fingerprint, audio, storage, hotspot, sensors, USB, and reboot persistence.

A device-specific build is still cleaner long-term, but it is not obviously worth the cost unless we want a maintainable public port, OTA-style rebuilds, SELinux cleanup, IMS/VoLTE work, or deeper NFC/GNSS/power polish.

## GSI Variant

The working image class is `arm64_bvN`, vanilla, Android 14 / LineageOS 21. Do not randomly switch to `a64`, GApps, vndklite, Android 15, or Android 16 variants without treating it as a new bring-up.

The current phone reports this as a LineageOS GSI, not an official Zenfone-specific LineageOS device build.

## Patch History

Earlier patch images were exploratory and should not be treated as known-good.

Patch25 got many framework/tethering pieces close, but patch26 introduced a subtle corruption problem.

Patch26 symptom:

- Eleven Music crashed/closed instantly.
- ThemePicker also had class/dex problems.

Patch26 root cause:

- The Android ext image used shared blocks.
- Replacing files with `debugfs` without first unsharing blocks corrupted unrelated APK data that shared the same backing blocks.

Patch27 fix:

- Rebuild from a cleaner stage-base image.
- Expand/resize the image.
- Run `e2fsck -fy -E unshare_blocks` before any file replacement.
- Replace framework/services/APEX payloads only after unsharing.
- Validate unrelated APKs, especially Eleven and ThemePicker.

Patch28:

- Same as patch27, plus image-level model/manufacturer rename from `TrebleDroid vanilla`/`unknown` to `Zenfone 6`/`ASUS` in product and system_ext build props.

Patch29:

- Same as patch28, plus Zenfone 6 Smart Key keylayout remap.
- The hardware reports `KEY_KBD_LAYOUT_NEXT` / Linux key code `0x248` through `googlekey_input`.
- Patch29 maps `0x248` to `CAMERA` in `/system/phh/zf6-googlekey_input.kl`, which PHH then projects into `/system/usr/keylayout/googlekey_input.kl`.

Patch30:

- Same as patch29, plus a Dialer startup fix in `/system/framework/framework.jar`.
- The crash was a missing Android 14 API on the patched framework role stub: `RoleManager.isRoleHeld(String)`.
- The shim returns true only for `com.android.dialer` asking for `android.app.role.DIALER`, and false otherwise.
- This was live-tested: the phone booted, Dialer displayed `MainActivity`, and no fatal Dialer exception was logged.

## What Worked

The safe ext image workflow worked:

1. Start from the preserved stage-base image.
2. Expand to 3 GiB.
3. `resize2fs` to 786432 4K blocks.
4. `e2fsck -fy -E unshare_blocks`.
5. Use `debugfs` to remove and write replacement payloads.
6. Set mode/uid/gid and SELinux xattrs for framework/APEX payloads.
7. Run `e2fsck -fy` or `e2fsck -fn` after writes.
8. Flash with fastboot.
9. Validate apps and hardware, not just boot.

The model rename worked by changing:

- `/product/etc/build.prop`: `ro.product.product.manufacturer`, `ro.product.product.model`
- `/system_ext/etc/build.prop`: `ro.product.system_ext.manufacturer`, `ro.product.system_ext.model`

At runtime, Android then resolved:

- `ro.product.model=Zenfone 6`
- `ro.product.manufacturer=ASUS`

The Settings-backed device name and Bluetooth name also needed runtime settings writes.

## What Did Not Work Or Was Not Worth Pursuing

Blind server/proxy replay for ASUS unlock was not reliable.

Patch26-style direct debugfs replacement without unsharing ext shared blocks is unsafe.

Trying to judge success by boot alone is insufficient. Patch26 booted but corrupted apps.

Device Controls being unavailable was not a ROM failure. It just had no installed controls provider service.

Battery Saver being unavailable in quick settings while plugged in was not a ROM failure. SystemUI marks that tile unavailable when the device is plugged in.

Browser geolocation did not work, likely because there is no network location provider/GApps. That is not the same as proving GNSS is broken.

Restoring Qualcomm's old location framework package was not the answer for this stock base. The official ASUS WW image checked during the investigation did not contain `com.qualcomm.location.apk`, `com.qti.location.sdk.jar`, `izat.xt.srv.jar`, `liblocationservice_jni.so`, or `libxt_native.so`. A donor Qualcomm location stack attempt caused a UI/system loop and was rolled back. Missing Qualcomm framework APKs are therefore not a proven root cause for this device/image combination.

The temporary `gps.conf` experiment using an SM8150-style LPP/SUPL/XTRA tweak did not fix acquisition and was reverted. The final phone state uses the previous live `/vendor/etc/gps.conf`. Qualcomm library strings warned when any `RF_LOSS_*` value was zero, so keeping the RF loss values non-zero appears preferable.

Temporarily setting SELinux permissive did not fix GNSS acquisition. Denials seen during testing, such as `lowi-server` access to `/dev/diag` and `vendor_hal_gnss_qti` reading `vendor_pd_locater_dbg_prop`, looked diagnostic/debug-related rather than acquisition blockers.

The FastRPC/ADSP warnings around `sscrpcd`, including `apps_std getenv failed: ADSP_LIBRARY_PATH`, were investigated but did not look like the GNSS blocker. The expected DSP/RFSA directories exist, and `libadsprpc.so` has built-in fallback paths including `/vendor/lib/rfsa/adsp`, `/vendor/lib/rfsa/dsp`, and `/vendor/dsp`.

Cellular data was not solved. With a local carrier SIM, cellular data activation was rejected during testing. That is separate from the GNSS result.

## Things Still Untested Or Weakly Tested

SIM/telephony was skipped because no spare SIM was available.

NFC is inconclusive. The service/HAL appears present and another phone read the Zenfone as ISO 14443-4/isodep, nfcb, but the Zenfone showed no visible reaction.

GNSS eventually tested good outdoors, but the original indoor location is poor for this phone. It may still fail to acquire or maintain a fix there even though another phone works in the same spot.

IMS/VoLTE was not tested.

Long-term suspend drain, thermal behavior, and camera edge cases were not tested deeply.

## GNSS Investigation Notes

Initial GPS testing looked bad:

- OsmAnd and GPSTest showed no position.
- Browser geolocation timed out.
- `dumpsys location` showed GPS provider requests and GNSS measurement events, but zero location reports and zero TTFF reports.
- NMEA showed no fix, for example GSA fix type 1, GGA fix quality 0, and RMC void status.
- Early `garden_app` direct Qualcomm testing saw many SV entries, but CNR was zero, ephemeris was absent, and no SVs were used in fix.

This was not because XTRA/PSDS download was impossible. With Wi-Fi enabled, the phone could reach Qualcomm XTRA over HTTPS, and forced PSDS/time injection produced the expected GNSS log markers:

- `LOC_QUERY_XTRA_INFO_REQ`
- `LOC_INJECT_UTC_TIME_REQ`
- `LOC_INJECT_XTRA_PCID_REQ`
- repeated `LOC_INJECT_XTRA_DATA_REQ`

The vendor GNSS service stack was present during testing:

- `loc_launcher`
- `lowi-server`
- `xtra-daemon`
- `mlid`
- `android.hardware.gnss@2.1-service-qti`

The decisive test was physical RF exposure. After taking the phone outside, Android began reporting real GPS fixes. A later `dumpsys location` showed:

- last GPS location successfully outdoors
- location reports: `199`
- TTFF reports: `3`
- TTFF mean: about `18.5` seconds
- used-in-fix constellations: GPS, GLONASS, BEIDOU, GALILEO
- L5 status processed and used

After returning the phone to the original indoor spot, no fresh location reports arrived and measured CN0 dropped again. The practical conclusion is that the GNSS software stack works, but the original test location is a poor RF environment for this phone. Do not spend more time on Qualcomm location APKs, SELinux, or `gps.conf` solely because that spot fails to acquire.

## Operational Notes

Avoid parallel ADB/fastboot commands against the physical phone. It is too easy to outrun the device state. Parallel local file reads are fine; device-facing commands should be serialized.

Keep patch30 as the daily baseline. If testing future images, use the inactive slot only if slot state is understood, and keep a fastboot rollback path.

Do not delete the final image or original upstream archive. The original archive gives provenance; the final image gives a known-good fallback; the stage-base image plus payloads/scripts gives a practical rebuild path.

## If Updating Later

Treat every upstream GSI update as a new port attempt:

- Download the matching `arm64_bvN` vanilla image.
- Re-apply only patches that are still needed.
- Re-check whether new upstream already fixed any old issue.
- Unshare blocks before edits.
- Validate apps and hardware again.
- Be especially cautious with Android major-version jumps because `/data` migration may reduce rollback cleanliness.
