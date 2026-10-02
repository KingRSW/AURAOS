#!/bin/bash
# AURA-OS 首启: 应用 Plasma 布局 (顶部菜单栏 + 底部 Dock)。
# 由 ~/.config/autostart/aura-layout.desktop 在登录时触发。
# 等待 plasmashell 就绪后, 经 qdbus evaluateScript 注入布局脚本。
set -u

LAYOUT=/usr/share/auraos/layout.js
[ -f "$LAYOUT" ] || exit 0

# 等待 plasmashell 的 DBus 服务出现 (最多 60s)
for i in $(seq 1 60); do
    if qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "function(){return 1;}" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# 仅在首次 (标记文件不存在) 执行, 避免每次登录重置用户自定义布局
MARK="$HOME/.config/aura-layout.applied"
if [ ! -f "$MARK" ]; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$LAYOUT")" 2>/dev/null || true
    touch "$MARK"
fi
