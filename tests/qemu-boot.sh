#!/bin/bash
# AURA-OS 无头启动测试: QEMU 引导 ISO + VNC 截图 + 串口断言。
# 依赖: qemu-system-x86_64, vncsnapshot, nc。
# 用法: tests/qemu-boot.sh [ISO路径]
# 说明: SYSLINUX 菜单需 sendkey 确认默认条目; TCG 软件模拟启动 Plasma 很慢,
#       故轮询串口日志直至 systemd 就绪 (上限 BOOT_TIMEOUT 秒)。
set -u

ISO="${1:-out/auraos-1.0-amd64.iso}"
[ -f "$ISO" ] || { echo "ISO 不存在: $ISO"; exit 1; }

SERIAL=/tmp/aura-serial.log
VNC_DISP=17                 # VNC 显示号 :17 (端口 5917)
BOOT_TIMEOUT="${BOOT_TIMEOUT:-900}"   # 启动等待上限 (秒)
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

mon() { printf "%s\n" "$1" | nc -U -w 2 "$WORK/mon.sock" 2>/dev/null; }

echo "[*] 确认 SYSLINUX 默认启动条目 (sendkey ret) ..."
sleep 10
mon "sendkey ret"
sleep 5
mon "sendkey ret"   # 双保险: 部分固件首键被吞

echo "[*] 轮询串口日志直至启动就绪 (上限 ${BOOT_TIMEOUT}s) ..."
ELAPSED=0
while [ "$ELAPSED" -lt "$BOOT_TIMEOUT" ]; do
    if grep -qi "Reached target" "$SERIAL" 2>/dev/null; then
        echo "[+] 检测到 systemd 目标达成, 再等待桌面拉起 (300s) ..."
        sleep 300
        break
    fi
    sleep 15
    ELAPSED=$((ELAPSED+15))
    [ $((ELAPSED % 60)) -eq 0 ] && echo "    ... ${ELAPSED}s, 串口 $(wc -c <"$SERIAL" 2>/dev/null || echo 0) 字节"
done

# 截图 (vncsnapshot)
SHOT="$WORK/desktop.png"
vncsnapshot "localhost:$VNC_DISP" "$SHOT" 2>/dev/null || true
[ -f "$SHOT" ] && echo "[+] 截图: $SHOT"

# 串口断言
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
check "filesystem.squashfs"      "live-boot 挂载 live 根"

echo "[*] 关闭 QEMU ..."
mon "system_powerdown"
sleep 3
kill "$QPID" 2>/dev/null || true

echo "=============================="
echo "结果: $PASS 通过 / $FAIL 失败"
echo "完整日志: $SERIAL"
[ "$FAIL" -eq 0 ] || exit 1
