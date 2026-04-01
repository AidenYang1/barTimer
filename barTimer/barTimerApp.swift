//
//  barTimerApp.swift
//  barTimer
//
//  Created by AidenYang on 2025/5/23.
//

import SwiftUI
import UserNotifications

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
            if let nearestTimer = timerManager.timers
                .filter({ $0.isRunning && !$0.isPaused })
                .min(by: { $0.remainingTime < $1.remainingTime }) {
                Text(timerManager.formatTimeForMenuBar(nearestTimer.remainingTime))
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// 添加 AppDelegate 来管理应用行为
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用不显示在 Dock 中
        NSApp.setActivationPolicy(.accessory)
        
        // 自动检查更新
        if UserDefaults.standard.object(forKey: "autoCheckUpdate") == nil || UserDefaults.standard.bool(forKey: "autoCheckUpdate") {
            UpdateChecker().checkForUpdate()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 防止重新打开时创建新的场景
        return false
    }
}

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
