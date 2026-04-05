//
//  barTimerApp.swift
//  barTimer
//
//  Created by AidenYang on 2025/5/23.
//

import SwiftUI
import UserNotifications
import Sparkle

@main
struct barTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var timerManager = TimerManager()
    @StateObject private var eventStore = EventStore()
    @State private var showPopover: Bool = false

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(isShowingPopover: $showPopover)
                .environmentObject(timerManager)
                .environmentObject(eventStore)
                .onAppear {
                    timerManager.eventStore = eventStore
                }
        } label: {
            // 根视图类型保持稳定，避免「图标 / 文本」切换时触发表层重建导致多余的状态栏项。
            HStack(spacing: 2) {
                if let nearestTimer = timerManager.timers
                    .filter({ $0.isRunning && !$0.isPaused })
                    .min(by: { $0.remainingTime < $1.remainingTime }) {
                    Text(timerManager.formatTimeForMenuBar(nearestTimer.remainingTime))
                } else {
                    Image(systemName: "timer")
                }
            }
            .onAppear {
                timerManager.eventStore = eventStore
                Self.configureHotkeysOnce {
                    setupHotkeys()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private static var didConfigureHotkeys = false
    private static func configureHotkeysOnce(_ block: () -> Void) {
        if didConfigureHotkeys { return }
        didConfigureHotkeys = true
        block()
    }

    private func setupHotkeys() {
        let hm = GlobalHotkeyManager.shared
        // 直接捕获引用类型，避免通过 SwiftUI App struct（值类型）的 @StateObject 间接访问
        let tm = timerManager
        let es = eventStore
        hm.onNewTimer = {
            QuickInputWindowController.shared.show(timerManager: tm, eventStore: es)
        }
        hm.onPauseAll = {
            let runningTimerIDs = tm.timers
                .filter { $0.isRunning && !$0.isPaused }
                .map(\.id)
            runningTimerIDs.forEach { tm.pauseTimer(id: $0) }
            tm.stopTickSound()
        }
    }
}

// - Sparkle window delegate（置前）

class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    static let shared = SparkleUserDriverDelegate()

    /// 避免 `WillHandle` 重复触发时多次 `push`，或与 `WillFinish` 不成对。
    private var isDrivingSparkleActivationPolicy = false

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        DispatchQueue.main.async {
            if handleShowingUpdate && !self.isDrivingSparkleActivationPolicy {
                self.isDrivingSparkleActivationPolicy = true
                MenuBarActivationPolicy.pushRegularAppearance()
            }
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.forEach { $0.level = .floating }
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        DispatchQueue.main.async {
            NSApp.windows.forEach { $0.level = .normal }
        }
    }

    func standardUserDriverWillFinishUpdateSession() {
        DispatchQueue.main.async {
            NSApp.windows.forEach { $0.level = .normal }
            if self.isDrivingSparkleActivationPolicy {
                self.isDrivingSparkleActivationPolicy = false
                MenuBarActivationPolicy.popRegularAppearance()
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    /// 与 `SettingsView` 中 `@AppStorage("autoCheckUpdate")` 一致；未写入时默认开启（与 SwiftUI 默认相同）。
    private static let autoCheckUpdateDefaultsKey = "autoCheckUpdate"

    /// 自动检查间隔（秒）。Sparkle 默认约 24h；菜单栏应用可缩短以便发布后更快收到提示。
    private static let sparkleUpdateCheckInterval: TimeInterval = 3600

    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: SparkleUserDriverDelegate.shared
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // LSUIElement 已在 Info.plist 中声明为附属应用，勿在此处再切换策略，以免和 SwiftUI MenuBarExtra 冲突。
        _ = updaterController   // 触发 lazy 初始化
        configureSparkleUpdaterFromUserDefaults()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AccessibilityOnboardingWindowController.shared.showIfNeeded()
        }
    }

    /// 启动时同步「自动检查更新」开关与检查间隔。此前仅在设置页 Toggle 时才写入 Sparkle，导致从未打开设置的用户不会自动检查。
    private func configureSparkleUpdaterFromUserDefaults() {
        let updater = updaterController.updater
        let autoCheck = UserDefaults.standard.object(forKey: Self.autoCheckUpdateDefaultsKey) as? Bool ?? true
        updater.automaticallyChecksForUpdates = autoCheck
        updater.updateCheckInterval = Self.sparkleUpdateCheckInterval
        if autoCheck {
            DispatchQueue.main.async {
                updater.checkForUpdatesInBackground()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }
}

// MARK: - NotificationDelegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
