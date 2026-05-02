---

## 整体架构

```
YourApp.app/
├── YourApp          (主 App 可执行文件)
├── YourDaemon       (后台服务可执行文件，独立进程)
└── PlugIns/
    └── YourWidget.appex/
        └── YourWidget   (Widget Extension，系统定期唤醒)

共享容器 (App Group):
└── group.com.yourcompany.yourapp/
    ├── daemon.pid        (守护进程 PID 文件)
    └── daemon.socket     (UNIX Domain Socket，IPC 通信)
```

**调用链**：`widgetd` 开机唤醒 → Widget Extension `getTimeline` → 检测 daemon 是否存活 → `posix_spawn` 启动 daemon → daemon 持续运行提供服务

---

## 第一步：Entitlements 配置

**Widget Extension 的 entitlements**（最关键）：

```xml
<!-- YourWidget.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 与主 App 共享数据容器，核心依赖 -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.yourapp</string>
    </array>

    <!-- 突破沙盒，允许访问 App Bundle 外的路径和执行二进制 -->
    <key>com.apple.private.security.no-sandbox</key>
    <true/>

    <!-- 允许以 platform 身份运行，提升进程权限 -->
    <key>platform-application</key>
    <true/>

    <!-- 允许访问任意文件路径 -->
    <key>com.apple.private.security.storage.AppDataContainers</key>
    <true/>
</dict>
</plist>
```

**主 App 的 entitlements**（对齐 App Group 即可）：

```xml
<!-- YourApp.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.yourapp</string>
    </array>
    <key>com.apple.private.security.no-sandbox</key>
    <true/>
    <key>platform-application</key>
    <true/>
</dict>
</plist>
```

> 用 `ldid` 给 daemon 可执行文件打上相同的 entitlements，TrollStore 安装时会保留它们。

---

## 第二步：共享工具层（App Group 通信）

新建一个两端共用的 Swift 文件（或 Swift Package），放在 shared target：

```swift
// SharedConfig.swift - Widget Extension 和主 App 共享

import Foundation

public struct DaemonConfig {
    /// App Group 容器路径
    public static let appGroupID = "group.com.yourcompany.yourapp"
    
    public static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
    }
    
    /// daemon 进程的 PID 文件路径
    public static var pidFileURL: URL {
        containerURL.appendingPathComponent("daemon.pid")
    }
    
    /// daemon 健康检查的 Darwin Notification 名称
    public static let daemonAliveNotification = "com.yourcompany.yourapp.daemon.alive"
    public static let daemonStartNotification  = "com.yourcompany.yourapp.daemon.start"
    public static let daemonStopNotification   = "com.yourcompany.yourapp.daemon.stop"
    
    /// daemon 可执行文件在 App Bundle 中的相对路径
    public static let daemonExecutableName = "YourDaemon"
}

// MARK: - 进程存活检测

public struct DaemonChecker {
    
    /// 通过 PID 文件检测 daemon 是否存活
    public static func isDaemonRunning() -> Bool {
        guard let pidData = try? Data(contentsOf: DaemonConfig.pidFileURL),
              let pidString = String(data: pidData, encoding: .utf8),
              let pid = pid_t(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        // kill(pid, 0) 不发信号，只检测进程是否存在
        return kill(pid, 0) == 0
    }
    
    /// 获取当前 daemon 的 PID
    public static func daemonPID() -> pid_t? {
        guard let pidData = try? Data(contentsOf: DaemonConfig.pidFileURL),
              let pidString = String(data: pidData, encoding: .utf8),
              let pid = pid_t(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return pid
    }
    
    /// 找到 App Bundle 中 daemon 可执行文件的路径
    /// Widget Extension bundle 在 <App.app>/PlugIns/<Widget>.appex
    /// 向上两级即为 App.app 目录
    public static func daemonExecutablePath(from widgetBundle: Bundle) -> String {
        let appBundleURL = widgetBundle.bundleURL
            .deletingLastPathComponent()  // PlugIns/
            .deletingLastPathComponent()  // App.app/
        return appBundleURL
            .appendingPathComponent(DaemonConfig.daemonExecutableName)
            .path
    }
}
```

