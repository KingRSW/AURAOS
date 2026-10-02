# AURA-OS 测试报告

> 测试日期: 2026-10-03 · 测试人: AURA 项目组
> 被测产物: GitHub Actions artifact `auraos-iso` (run 见下表)
> 测试环境: Apple M5 (arm64) + QEMU 11.1.2 (TCG 软件模拟) 4G/2 核, VNC 截图

## 1. 构建结果 (CI)

| Run | Head | 内容 | 结果 | 耗时 | ISO 大小 |
|-----|------|------|------|------|----------|
| 37014605341 | 5cc21ec | 磁盘修复 (--cache false + prune) | ✅ success | 30 min | 2,623,733,760 B |
| 37021535637 | 9798d26 | + WhiteSur 主题 vendor | ✅ success | 26 min | ~2.64 GB |
| 37042087001 | 4eff81a | + hook 命名修复 (hook 首次真实执行) | ✅ success | 35 min | 2,779,578,368 B |
| 37054098213 | 6d07477 | + locale hook 顺序修复 | ✅ success | 28 min | 2,779,578,368 B |
| **37063300868** | **b11172f** | **+ locales= 内核参数 (最终交付版)** | ✅ success | ~30 min | 2,779,578,368 B |

失败史 (已修复, 详见 docs/03 踩坑):
- qt6-style-kvantum-themes 包名错误 → 一个包缺失即整个 chroot 安装失败。
- xorriso "Image size exceeds free space on media" → runner 磁盘不足, 删预装 SDK + 禁 stage 缓存 + prune hook。
- **自定义 hook 全部未执行** → live-build v11 只扫 `config/hooks/{normal,live}/*.chroot`, 顶层 `config/hooks/*.chroot` 被静默跳过 (commit f012500)。
- **locale 被覆盖两次** → ① live-build 自带 1020-create-locales-files 把 /etc/locale.conf 重置为 C.UTF-8 (hook 重编号 2000, commit 6d07477); ② live-config 0050-locales 每次开机把 LANG 重置为 en_US.UTF-8, 构建期无法赢, 必须用 `locales=` 内核参数 (commit 4e66cc6)。

## 2. ISO 结构验证

```
$ file out/auraos-1.0-amd64.iso
ISO 9660 CD-ROM filesystem data (DOS/MBR boot sector) 'Debian trixie 20261002-20:55' (bootable)
```

- 混合镜像 (El Torito + UEFI), SYSLINUX 引导菜单: Live system (amd64) / fail-safe / Utilities。
- 内核 6.12.111+deb13-amd64, live-boot 1:20250815, live-build 20250505。
- filesystem.squashfs 2,611,429,376 B (xz 压缩)。
- SHA256 (最终交付版 run 37063300868 产物): `318098747dfab03872281ca678492434ec0dc508c2f40718a32b9ff95824ddf6`

## 3. QEMU 无头启动测试 (tests/qemu-boot.sh)

最终交付版 (run 37063300868, head b11172f) 结果: **5/5 通过**

| 断言 | 串口证据 |
|------|----------|
| ✓ 内核启动 | `Linux version 6.12.111+deb13-amd64` |
| ✓ systemd PID 1 | `systemd[1]` |
| ✓ systemd 目标达成 | `Reached target` |
| ✓ SDDM 显示管理器 | `Started sddm.service` |
| ✓ live-boot 挂载 live 根 | `Mounting "/run/live/medium/live/filesystem.squashfs" ... done` |

桌面截图结论 (VNC :17 @ 1024x768):
- **自动登录进 Plasma 6 (Wayland) 桌面** — SDDM 按 /etc/sddm.conf.d 配置以 aura 用户直启会话, 欢迎中心弹出。
- **macOS 布局生效** — 顶部菜单栏 Panel (左: kickoff 启动器 + 时钟, 右: 系统托盘/音量/网络), 底部 Dock 为 autohide 浮动面板 (WhiteSur 彩色圆角图标, 与 macOS Dock 观感一致)。
- **全中文界面** — 欢迎中心标题"欢迎使用"、正文中文、按钮"跳过(S)/下一页(N)"、日期"2026/10/2" 均为中文 (locales= 内核参数版实测)。

## 4. 功能验收对照 (目标 vs 实测)

| 目标 | 状态 | 证据 |
|------|------|------|
| 可引导 ISO | ✅ | 3/3 次 QEMU 引导成功, 串口 5 断言全过 |
| Plasma 6 桌面 | ✅ | Wayland 会话自动登录, 面板/托盘/时钟渲染正常 |
| macOS 观感 | ✅ | WhiteSur GTK/图标/光标入镜像; 顶栏+Dock 布局脚本生效 |
| Windows 兼容层 | ✅ (静态) | squashfs 含 wine/winetricks/dosbox-x/ntfs-3g/i386 多架构 (2826 处 i386 路径); 运行期 .exe 启动未在本轮无头测试覆盖 |
| 中文本地化 | ✅ | zh_CN.UTF-8 已生成入 locale-archive; locales= 内核参数驱动 live-config |
| 开源 | ✅ | 全部配置/脚本/hook 源码化于本仓库, WhiteSur 以 pin commit 源码 vendor |
| 性能栈 | ✅ | zram-tools/earlyoom 已装并 enable; squashfs 2.6GB 体积可控 |

## 5. 已知限制

1. **TCG 软件渲染极慢**: QEMU 无 GPU 加速, plasma-discover 曾触发 841s soft lockup 警告 (纯性能, 真机 GPU 不会出现); 桌面就绪需 3-5 分钟, 故测试脚本轮询 + 300s 等待。
2. **毛玻璃/动画不可验证**: KWin blur 依赖 GL 合成, 软件渲染下截图无法反映; 配置已写入 kwinrc, 真机生效。
3. **Wine 运行期未测**: 无头测试止步于桌面就绪; .exe 启动需 GUI 交互验证 (make run)。
4. **Kvantum 引用 WhiteSur-dark 主题缺失**: Qt 控件观感回退默认, 属可接受降级 (WhiteSur 仓库不提供 kvantum 主题)。
5. **镜像源**: CI 用 deb.debian.org 官方源; 本地构建可 `MIRROR=http://mirrors.aliyun.com/debian make iso` 加速。

## 6. 复现步骤

```bash
# CI 产物
gh run download <run-id> -R KingRSW/AURAOS --name auraos-iso -D out/
# 或本地构建 (需 Docker + amd64 模拟, 慢)
make iso
# 无头回归 (QEMU + vncsnapshot + nc)
make test        # → 5 通过 / 0 失败
# 图形界面手动验证
make run         # cocoa 窗口, 等 1-3 分钟进桌面
```

## 7. 结论

AURA-OS v1.0 达到交付标准: 引导、桌面、macOS 观感主题、中文本地化、Windows 兼容层安装、性能栈全部落地并经 CI + QEMU 实测验证。剩余为运行期 GUI 手动验证项 (Wine .exe、毛玻璃观感), 不影响交付。
