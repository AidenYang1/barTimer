import Foundation
import UserNotifications
import AudioToolbox
import SwiftUI
import AppKit

// 定义单个计时器的数据结构
struct TimerData: Identifiable {
    let id = UUID()
    var remainingTime: TimeInterval
    var originalDuration: TimeInterval
    var isRunning: Bool
    var isPaused: Bool
}

class TimerManager: ObservableObject {
    @Published var timers: [TimerData] = []
    @Published var showOverlay = false
    private var timer: Timer?
    private var overlayWindow: NSWindow?
    private var overlayHostingView: NSHostingView<OverlayView>?
    
    init() {
        // 初始化时请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
                return
            }
            if granted {
                print("通知权限请求成功")
            } else {
                print("通知权限被拒绝")
            }
        }
    }
    
    // 解析输入的时间字符串
    func parseTimeInput(_ input: String) -> TimeInterval? {
        // 移除所有空格
        let cleanInput = input.replacingOccurrences(of: " ", with: "")
        var totalSeconds: TimeInterval = 0
        
        // 匹配小时和分钟的正则表达式
        let patterns = [
            "([0-9]+)小时([0-9]+)分": (3600.0, 60.0),    // 2小时30分
            "([0-9]+)小时": (3600.0, 0.0),               // 2小时
            "([0-9]+)分钟": (60.0, 0.0),                 // 30分钟
            "([0-9]+)分": (60.0, 0.0),                   // 30分
            "([0-9]+)秒": (1.0, 0.0)                     // 30秒
        ]
        
        for (pattern, multipliers) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(cleanInput.startIndex..., in: cleanInput)
                if let match = regex.firstMatch(in: cleanInput, range: range) {
                    let nsString = cleanInput as NSString
                    let firstNumber = Double(nsString.substring(with: match.range(at: 1))) ?? 0
                    let secondNumber = match.numberOfRanges > 2 ? 
                        (Double(nsString.substring(with: match.range(at: 2))) ?? 0) : 0
                    
                    totalSeconds += firstNumber * multipliers.0 + secondNumber * multipliers.1
                    return totalSeconds
                }
            }
        }
        
        // 尝试直接解析数字（假设为分钟）
        if let minutes = Double(cleanInput) {
            return minutes * 60
        }
        
        return nil
    }
    
    // 添加新计时器
    func addTimer(duration: TimeInterval) {
        let newTimer = TimerData(
            remainingTime: duration,
            originalDuration: duration,
            isRunning: true,
            isPaused: false
        )
        timers.append(newTimer)
        sortTimers()
        startGlobalTimer()
    }
    
    // 对计时器进行排序
    private func sortTimers() {
        timers.sort { $0.remainingTime < $1.remainingTime }
    }
    
    // 启动全局计时器
    private func startGlobalTimer() {
        // 如果计时器已经在运行，就不需要再次启动
        if timer != nil { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            var needsSort = false
            for index in timers.indices {
                if timers[index].isRunning && !timers[index].isPaused {
                    timers[index].remainingTime -= 1
                    
                    // 检查是否完成
                    if timers[index].remainingTime <= 0 {
                        timers[index].isRunning = false
                        self.notifyTimerComplete()
                        needsSort = true
                    }
                }
            }
            
            // 移除已完成的计时器
            timers.removeAll { $0.remainingTime <= 0 }
            
            // 如果需要，重新排序
            if needsSort {
                sortTimers()
            }
            
            // 如果没有活动的计时器，停止全局计时器
            if !timers.contains(where: { $0.isRunning && !$0.isPaused }) {
                stopGlobalTimer()
            }
        }
    }
    
    // 停止全局计时器
    private func stopGlobalTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // 暂停特定计时器
    func pauseTimer(id: UUID) {
        if let index = timers.firstIndex(where: { $0.id == id }) {
            timers[index].isPaused = true
            timers[index].isRunning = false
        }
    }
    
    // 恢复特定计时器
    func resumeTimer(id: UUID) {
        if let index = timers.firstIndex(where: { $0.id == id }) {
            timers[index].isPaused = false
            timers[index].isRunning = true
            startGlobalTimer()
        }
    }
    
    // 删除特定计时器
    func removeTimer(id: UUID) {
        timers.removeAll { $0.id == id }
    }
    
    // 格式化时间显示
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d小时%02d分", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d分%02d秒", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }
    
    // 发送通知
    private func notifyTimerComplete() {
        // 显示遮罩
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showOverlay = true
            self.showOverlayWindow()
        }
    }
    
    private func showOverlayWindow() {
        cleanup()
        
        guard let screen = NSScreen.main else { return }
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: NSWindow.StyleMask.borderless,
            backing: NSWindow.BackingStoreType.buffered,
            defer: false,
            screen: screen
        )
        
        overlayWindow = window
        
        window.backgroundColor = NSColor.clear
        window.level = NSWindow.Level.screenSaver
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        
        let overlayView = OverlayView(isVisible: .init(
            get: { [weak self] in
                self?.showOverlay ?? false
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                self.showOverlay = newValue
                if !newValue {
                    self.cleanup()
                }
            }
        ))
        
        let hostingView = NSHostingView(rootView: overlayView)
        overlayHostingView = hostingView
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        
        // 5秒后自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        overlayWindow?.contentView = nil
        overlayHostingView = nil
        overlayWindow?.close()
        overlayWindow = nil
        showOverlay = false
    }
} 