---

## 第三步：Widget Extension（核心启动逻辑）

```swift
// YourWidget.swift

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider（核心）

struct LaunchDaemonProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> DaemonEntry {
        DaemonEntry(date: Date(), isRunning: false)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DaemonEntry) -> Void) {
        let entry = DaemonEntry(date: Date(), isRunning: DaemonChecker.isDaemonRunning())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DaemonEntry>) -> Void) {
        // 1. 检测 daemon 是否存活
        let isRunning = DaemonChecker.isDaemonRunning()
        
        // 2. 若未运行，尝试启动
        if !isRunning {
            launchDaemonIfNeeded()
        }
        
        // 3. 构造 Timeline entry
        let now = Date()
        let entry = DaemonEntry(date: now, isRunning: DaemonChecker.isDaemonRunning())
        
        // 4. 设置下次刷新时间
        // 注意：Apple 对刷新频率有配额限制（每天约 40~70 次）
        // 实际触发间隔由系统决定，这里设置的是"最早"刷新时间
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        
        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextRefresh)  // 15 分钟后请求新 timeline
        )
        
        completion(timeline)
    }
    
    // MARK: - 启动 Daemon
    
    private func launchDaemonIfNeeded() {
        let executablePath = DaemonChecker.daemonExecutablePath(from: Bundle.main)
        
        // 验证可执行文件存在
        guard FileManager.default.fileExists(atPath: executablePath) else {
            print("[Widget] Daemon executable not found at: \(executablePath)")
            return
        }
        
        // 确保有执行权限
        ensureExecutable(path: executablePath)
        
        // posix_spawn 启动独立进程
        spawnDaemon(executablePath: executablePath)
    }
    
    private func ensureExecutable(path: String) {
        var attrs = stat()
        if stat(path, &attrs) == 0 {
            let currentMode = attrs.st_mode
            let executableMode = currentMode | S_IXUSR | S_IXGRP | S_IXOTH
            if currentMode != executableMode {
                chmod(path, executableMode)
            }
        }
    }
    
    private func spawnDaemon(executablePath: String) {
        var pid: pid_t = 0
        
        // 构造 argv（C 风格字符串数组）
        let args: [String] = [executablePath]
        let cArgs = args.map { $0.withCString(strdup) }
        defer { cArgs.forEach { free($0) } }
        var argv = cArgs + [nil]
        
        // 构造环境变量
        let envVars = [
            "APP_GROUP_ID=\(DaemonConfig.appGroupID)",
            "HOME=/var/mobile",
        ]
        let cEnv = envVars.map { $0.withCString(strdup) }
        defer { cEnv.forEach { free($0) } }
        var envp = cEnv + [nil]
        
        // 配置 spawn attributes
        var spawnAttr: posix_spawnattr_t?
        posix_spawnattr_init(&spawnAttr)
        defer { posix_spawnattr_destroy(&spawnAttr) }
        
        // POSIX_SPAWN_SETSID: 在新 session 中运行，脱离当前进程组
        posix_spawnattr_setflags(&spawnAttr, Int16(POSIX_SPAWN_SETSID))
        
        // 配置文件操作（让 daemon 关闭继承的文件描述符）
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        
        // 重定向 stdout/stderr 到日志文件
        let logPath = DaemonConfig.containerURL
            .appendingPathComponent("daemon.log").path
        posix_spawn_file_actions_addopen(
            &fileActions, STDOUT_FILENO,
            logPath, O_WRONLY | O_CREAT | O_APPEND, 0o644
        )
        posix_spawn_file_actions_adddup2(&fileActions, STDOUT_FILENO, STDERR_FILENO)
        
        let result = posix_spawn(
            &pid,
            executablePath,
            &fileActions,
            &spawnAttr,
            &argv,
            &envp
        )
        
        if result == 0 {
            print("[Widget] Daemon spawned with PID: \(pid)")
            // 写入 PID 文件，供后续检测
            writePID(pid)
        } else {
            print("[Widget] posix_spawn failed: \(String(cString: strerror(result)))")
        }
    }
    
    private func writePID(_ pid: pid_t) {
        let pidString = "\(pid)\n"
        try? pidString.data(using: .utf8)?
            .write(to: DaemonConfig.pidFileURL, options: .atomic)
    }
}

// MARK: - Timeline Entry

struct DaemonEntry: TimelineEntry {
    let date: Date
    let isRunning: Bool
}

// MARK: - Widget View（UI 尽量简单，用户需要把它放到主屏幕）

struct LaunchDaemonWidgetView: View {
    let entry: DaemonEntry
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: entry.isRunning ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundColor(entry.isRunning ? .green : .orange)
                .font(.title2)
            Text(entry.isRunning ? "服务运行中" : "服务未启动")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget 声明

struct LaunchDaemonWidget: Widget {
    let kind = "LaunchDaemonWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LaunchDaemonProvider()) { entry in
            LaunchDaemonWidgetView(entry: entry)
        }
        .configurationDisplayName("后台服务")
        .description("保持后台服务运行")
        .supportedFamilies([.systemSmall])
    }
}
```

