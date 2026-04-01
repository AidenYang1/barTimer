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

class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // 监听 Sparkle 弹窗出现，确保窗口可见
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    func checkForUpdates() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        updaterController.updater.checkForUpdates()
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
