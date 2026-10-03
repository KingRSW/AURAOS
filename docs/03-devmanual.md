# AURA-OS 开发手册

## 1. 环境要求

### 构建（二选一）
- **推荐：GitHub Actions**（原生 amd64，无需本地环境）。推送即自动构建。
- **本地：macOS + Docker Desktop**
  - Docker Desktop 设置开启 **Use Rosetta for x86/amd64 emulation**
    （Settings → General），否则 amd64 容器走 qemu 模拟，慢 2-3 倍。
  - 若 Rosetta 不可用且容器卡 "Created" 状态，注册 binfmt：
    ```bash
    docker run --privileged --rm tonistiigi/binfmt --install amd64
    ```

### 测试
```bash
brew install qemu        # qemu-system-x86_64
```

## 2. 一条命令构建

```bash
cd /path/to/AURAOS
make iso                 # 产物: out/auraos-1.0-amd64.iso
```

首次构建下载 KDE+Wine 约 2-3GB deb：CI 数十分钟；本地模拟 40-90 分钟。
增量构建（apt 缓存命中）10-25 分钟。

## 3. 运行与测试

```bash
make run                 # QEMU GUI 窗口 (cocoa), 4G 内存
make test                # 无头: VNC 截图 + 串口断言
```

GUI 启动后用鼠标点击窗口获取焦点，等待自动登录进 Plasma 桌面。

## 4. 修改流程

### 增删软件包
编辑 `config/package-lists/*.list.chroot`（每行一个包名，`#!/bin/bash` 开头）。
**务必先在 https://packages.debian.org/trixie/ 核实包名存在**，否则整个
chroot 安装阶段失败。

### 调整桌面观感
- KWin 特效/主题：`config/hooks/1040-kwin-effects.chroot`
- Panel/Dock 布局：`config/includes.chroot/usr/share/auraos/layout.js`
- 改完重新 `make iso`（或 CI 自动跑）。

### 换用户/主机名
`docker/build.sh` 的 `--bootappend-live` 行：`username=` / `hostname=`。

## 5. 缓存与清理

```bash
make clean               # 清 ISO + lb clean
docker volume rm aura-lb-cache aura-build   # 彻底清缓存 (下次全量重建)
```

## 6. 踩坑记录（实测）

1. **macOS bind mount 上 deb 解包失败**：live-build 必须在容器本地卷 `/build`
   构建，不能直接在 `/work`（virtiofs 上 tar 解包报错）。build.sh 已处理。
2. **Docker amd64 容器卡 Created 状态**：未注册模拟后端。开 Rosetta 或装
   tonistiigi/binfmt。
3. **包名臆测导致整构建失败**：`task-live`、`plasma-workspace-wayland`、
   `kwin-effects-forceblur`、`breeze-icons-extra`、`plasma-nm6`、
   `language-pack-zh-hans` 在 trixie 均不存在。改包名前必查 packages.debian.org。
4. **Plasma 6 Wayland 会话并入 plasma-workspace**：不再单独有
   plasma-workspace-wayland 包；SDDM 会话名需动态检测 wayland-sessions/xsessions。
5. **wine32:i386 不能在 package-lists 直接写**：i386 架构在 hooks 阶段才
   `dpkg --add-architecture`，package-lists 早于 hooks，会找不到包。放 hook 装。
6. **手写 appletsrc 崩溃**：Plasma 布局配置文件版本漂移大，改用 DesktopSettings
   JS API + try/catch 注入。
7. **git 连不上 github.com 443**：本机走 127.0.0.1:7897 代理，git 不读系统代理，
   需 `git -c http.proxy=http://127.0.0.1:7897 push`。
8. **CI xorriso "Image size exceeds free space on media"**：live-build 默认把每个
   stage 打包成 `cache/*.tar`（chroot.tar ≈ 整份未压缩 chroot），binary 阶段
   cache + chroot + squashfs + ISO 同时落盘撑爆 runner。对策：`lb config
   --cache false` + `hooks/9000-prune.chroot`（apt clean、删 man/info/多余 locale）。
9. **GitHub runner 磁盘先天不足**：ubuntu-24.04 runner 预装 .NET/Android SDK/GHC
   占 15-30GB，构建前需 `rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc
   /opt/hostedtoolcache`（见 build.yml "Free disk space" step）。
10. **布局脚本 plasmoid ID 同样要核实**：`org.kde.plasma.windowtitle` 在 trixie
    不存在（在 Plasma 5 属 kdeplasma-addons，6 中无此包）；`panelspacer` 在
    plasma-workspace、`trash` 在 plasma-desktop。核实方法：查
    `qt6/plugins/plasma/applets/*.so` 或 `plasmoids/` 目录的包文件列表。

## 7. 真机验证（需 x86 物理机）

QEMU 软件渲染下 **blur 毛玻璃与 DXVK 无法真实验证**。在 x86 真机：
```bash
# 刻录或 dd 到 U 盘
dd if=out/auraos-1.0-amd64.iso of=/dev/sdX bs=4M status=progress
# 启动后:
free -h                          # 目标空闲内存 > 1.5G (4G 机器)
systemd-analyze                  # 开机耗时
wine notepad.exe                 # Wine 冒烟
sudo mount -t ntfs3 /dev/sdBY /mnt   # NTFS
```
