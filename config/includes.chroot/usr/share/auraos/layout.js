// AURA-OS Plasma 6 布局脚本 (首启由 autostart 经 qdbus evaluateScript 执行)
// 目标: 顶部菜单栏 Panel + 底部自动隐藏 Dock (macOS 观感)。
// API 依据 develop.kde.org/docs/plasma/scripting/api:
//   new Panel / panels() / panel.location / panel.hiding("autohide") / addWidget / remove()
// 每步 try/catch, 失败不影响进入默认桌面。

function safe(fn) { try { fn(); } catch (e) { console.error("aura-layout:", e); } }

// 移除发行版默认面板
safe(function () {
    var ps = panels();
    for (var i = 0; i < ps.length; i++) {
        ps[i].remove();
    }
});

// ===== 顶部菜单栏 Panel =====
safe(function () {
    var top = new Panel();
    top.location = "top";
    top.height = 34;
    top.alignment = "center";
    top.hiding = "none";
    safe(function () { top.addWidget("org.kde.plasma.kickoff"); });
    safe(function () { top.addWidget("org.kde.plasma.digitalclock"); });
    safe(function () { top.addWidget("org.kde.plasma.systemtray"); });
});

// ===== 底部 Dock Panel (自动隐藏) =====
safe(function () {
    var dock = new Panel();
    dock.location = "bottom";
    dock.height = 60;
    dock.alignment = "center";
    dock.hiding = "autohide";
    safe(function () { dock.addWidget("org.kde.plasma.icontasks"); });
    safe(function () { dock.addWidget("org.kde.plasma.launchers"); });
});
