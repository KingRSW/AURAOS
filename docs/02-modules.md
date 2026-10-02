# AURA-OS 模块接口说明

本仓库即构建配置本身，各"模块"对应 live-build 配置树中的目录/文件。

## 1. 顶层入口

### `Makefile`
| 目标 | 说明 |
|------|------|
| `make iso` | 构建 builder 镜像并在容器内跑 `lb build`，产物 `out/auraos-1.0-amd64.iso` |
| `make run` | QEMU GUI 启动 ISO（`-display cocoa`，4G 内存） |
| `make test` | 调用 `tests/qemu-boot.sh` 无头回归 |
| `make clean` | 删除 out/ 并容器内 `lb clean --all` |

卷约定：`aura-lb-cache:/var/cache/live`（apt 缓存）、`aura-build:/build`（chroot 工作区）。

### `docker/Dockerfile`
构建器镜像：`debian:trixie` + `live-build debootstrap squashfs-tools isolinux
grub-pc-bin grub-efi-amd64-bin xorriso eatmydata`。

### `docker/build.sh`（容器内执行）
- 输入：`/work/config`（本仓库配置树）、环境变量 `CLEAN=1`（全清重建）。
- 行为：`lb config noauto --distribution trixie --architectures amd64
  --binary-images iso-hybrid --archive-areas "main contrib non-free
  non-free-firmware" --bootappend-live "boot=live components username=aura
  hostname=aura-os console=ttyS0"` → `lb build`。
- 输出：`binary.img` 或 `live-image-amd64.hybrid.iso` 拷贝为
  `/work/out/auraos-1.0-amd64.iso`。

### `.github/workflows/build.yml`
ubuntu-24.04 原生 amd64：checkout → `docker build` → `docker run --privileged`
跑 build.sh → `upload-artifact`（`auraos-iso`，保留 14 天）。

## 2. `config/` 配置树

### `config/architectures`
`amd64`。

### `config/package-lists/*.list.chroot`（live-build 自动安装）
| 文件 | 职责 | 关键包 |
|------|------|--------|
| `00-base` | 基础工具 | sudo vim-nox net-tools openssh-server curl |
| `10-kde-macos` | Plasma 6 桌面栈 | plasma-desktop plasma-workspace sddm sddm-theme-breeze konsole dolphin breeze breeze-gtk-theme qt6-style-kvantum xdg-desktop-portal-kde papirus-icon-theme |
| `20-windows-compat` | Windows 兼容层 | wine wine64 winetricks dosbox-x ntfs-3g exfatprogs smbclient cifs-utils gvfs-backends cups printer-driver-all hplip printer-driver-foo2zjs |
| `30-perf` | 性能 | zram-tools earlyoom plymouth plymouth-themes |
| `40-firmware-fonts` | 固件+中文字体 | firmware-linux firmware-misc-nonfree firmware-iwlwifi fonts-noto-cjk locales |

包名均经 `packages.debian.org/trixie` 核实（不存在的包：plasma-workspace-wayland、
kwin-effects-forceblur、breeze-icons-extra、plasma-nm6、language-pack-zh-hans）。

### `config/hooks/*.chroot`（chroot 构建后、打包前以 root 执行）
| 文件 | 输入 | 输出/副作用 |
|------|------|-------------|
| `1000-locale-zh` | — | zh_CN.UTF-8 生成并设为默认；时区 Asia/Shanghai |
| `1010-autologin` | xsessions/wayland-sessions 目录 | `/etc/sddm.conf.d/aura-autologin.conf`（动态检测会话名，Wayland 优先）；enable sddm |
| `1020-i386-wine` | apt 源 | `dpkg --add-architecture i386` + 安装 wine32:i386（失败降级不阻断） |
| `1030-perf` | — | enable zramswap/earlyoom；plymouth 主题；disable bluetooth/avahi |
| `1040-kwin-effects` | — | `/etc/skel/.config/{kwinrc,kdeglobals,kcmfonts}` + `/etc/skel/.config/Kvantum/kvantumrc`（blur/fade/overview 启用、Breeze 装饰、动画 120ms） |

### `config/includes.chroot/`（原样拷入 rootfs）
| 路径 | 说明 |
|------|------|
| `etc/skel/.config/autostart/aura-layout.desktop` | 首启 autostart 项，触发布局脚本 |
| `usr/share/auraos/layout.js` | Plasma DesktopSettings JS：顶部 Panel（kickoff+globalmenu+时钟+托盘）+ 底部浮动 auto-hiding Dock（icontasks+launchers），全程 try/catch |
| `usr/share/auraos/apply-layout.sh` | 等待 plasmashell DBus 就绪 → `qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript` 注入 layout.js；标记文件防重复执行 |
| `etc/aura-release` | 发行版标识 |

## 3. `tests/`

### `tests/qemu-boot.sh [ISO]`
- 无头 QEMU（`-display none -vga virtio -vnc :17 -serial file:/tmp/aura-serial.log`）。
- 等待 120s 后截图（vncsnapshot/ffmpeg 可选）+ 串口断言：
  `Linux version` / `systemd[1]` / `Reached target` / `sddm` / `Live system`。
- 退出码 0 = 全部通过。

## 4. 运行时接口（ISO 内）

### 用户与登录
- live 用户：`aura`（live-config 按 `username=aura` 创建，免密 sudo）。
- SDDM 自动登录 → Plasma Wayland 会话；主机名 `aura-os`；串口控制台 ttyS0。

### 系统调用面（对用户）
- 桌面：顶部菜单栏（全局菜单）、底部 Dock、Meta+W 概览。
- Windows 应用：`wine 程序.exe`、`winetricks 组件`、`dosbox-x 游戏`。
- 文件：NTFS/exFAT U 盘即插即挂（udisks2/Dolphin）；SMB 浏览（gvfs+Dolphin）。
- 打印：CUPS + printer-driver-all。
