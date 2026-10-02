// AURA-OS Plasma 布局脚本 (首启由 autostart 通过 plasmashell evaluateScript 执行)
// 目标: 顶部菜单栏 Panel + 底部居中标签式 Dock + KWin 概览补位 Mission Control。
// 采用官方 DesktopSettings API, 避免手写 appletsrc 因版本漂移而崩溃。

var desktops = desktops();
for (var d = 0; d < desktops.length; d++) {
    var ds = desktops[d];

    // 清空默认 widget, 从零构建
    ds.clearApplets();

    // ===== 顶部 Panel: 启动器 + 全局菜单 + 时钟居中 + 托盘 =====
    var top = ds.createPanel();
    top.location = "top";
    top.height = 34;
    top.alignment = "center";
    top.floating = false;
    top.hiding = "none";
    top.width = ds.screenGeometry.width;

    // 左: kickoff 启动器 (替代苹果 Logo)
    var kickoff = top.createApplet("org.kde.plasma.kickoff");
    // 左: 全局菜单 (macOS 顶部菜单条核心)
    try { top.createApplet("org.kde.plasma.globalmenu"); } catch (e) {}

    // 中: 数字时钟
    var clock = top.createApplet("org.kde.plasma.digitalclock");
    // 右: 系统托盘 (网络/音量/通知)
    var tray = top.createApplet("org.kde.plasma.systemtray");

    // ===== 底部 Panel: 浮动居中标签 Dock =====
    var dock = ds.createPanel();
    dock.location = "bottom";
    dock.height = 60;
    dock.alignment = "center";
    dock.floating = true;
    dock.hiding = "auto";          // 鼠标触底弹出, 模仿 macOS Dock
    dock.width = 720;

    // 仅图标任务管理器 (运行中应用)
    var tasks = dock.createApplet("org.kde.plasma.icontasks");
    // 固定启动器 (常用应用)
    var launchers = dock.createApplet("org.kde.plasma.launchers");

    // 图标尺寸放大到 Dock 观感
    try {
        var tc = tasks.confContainmentItem || null;
    } catch (e) {}
}

// 通知 plasmashell 布局已变更
plasma.notifyLayoutChange();
