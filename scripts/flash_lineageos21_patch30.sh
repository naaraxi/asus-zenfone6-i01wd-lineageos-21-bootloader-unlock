#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG_ZST="$ROOT/images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img.zst"
IMG="$ROOT/images/lineage-21.0-20250621-arm64_bvN_patch30_smartkey_camera_dialer.img"
VBMETA="$ROOT/images/vbmeta_flags3_empty_64k.img"
SLOT="${SLOT:-a}"

if [[ ! -f "$IMG" ]]; then
  if [[ ! -f "$IMG_ZST" ]]; then
    echo "missing $IMG_ZST" >&2
    exit 1
  fi
  zstd -d -f "$IMG_ZST" -o "$IMG"
fi

sha256sum -c "$ROOT/SHA256SUMS" --ignore-missing

cat <<WARN
About to flash LineageOS 21 GSI patch30 to system_$SLOT.
This requires an already-unlocked bootloader and a phone in fastboot mode.
WARN
read -r -p "Type FLASH to continue: " confirm
if [[ "$confirm" != "FLASH" ]]; then
  echo "aborted" >&2
  exit 1
fi

fastboot devices
fastboot --set-active="$SLOT"
fastboot flash vbmeta_"$SLOT" "$VBMETA" || fastboot flash vbmeta "$VBMETA"
fastboot flash system_"$SLOT" "$IMG"
fastboot -w
fastboot reboot
