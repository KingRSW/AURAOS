#!/bin/sh
# AURA-OS headless smoke test: boot in QEMU, capture serial log + screenshot.
# usage: tests/smoke.sh [image]
IMG=${1:-out/auraos.img}
DIR=$(mktemp -d)
echo "smoke: booting $IMG (logs in $DIR)"

(
    sleep 45
    echo screendump "$DIR/aura.ppm"
    sleep 2
    echo quit
) | qemu-system-x86_64 \
    -drive format=raw,file="$IMG" \
    -m 512 \
    -display none \
    -serial file:"$DIR/serial.log" \
    -monitor stdio > /dev/null 2>&1

echo "--- serial log ---"
cat "$DIR/serial.log"

if grep -q "\[aura\] ready" "$DIR/serial.log"; then
    echo "smoke: PASS"
    rc=0
else
    echo "smoke: FAIL (no ready marker)"
    rc=1
fi
if grep -q "AURA-FAULT" "$DIR/serial.log"; then
    echo "smoke: CPU FAULT detected"
    rc=1
fi
if [ -f "$DIR/aura.ppm" ]; then
    python3 - "$DIR/aura.ppm" "$DIR/aura.png" <<'EOF'
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2])
print("screenshot:", sys.argv[2])
EOF
fi
exit $rc