---

## 第四步：Daemon 可执行文件（后台服务进程）

这是一个独立的命令行可执行文件，编译后打包进 App Bundle。

```swift
// main.swift (YourDaemon target)

import Foundation

// MARK: - 自我守护（double fork 模式，脱离控制终端）

func daemonize() {
    // 写入 PID 文件
    let appGroupID = ProcessInfo.processInfo.environment["APP_GROUP_ID"]
        ?? "group.com.yourcompany.yourapp"
    
    if let containerURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
        let pidURL = containerURL.appendingPathComponent("daemon.pid")
        let pid = ProcessInfo.processInfo.processIdentifier
        try? "\(pid)\n".data(using: .utf8)?.write(to: pidURL, options: .atomic)
    }
}

// MARK: - Darwin Notification 响应

func setupNotificationHandlers() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    
    // 监听停止信号
    CFNotificationCenterAddObserver(
        center, nil,
        { _, _, name, _, _ in
            if let name = name?.rawValue as? String,
               name == DaemonConfig.daemonStopNotification {
                exit(0)
            }
        },
        DaemonConfig.daemonStopNotification as CFString,
        nil, .deliverImmediately
    )
}

// MARK: - 信号处理

func setupSignalHandlers() {
    signal(SIGTERM) { _ in
        // 清理工作
        cleanupAndExit()
    }
    signal(SIGINT) { _ in
        cleanupAndExit()
    }
    // 忽略 SIGHUP，防止终端断开时退出
    signal(SIGHUP, SIG_IGN)
}

func cleanupAndExit() -> Never {
    // 删除 PID 文件
    try? FileManager.default.removeItem(at: DaemonConfig.pidFileURL)
    exit(0)
}

// MARK: - 心跳：定期通知 Widget 自己还活着（可选）

func startHeartbeat() {
    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            DaemonConfig.daemonAliveNotification as CFString as CFNotificationName,
            nil, nil, true
        )
    }
}

// MARK: - 你的实际服务逻辑

func startService() {
    // 在这里实现你的核心功能
    // 例如：监听电话事件、音频录制等
    print("[Daemon] Service started, PID: \(ProcessInfo.processInfo.processIdentifier)")
    
    // 示例：使用 CTCallCenter 监听通话（需要相应 entitlement）
    // let callCenter = CTCallCenter()
    // callCenter.callEventHandler = { call in ... }
    
    // 保持 RunLoop 运行
    RunLoop.main.run()
}

// MARK: - 入口

daemonize()
setupSignalHandlers()
setupNotificationHandlers()
startHeartbeat()
startService()
```

---

## 第五步：主 App 与 Daemon 的通信

