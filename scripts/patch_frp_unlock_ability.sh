#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <frp_before.bin> <frp_unlock_ability1.bin>" >&2
  exit 2
fi

IN="$1"
OUT="$2"
SIZE=524288
OFFSET=524287

actual_size="$(stat -c '%s' "$IN")"
if [[ "$actual_size" != "$SIZE" ]]; then
  echo "error: expected FRP image size $SIZE bytes, got $actual_size" >&2
  exit 1
fi

cp "$IN" "$OUT"
printf '\001' | dd of="$OUT" bs=1 seek="$OFFSET" conv=notrunc status=none

echo "Patched final FRP byte to 0x01: $OUT"
echo "Expected cmp -l output, if original byte was 0: 524288 0 1"
cmp -l "$IN" "$OUT" || true
xxd -g1 -s -16 "$OUT"
