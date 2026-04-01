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
    static weak var shared: AppDelegate?

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    func checkForUpdates() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "DEBUG: checkForUpdates reached"
        alert.informativeText = "shared=\(AppDelegate.shared != nil), about to call Sparkle"
        alert.runModal()
        updaterController.checkForUpdates(nil)
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