```swift
// DaemonManager.swift（主 App 中使用）

import Foundation

class DaemonManager {
    static let shared = DaemonManager()
    
    // MARK: - 检测状态
    
    var isDaemonRunning: Bool {
        DaemonChecker.isDaemonRunning()
    }
    
    // MARK: - 从主 App 手动启动 Daemon（备用方案）
    
    func startDaemon() {
        guard !isDaemonRunning else { return }
        
        let executablePath = Bundle.main
            .url(forResource: DaemonConfig.daemonExecutableName, withExtension: nil)!
            .path
        
        // 确保有执行权限
        chmod(executablePath, 0o755)
        
        var pid: pid_t = 0
        let args = [executablePath]
        let cArgs = args.map { $0.withCString(strdup) }
        defer { cArgs.forEach { free($0) } }
        var argv = cArgs + [nil]
        
        posix_spawn(&pid, executablePath, nil, nil, &argv, environ)
        print("[App] Daemon started with PID: \(pid)")
    }
    
    // MARK: - 停止 Daemon
    
    func stopDaemon() {
        // 方式一：Darwin Notification
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            DaemonConfig.daemonStopNotification as CFString as CFNotificationName,
            nil, nil, true
        )
        
        // 方式二：直接 kill（更可靠）
        if let pid = DaemonChecker.daemonPID() {
            kill(pid, SIGTERM)
        }
        
        // 清理 PID 文件
        try? FileManager.default.removeItem(at: DaemonConfig.pidFileURL)
    }
    
    // MARK: - 通过 UserDefaults (App Group) 传递配置给 Daemon
    
    func updateConfig(key: String, value: Any) {
        let defaults = UserDefaults(suiteName: DaemonConfig.appGroupID)
        defaults?.set(value, forKey: key)
        defaults?.synchronize()
        
        // 通知 Daemon 读取新配置
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            "com.yourcompany.yourapp.daemon.configChanged" as CFString as CFNotificationName,
            nil, nil, true
        )
    }
}
```

---

## 第六步：WidgetKit 强制刷新（从主 App 触发）

```swift
// 在主 App 中，当用户更改配置后，主动请求 Widget 刷新
// 这会触发 getTimeline 被调用，进而检测并重启 daemon

import WidgetKit

func requestWidgetRefresh() {
    WidgetCenter.shared.reloadAllTimelines()
    // 或者只刷新特定 widget：
    // WidgetCenter.shared.reloadTimelines(ofKind: "LaunchDaemonWidget")
}
```

---

## 第七步：打包与签名（用 ldid）

```bash
# 给 daemon 可执行文件打 entitlements
ldid -SDaemon.entitlements YourApp.app/YourDaemon

# Daemon.entitlements 内容：
# <?xml version="1.0" encoding="UTF-8"?>
# <plist version="1.0"><dict>
#   <key>platform-application</key><true/>
#   <key>com.apple.private.security.no-sandbox</key><true/>
#   <key>com.apple.security.application-groups</key>
#   <array><string>group.com.yourcompany.yourapp</string></array>
# </dict></plist>

# 给 widget extension 打 entitlements  
ldid -SWidget.entitlements YourApp.app/PlugIns/YourWidget.appex/YourWidget

# 然后打包成 .ipa / .tipa
```

---

## 关键注意事项

**关于刷新频率**：Apple 的 Widget 刷新配额约为每天 40~70 次，系统不保证按你设置的时间精确刷新。如果 daemon crash 了，最坏情况下要等到下次刷新（最多几小时）才会被重启。可以考虑同时注册 `BGAppRefreshTask` 作为补充保活手段。

**关于 Widget 必须放主屏幕**：这是这个方案最大的限制。Widget 没有被用户添加到主屏幕时，系统不会调度它。建议在首次启动时引导用户添加，并通过主 App 的 `WidgetCenter.shared.getCurrentConfigurations` 检测是否已添加。

**关于 posix_spawn 与沙盒**：没有 `no-sandbox` entitlement 时，Widget Extension 的沙盒会阻止 `posix_spawn` 执行 App Bundle 外的二进制，并且对容器路径的访问也会被限制。TrollStore 的任意 entitlement 能力是这个方案成立的前提。

**关于 daemon 的稳定性**：daemon 进程被系统 OOM Killer 杀掉是常见情况。可以在 daemon 里申请 `os_proc_available_memory()` 监控，或者在 entitlements 里加 `com.apple.runningboard.assertions.allowbackgroundtask` 来申请后台运行断言，降低被杀概率。