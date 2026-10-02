# AURA-OS 架构设计文档

## 1. 项目定位

AURA-OS 是一个基于 **Debian 13 (trixie)** 的定制 Linux 发行版，通过 `live-build`
构建为可引导混合 ISO（El Torito + UEFI），目标特性：

| 特性 | 实现路径 |
|------|----------|
| macOS 级流畅体验 | KDE Plasma 6 (Wayland) 精简栈 + zram + earlyoom + 关闭非必要服务 |
| Windows 生态兼容 | Wine 10 + winetricks + dosbox-x + NTFS/exFAT/SMB + CUPS 打印机驱动 |
| 开源 | 全部构建配置源码化于本仓库，基于 Debian 自由软件仓库 |
| 精美 UI | 顶部全局菜单栏 + 底部浮动 Dock + KWin 毛玻璃 + Breeze 主题 |

## 2. 总体架构

```
┌─────────────────────────────────────────────────┐
│                  用户 (aura, ring3)              │
│  Plasma 6 Shell (Wayland) · Konsole · Dolphin    │
│  Windows 应用 (Wine/dosbox-x)                    │
├─────────────────────────────────────────────────┤
│              KDE 框架层 (KF6 / Qt6)              │
│  KWin 合成器: blur · fade · overview · 圆角      │
│  Kvantum 主题引擎 · Breeze 装饰                  │
├─────────────────────────────────────────────────┤
│            Debian 用户空间 (trixie)              │
│  systemd · sddm · live-config · pulseaudio       │
│  wine 10 · cups · ntfs-3g · exfatprogs · smb     │
├─────────────────────────────────────────────────┤
│              Linux 内核 6.12 + 固件              │
│  E820/UEFI · 内存管理 · 调度 · 驱动 · net/usb    │
├─────────────────────────────────────────────────┤
│        live-boot (squashfs + overlayfs)          │
│  ISO 只读根文件系统 + 内存可写层                  │
└─────────────────────────────────────────────────┘
```

## 3. 构建架构

```
macOS (Apple Silicon)                GitHub Actions (ubuntu-24.04, 原生 amd64)
─────────────────────                ─────────────────────────────────────────
make iso                             push → build.yml
  └─ docker run --privileged           └─ docker build docker/Dockerfile
       └─ debian:trixie 容器                └─ debian:trixie 容器
            └─ lb config && lb build             └─ lb config && lb build
                 (qemu-x86 模拟, 慢)                  (原生 amd64, 主路径)
                 → out/*.iso                          → artifact: auraos-iso
```

- **CI 为主构建路径**：macOS 上 Docker amd64 模拟下载/解包极慢（实测 90KB/s），
  GitHub Actions 原生 runner 数十分钟完成全量构建。
- **构建在容器本地卷 `/build` 进行**：macOS bind mount (virtiofs) 上 tar 解包
  deb 包会失败，故 ISO 中间产物放 named volume，仅最终 ISO 拷回 `/work/out`。

## 4. 关键设计决策

### 4.1 桌面环境：KDE Plasma 6 (非 GNOME)
- 全局菜单栏 plasmoid 原生支持（macOS 顶部菜单条核心）。
- KWin 6.3 自带 blur/fade/overview 特效与圆角装饰，无需扩展链。
- 配置可全脚本化（`/etc/skel` + autostart JS），复现性强。
- 最小化 Plasma 内存占用低于 GNOME 约 300-500MB。

### 4.2 Wine：Debian 官方 10.0（非 WineHQ wine-staging）
- trixie 无 wine-staging 包；引入 WineHQ 第三方源 + i386 multiarch 会显著
  增加构建脆弱性（密钥、依赖冲突）。官方 wine/wine64 覆盖主流兼容需求。
- wine32 通过 chroot hook 在 `dpkg --add-architecture i386` 后安装，失败降级
  为仅 wine64，不阻断 ISO 构建。

### 4.3 Dock：原生 Panel 伪装（无 Latte Dock）
- Latte Dock 已死（无 Plasma 6 移植）。方案：底部 floating + auto-hide 居中
  Panel + icontasks + launchers，毛玻璃由 KWin blur 提供。
- 放弃 hover 放大动效（Plasma 6 生态无成熟开源件），用 Overview (Meta+W)
  补位 Mission Control。

### 4.4 布局注入：evaluateScript 而非预置 appletsrc
- 手写 `plasma-org.kde.plasma.desktop-appletsrc` 因 Plasma 版本漂移极易崩溃。
- 采用官方 DesktopSettings JS API，首启 autostart 经 qdbus 注入，全程
  try/catch 防御式执行，失败仅保留默认布局。

### 4.5 已知限制
- QEMU 软件渲染下 KWin blur 特效与 DXVK 无法真实验证（需 x86 真机 GPU）。
- Wine "高度兼容 Windows" 是业界公认最难项，本系统提供的是 Wine 生态的
  完整集成（可运行大量应用），而非 100% 兼容承诺。

## 5. ISO 产物结构

```
auraos-1.0-amd64.iso (hybrid, ~2.5-3.5GB)
├── boot/grub          # GRUB (BIOS + UEFI 双模引导)
├── live/
│   ├── vmlinuz        # Linux 6.12 内核
│   ├── initrd.img     # live-boot initramfs
│   └── filesystem.squashfs   # 只读 rootfs (Plasma+Wine+固件)
└── .disk/             # live-boot 元数据
```

启动流程：固件 → GRUB → live-boot 挂载 squashfs → overlayfs → systemd →
SDDM 自动登录 aura → Plasma Wayland 会话 → autostart 注入布局。
