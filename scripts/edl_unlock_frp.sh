#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER="${LOADER:-$ROOT/loaders/i01wd_fhprg.bin}"
EDL="${EDL:-edl}"
OUTDIR="${OUTDIR:-$ROOT/work/edl}"
mkdir -p "$OUTDIR"

BEFORE="$OUTDIR/frp_before_unlock.bin"
PATCHED="$OUTDIR/frp_unlock_ability1.bin"
AFTER="$OUTDIR/frp_after_unlock_write.bin"

cat <<WARN
This writes the FRP partition on the connected Zenfone 6 from EDL.
It sets only the final byte of FRP to 0x01, then powers the phone off.
After poweroff, DO NOT boot Android. Manually boot directly to fastboot with Volume Up + Power.

Using:
  EDL=$EDL
  LOADER=$LOADER
  OUTDIR=$OUTDIR
WARN

read -r -p "Type UNLOCK to continue: " confirm
if [[ "$confirm" != "UNLOCK" ]]; then
  echo "aborted" >&2
  exit 1
fi

sudo "$EDL" nop --loader="$LOADER"
sudo "$EDL" r frp "$BEFORE" --memory=ufs --lun=0 --loader="$LOADER"
"$ROOT/scripts/patch_frp_unlock_ability.sh" "$BEFORE" "$PATCHED"
sudo "$EDL" w frp "$PATCHED" --memory=ufs --lun=0 --loader="$LOADER"
sudo "$EDL" r frp "$AFTER" --memory=ufs --lun=0 --loader="$LOADER"
cmp "$PATCHED" "$AFTER"
xxd -g1 -s -16 "$AFTER"
sudo "$EDL" reset --resetmode=off --loader="$LOADER" || true

cat <<DONE

FRP was patched and EDL poweroff was requested.
Immediately boot to fastboot manually:
  Hold Volume Up + Power.
  Release Power when the phone vibrates/lights.
  Keep Volume Up held until fastboot appears.

Then run:
  fastboot flashing get_unlock_ability
  fastboot flashing unlock
DONE
