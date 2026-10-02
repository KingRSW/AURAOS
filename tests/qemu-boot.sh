#!/bin/bash
# AURA-OS 无头启动测试: QEMU 引导 ISO + VNC 截图 + 串口断言。
# 依赖: qemu-system-x86_64, 可选 vncsnapshot/ffmpeg 截图。
# 用法: tests/qemu-boot.sh [ISO路径]
set -u

ISO="${1:-out/auraos-1.0-amd64.iso}"
[ -f "$ISO" ] || { echo "ISO 不存在: $ISO"; exit 1; }

SERIAL=/tmp/aura-serial.log
VNC_DISP=17                 # VNC 显示号 :17 (端口 5917)
WORK=/tmp/aura-test-$$
mkdir -p "$WORK"
rm -f "$SERIAL"

echo "[*] 启动 QEMU (无头, VNC :$VNC_DISP) ..."
qemu-system-x86_64 \
    -m 4G -smp 2 \
    -cdrom "$ISO" -boot d \
    -display none -vga virtio \
    -vnc ":$VNC_DISP" \
    -serial file:"$SERIAL" \
    -monitor "unix:$WORK/mon.sock,server,nowait" \
    -daemonize
QPID=$(pgrep -f "cdrom $ISO" | head -1)

echo "[*] 等待 live 系统启动 (TCG/软件渲染较慢, 给 120s) ..."
sleep 120

# 截图 (优先 vncsnapshot, 退回 ffmpeg)
SHOT="$WORK/desktop.png"
if command -v vncsnapshot >/dev/null 2>&1; then
    vncsnapshot "localhost:$VNC_DISP" "$SHOT" 2>/dev/null || true
elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -f x11grab -video_size 1024x768 -i ":0.0" -frames:v 1 "$SHOT" 2>/dev/null || true
fi
[ -f "$SHOT" ] && echo "[+] 截图: $SHOT"

# 串口断言: 内核横幅 + systemd 启动完成
echo "[*] 串口日志检查:"
PASS=0; FAIL=0
check() {
    if grep -qi "$1" "$SERIAL"; then echo "  ✓ $2"; PASS=$((PASS+1));
    else echo "  ✗ $2"; FAIL=$((FAIL+1)); fi
}
check "Linux version"            "内核启动"
check "systemd\[1\]"             "systemd PID 1"
check "Reached target"           "systemd 目标达成"
check "sddm"                     "SDDM 显示管理器"
check "Live system"              "live-boot 进入 live 环境"

echo "[*] 关闭 QEMU ..."
if [ -S "$WORK/mon.sock" ]; then
    printf "system_powerdown\n" | nc -U "$WORK/mon.sock" 2>/dev/null || true
fi
sleep 3
kill "$QPID" 2>/dev/null || true

echo "=============================="
echo "结果: $PASS 通过 / $FAIL 失败"
echo "完整日志: $SERIAL"
[ "$FAIL" -eq 0 ] || exit 1
