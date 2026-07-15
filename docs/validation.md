# Validation Notes

Validated on the Zenfone 6 after patch30 live testing:

- Boot completes.
- Reboot persistence works.
- Wi-Fi connects and browser works.
- Bluetooth scans, pairs, and connects.
- Rear camera works.
- Camera switch works.
- Flip camera motor works.
- Camera can take and save photos.
- Fingerprint enrollment works.
- Fingerprint unlock works, including wake.
- USB/ADB works.
- ADB push/pull byte comparison passed.
- Hotspot enables and another phone can connect.
- Sensors, display, brightness, rotation, and buttons work.
- Speaker works.
- Microphone recording works.
- Recorder playback works.
- Charging and battery stats work.
- Vibration works.
- Lock/security basics work.
- Files opens and internal storage/media are visible.
- Gallery opens and sees saved media.
- Eleven Music launches after patch27/patch28.
- ThemePicker launches after patch27/patch28.
- Phone/Dialer launches after patch30.
- GNSS/GPS works outdoors after cold/warm acquisition. After taking the phone outside, Android reported GPS fixes successfully outdoors, TTFF reports, used-in-fix satellites, and GPS/GLONASS/BEIDOU/GALILEO constellations. The original indoor test spot is a poor RF environment for this phone and may show no fresh fixes.
- F-Droid, WhatsApp, Signal, PlayTube, Fennec, OsmAnd, and GPSTest can be installed/launched unless the app itself has a separate issue.

Skipped:

- SIM/mobile data. A local carrier SIM registered enough to test APN attempts, but cellular data activation was rejected during this session. GPS success outdoors does not prove SIM data would work there.

Partial/inconclusive:

- NFC service/HAL appear present. Another phone could read the Zenfone as ISO 14443-4/isodep, nfcb, but the Zenfone did not visibly react and no extra NFC app could be installed during testing.
- Browser geolocation timed out. This is likely no network location provider / no GApps rather than a Zenfone-specific GNSS hardware failure.

Expected UI states:

- Battery Saver quick tile is unavailable while the phone is plugged in. SystemUI marks the tile unavailable when `mPluggedIn` is true.
- Device Controls quick tile is unavailable without an installed app exposing `android.service.controls.ControlsProviderService`.

Patch29 addition:

- Zenfone 6 Smart Key source and active PHH keylayout now map `0x248` to `CAMERA`:
  - `/system/phh/zf6-googlekey_input.kl`
  - `/system/usr/keylayout/googlekey_input.kl`

Patch30 addition:

- Dialer startup fixed by adding `RoleManager.isRoleHeld(String)` compatibility behavior to the patched framework stub.
