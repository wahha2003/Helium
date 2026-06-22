# Helium Widget 自启动 Patch

> 改动量：**新增 3 个文件 + 修改 Makefile 2 处**。
> 不动 Helium 任何现有代码。

---

## 一、理解现有 Helium 的 spawn 流程

Helium 目录结构（关键部分）：

```
Helium/
├── Makefile
├── ent.plist                    ← 主 App + HUD 共用 entitlements
├── src/
│   ├── MainApp/                 ← 主 App：设置界面，调用 spawnHUD()
│   └── HUDApp/                  ← HUD 进程：全局 UIWindow
└── layout/
    └── Applications/
        └── Helium.app/
```

主 App 启动时调用（位于 `src/MainApp/` 某处）：

```objc
// Helium 已有的 spawn 逻辑（伪代码，实际在 AppDelegate 或 HUDHelper）
pid_t pid = 0;
const char *hudPath = [NSBundle.mainBundle.bundlePath
    stringByAppendingPathComponent:@"heliumhud"].UTF8String;
const char *args[] = { hudPath, NULL };
posix_spawn(&pid, hudPath, NULL, NULL, (char *const *)args, environ);
// 不 waitpid，让 HUD 独立运行
```

**Widget 要做的事完全相同**——在 `getTimeline` 里调同一个 `posix_spawn`，路径从 Widget bundle 反推即可。

---

## 二、新增文件

### 文件 1：`src/HeliumWidget/HeliumWidget.swift`

```swift
import WidgetKit
import SwiftUI
import Darwin   // posix_spawn

// ──────────────────────────────────────────────
// MARK: - HUD Spawn（核心逻辑）
// ──────────────────────────────────────────────

private func spawnHUDIfNeeded() {
    // Widget Extension 路径：
    //   .../Helium.app/PlugIns/HeliumWidget.appex/
    // HUD 二进制路径：
    //   .../Helium.app/heliumhud
    let widgetBundlePath = Bundle.main.bundlePath          // PlugIns/HeliumWidget.appex
    let appBundlePath    = widgetBundlePath                // 往上两级
        .deletingLastPathComponent()                       // PlugIns/
        .deletingLastPathComponent()                       // Helium.app/
    let hudPath = appBundlePath.appendingPathComponent("heliumhud")
    
    // 如果 HUD 已在运行，跳过（通过 pid file 判断）
    let pidFile = "/var/mobile/Library/Helium/hud.pid"
    if let pidStr = try? String(contentsOfFile: pidFile, encoding: .utf8),
       let pid = pid_t(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)),
       kill(pid, 0) == 0 {
        return   // 已在运行
    }
    
    guard FileManager.default.fileExists(atPath: hudPath) else { return }
    
    var pid: pid_t = 0
    let cPath = hudPath.withCString { strdup($0) }
    defer { free(cPath) }
    
    // 与主 App 完全相同的调用方式
    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)
    let ret = posix_spawn(&pid, cPath, &fileActions, nil,
                          [cPath, nil].map { $0 },
                          nil)
    posix_spawn_file_actions_destroy(&fileActions)
    
    if ret == 0 {
        // 写 pid file 供下次检查
        try? "\(pid)".write(toFile: pidFile, atomically: true, encoding: .utf8)
    }
    // 不 waitpid —— 让 HUD 进程独立存活
}

// String 路径扩展，避免 URL 转换
private extension String {
    func deletingLastPathComponent() -> String {
        (self as NSString).deletingLastPathComponent
    }
    func appendingPathComponent(_ str: String) -> String {
        (self as NSString).appendingPathComponent(str)
    }
}

// ──────────────────────────────────────────────
// MARK: - Timeline Provider
// ──────────────────────────────────────────────

struct HeliumAutoStartProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> HeliumEntry {
        HeliumEntry(date: Date())
    }
    
    func getSnapshot(in context: Context,
                     completion: @escaping (HeliumEntry) -> Void) {
        completion(HeliumEntry(date: Date()))
    }
    
    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<HeliumEntry>) -> Void) {
        // ★ 系统重启后刷新 Widget 时，这里会被调用
        //   → 触发 HUD spawn，效果与手动打开 App 完全一致
        spawnHUDIfNeeded()
        
        let entry = HeliumEntry(date: Date())
        
        // 每 15 分钟刷新一次（iOS 会按电量/使用习惯实际调度）
        // 目的：保证 HUD 意外退出后能自愈
        let nextRefresh = Calendar.current.date(byAdding: .minute,
                                                value: 15, to: Date())!
        let timeline = Timeline(entries: [entry],
                                policy: .after(nextRefresh))
        completion(timeline)
    }
}

// ──────────────────────────────────────────────
// MARK: - Widget Entry & View
// ──────────────────────────────────────────────

struct HeliumEntry: TimelineEntry {
    let date: Date
}

struct HeliumWidgetView: View {
    var body: some View {
        // 极简外观：只显示一个小图标，不影响桌面美观
        Image(systemName: "waveform")
            .font(.system(size: 20))
            .foregroundColor(.white)
            .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

// ──────────────────────────────────────────────
// MARK: - Widget 定义
// ──────────────────────────────────────────────

@main
struct HeliumWidget: Widget {
    let kind = "HeliumWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeliumAutoStartProvider()) { entry in
            HeliumWidgetView()
        }
        .configurationDisplayName("Helium")
        .description("自动保持 Helium HUD 运行")
        // 只支持最小尺寸，桌面占用最小
        .supportedFamilies([.systemSmall])
    }
}
```

