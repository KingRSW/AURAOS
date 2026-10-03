// AURA-OS Plasma 6 布局脚本 (首启由 autostart 经 qdbus evaluateScript 执行)
// 目标: macOS 菜单栏观感 —— 顶栏全宽 (启动器居左 / 时钟居中 / 托盘居右),
//       底部 Dock 躲避窗口而非粗暴隐藏, 右端回收站。
// API 依据 develop.kde.org/docs/plasma/scripting/api:
//   new Panel / panels() / panel.location / panel.hiding() / addWidget / remove()
// 每步 try/catch, 失败不影响进入默认桌面。

function safe(fn) { try { fn(); } catch (e) { console.error("aura-layout:", e); } }

// 移除发行版默认面板
safe(function () {
    var ps = panels();
    for (var i = 0; i < ps.length; i++) {
        ps[i].remove();
    }
});

// ===== 顶部菜单栏 Panel (mac menu bar) =====
safe(function () {
    var top = new Panel();
    top.location = "top";
    top.height = 30;
    top.alignment = "left";       // 全宽: lengthMode fill + alignment left
    top.lengthMode = "fill";
    top.hiding = "none";

    // 左: 系统启动器 (Plasma logo, WhiteSur -p 替换后 start-here-kde 即 Plasma logo)
    safe(function () {
        var kickoff = top.addWidget("org.kde.plasma.kickoff");
        kickoff.currentConfigGroup = ["General"];
        kickoff.writeConfig("icon", "start-here-kde");
    });
    // 居中时钟: 两侧等宽 spacer 撑开
    safe(function () {
        var s1 = top.addWidget("org.kde.plasma.panelspacer");
        s1.currentConfigGroup = ["General"];
        s1.writeConfig("expanding", true);
    });
    safe(function () {
        var clock = top.addWidget("org.kde.plasma.digitalclock");
        clock.currentConfigGroup = ["General"];
        clock.writeConfig("showDate", false);   // mac 菜单栏只显示星期+时间
        clock.writeConfig("showSeconds", false);
    });
    safe(function () {
        var s2 = top.addWidget("org.kde.plasma.panelspacer");
        s2.currentConfigGroup = ["General"];
        s2.writeConfig("expanding", true);
    });

    // 右: 系统托盘
    safe(function () { top.addWidget("org.kde.plasma.systemtray"); });
});

// ===== 底部 Dock (dodgewindows: 仅被全屏/最大化窗口遮挡时让位) =====
safe(function () {
    var dock = new Panel();
    dock.location = "bottom";
    dock.height = 64;
    dock.alignment = "center";
    dock.lengthMode = "fit";
    dock.hiding = "dodgewindows";

    safe(function () {
        var tasks = dock.addWidget("org.kde.plasma.icontasks");
        tasks.currentConfigGroup = ["General"];
        tasks.writeConfig("maxIconSize", 56);
        tasks.writeConfig("iconSpacing", "medium");
    });
    safe(function () { dock.addWidget("org.kde.plasma.launchers"); });
    // 右端分隔 + 回收站 (mac Dock 特征)
    safe(function () {
        var sep = dock.addWidget("org.kde.plasma.panelspacer");
        sep.currentConfigGroup = ["General"];
        sep.writeConfig("expanding", false);
    });
    safe(function () { dock.addWidget("org.kde.plasma.trash"); });
});
