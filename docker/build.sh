#!/bin/bash
# 容器内执行: 构建 AURA-OS live ISO
# 关键: 构建必须在容器本地文件系统 /build 进行 ——
# macOS bind mount (virtiofs/gRPC-FUSE) 上 tar 解包 deb 会失败。
# /build 挂载在 named volume 上以保留 bootstrap 缓存, 仅最终 ISO 拷回 /work/out。
set -ex

STAGE="${STAGE:-0}"
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
    --bootappend-live "boot=live components username=aura hostname=aura-os" \
    "${@}"

lb build

mkdir -p /work/out
if [ -f binary.img ]; then
    cp binary.img /work/out/auraos-1.0-amd64.iso
elif [ -f live-image-amd64.hybrid.iso ]; then
    cp live-image-amd64.hybrid.iso /work/out/auraos-1.0-amd64.iso
fi
ls -la /work/out/