---

### 文件 2：`widget-ent.plist`（Widget Extension 专用 entitlements）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Widget Extension 需要独立的 no-sandbox 才能 posix_spawn -->
    <key>platform-application</key>
    <true/>
    <key>com.apple.private.security.no-sandbox</key>
    <true/>
    <key>com.apple.private.security.no-container</key>
    <true/>

    <!-- App Group：与主 App 共享偏好设置（可选，如需读 Helium 配置） -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.leminlimez.helium</string>
    </array>
</dict>
</plist>
```

> **注意**：这个 `widget-ent.plist` 通过 `ldid -S` 签入 Widget Extension 二进制，
> 与现有 `ent.plist`（给主 App 和 HUD 用的）**完全独立，互不影响**。

---

### 文件 3：`src/HeliumWidget/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>HeliumWidget</string>
    <key>CFBundleIdentifier</key>
    <string>com.leminlimez.helium.widget</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

---

## 三、修改 Makefile（只加 2 段）

原始 Helium Makefile 大致如下（只展示需要改动的位置）：

```makefile
TARGET := iphone:clang:15.0:14.0
ARCHS  := arm64 arm64e

include $(THEOS)/makefiles/common.mk

# ── 已有：主 App ──
APPLICATION_NAME = Helium
# ...（原有配置不动）

# ── 已有：HUD 工具 ──
TOOL_NAME = heliumhud
# ...（原有配置不动）

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk
```

**在 `include $(THEOS_MAKE_PATH)/tool.mk` 之后添加**：

```makefile
# ── 新增：Widget Extension ──────────────────────
BUNDLE_NAME = HeliumWidget

HeliumWidget_FILES          = src/HeliumWidget/HeliumWidget.swift
HeliumWidget_INSTALL_PATH   = $(THEOS_PACKAGE_STAGING_DIR)/Applications/Helium.app/PlugIns
HeliumWidget_CODESIGN_FLAGS = -Swidget-ent.plist
HeliumWidget_SWIFTFLAGS     = -target arm64-apple-ios14.0
HeliumWidget_FRAMEWORKS     = WidgetKit SwiftUI

include $(THEOS_MAKE_PATH)/bundle.mk

# 构建后把 Widget Extension 放进主 App bundle 的 PlugIns 目录
after-stage::
	mkdir -p $(THEOS_PACKAGE_STAGING_DIR)/Applications/Helium.app/PlugIns
	cp -r $(THEOS_PACKAGE_STAGING_DIR)/Applications/Helium.app/PlugIns/HeliumWidget.bundle \
	      $(THEOS_PACKAGE_STAGING_DIR)/Applications/Helium.app/PlugIns/HeliumWidget.appex
```

---

## 四、用户侧：如何启用

1. 编译安装后，在 iOS 桌面长按空白处 → 添加小组件 → 找到 **Helium** → 添加最小尺寸。
2. 重启设备后，iOS 会在几分钟内刷新 Widget，`getTimeline` 被调用，HUD 自动 spawn。
3. 无需打开 Helium App。

---

## 五、运作流程图

```
设备重启
  └─► SpringBoard 启动
        └─► widgetlayoutd 刷新所有 Widget（约 1~5 分钟内）
              └─► HeliumWidget.appex 进程被唤醒
                    └─► getTimeline() 调用
                          └─► spawnHUDIfNeeded()
                                ├─ 检查 pid file → HUD 未运行
                                └─► posix_spawn("Helium.app/heliumhud")
                                      └─► HUD 进程启动，全局 UIWindow 显示 ✅

后续（每 15 分钟）
  └─► Widget 刷新 → spawnHUDIfNeeded() → pid file 检查 → HUD 在运行 → 跳过
```

---

## 六、常见问题

**Q: Widget Extension 能 posix_spawn 吗？**
A: 正常沙盒下不能。但 TrollStore 安装的 App，Extension 也可以通过 `ldid -S widget-ent.plist` 注入 `no-sandbox` 后获得能力。

**Q: HUD 路径怎么确定？**
A: Widget Extension bundle 路径是 `Helium.app/PlugIns/HeliumWidget.appex/`，往上两层就是 `Helium.app/`，再拼接 `heliumhud`（与 Helium 现有 Makefile 中 `TOOL_NAME` 一致）。

**Q: Widget 刷新太慢怎么办？**
A: iOS 不保证精确时间，重启后首次刷新一般 1~5 分钟。如果要秒级恢复，可以同时保留 LaunchDaemon 方案作为兜底，两者互不冲突。

**Q: 会影响 Helium 现有功能吗？**
A: 完全不影响。没有修改任何现有文件，只是新增了 Widget Extension 并在打包阶段把它放进 App bundle。