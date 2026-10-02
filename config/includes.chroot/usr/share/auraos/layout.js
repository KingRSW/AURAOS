// AURA-OS Plasma 布局脚本 (首启由 autostart 经 qdbus evaluateScript 执行)
// 目标: 顶部菜单栏 Panel + 底部居中标签 Dock。
// Plasma 6 脚本 API 存在版本漂移, 故每步 try/catch, 失败不影响进入默认桌面。

function safe(fn) { try { fn(); } catch (e) { console.error("aura-layout:", e); } }

var ds = desktops();
for (var i = 0; i < ds.length; i++) {
    var d = ds[i];

    safe(function () { d.clearApplets(); });

    // ===== 顶部 Panel =====
    safe(function () {
        var top = d.createPanel();
        top.location = "top";
        top.height = 34;
        top.alignment = "center";
        top.floating = false;
        safe(function () { top.createApplet("org.kde.plasma.kickoff"); });
        safe(function () { top.createApplet("org.kde.plasma.globalmenu"); });
        safe(function () { top.createApplet("org.kde.plasma.digitalclock"); });
        safe(function () { top.createApplet("org.kde.plasma.systemtray"); });
    });

    // ===== 底部 Dock Panel =====
    safe(function () {
        var dock = d.createPanel();
        dock.location = "bottom";
        dock.height = 60;
        dock.alignment = "center";
        dock.floating = true;
        dock.hiding = "auto";
        safe(function () { dock.createApplet("org.kde.plasma.icontasks"); });
        safe(function () { dock.createApplet("org.kde.plasma.launchers"); });
    });
}
