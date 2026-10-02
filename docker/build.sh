#!/bin/bash
# 容器内执行: 构建 AURA-OS live ISO
# 关键: 构建必须在容器本地文件系统 /build 进行 ——
# macOS bind mount (virtiofs/gRPC-FUSE) 上 tar 解包 deb 会失败。
# /build 挂载在 named volume 上以保留 bootstrap 缓存, 仅最终 ISO 拷回 /work/out。
#
# 磁盘峰值控制 (实测 CI 失败: xorriso "Image size exceeds free space on media"):
# live-build 默认把每个 stage 打包成 cache/*.tar (chroot.tar ≈ 整份未压缩 chroot),
# binary 阶段 cache + chroot + binary/squashfs + ISO 同时存在, 撑爆 runner 磁盘。
# 对策: --cache false 禁用 stage 缓存; 修剪由 hooks/9000-prune.chroot 完成
# (hooks 在包安装之后执行, 见 docs/03 踩坑 5)。
set -ex

BUILD=/build

mkdir -p "$BUILD"
cd "$BUILD"
# 增量构建: 复用缓存 chroot, 仅 CLEAN=1 时全清
if [ "${CLEAN:-0}" = "1" ]; then lb clean || true; fi

# 从 /work 同步配置 (每次构建取最新)
rm -rf "$BUILD/config"
cp -a /work/config "$BUILD/"

lb config noauto \
    --distribution trixie \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --archive-areas "main contrib non-free non-free-firmware" \
    --cache false \
    --bootappend-live "boot=live components username=aura hostname=aura-os console=ttyS0 locales=zh_CN.UTF-8" \
    "${@}"

df -h "$BUILD" || true
lb build
df -h "$BUILD" || true

mkdir -p /work/out
if [ -f binary.img ]; then
    cp binary.img /work/out/auraos-1.0-amd64.iso
elif [ -f live-image-amd64.hybrid.iso ]; then
    cp live-image-amd64.hybrid.iso /work/out/auraos-1.0-amd64.iso
fi
ls -la /work/out/
