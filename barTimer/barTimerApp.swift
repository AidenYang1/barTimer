//
//  barTimerApp.swift
//  barTimer
//
//  Created by 杨翼臣 on 2025/5/23.
//

import SwiftUI
import UserNotifications

@main
struct barTimerApp: App {
    // 添加状态管理
    @State private var showPopover: Bool = false
    
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        // 将 WindowGroup 改为 MenuBarExtra
        MenuBarExtra("计时器", systemImage: "timer") {
            ContentView(isShowingPopover: $showPopover)
        }
        .menuBarExtraStyle(.window) // 使用窗口样式显示内容
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
