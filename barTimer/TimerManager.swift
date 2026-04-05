import Foundation
import UserNotifications
import AudioToolbox
import AVFoundation
import SwiftUI
import AppKit

// 定义单个计时器的数据结构
struct TimerData: Identifiable {
    let id = UUID()
    var remainingTime: TimeInterval
    var originalDuration: TimeInterval
    var isRunning: Bool
    var isPaused: Bool
    var eventName: String?  // 关联的事件名称（通过 @ 语法指定）
}

// 自定义窗口类，防止窗口激活应用
private class NonActivatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class TimerManager: ObservableObject {
    private let defaultFocusEventName = "专注"
    @Published var timers: [TimerData] = []
    @Published var showOverlay = false
    @Published var enableAlertSound = true  // 提示音开关
    @Published var enableTickSound = false  // 倒计时滴答音效开关
    @Published var tickSoundMuted = false   // 滴答音效临时静音（菜单栏快捷切换）
    var eventStore: EventStore?  // 事件存储引用
    private var timer: Timer?
    private var overlayWindow: NSWindow?
    private var overlayHostingView: NSHostingView<OverlayView>?
    private var cleanupWorkItem: DispatchWorkItem?
    private var currentSound: NSSound? // 保持对当前播放声音的强引用
    private var tickPlayer: AVAudioPlayer? // 滴答音效（使用 AVAudioPlayer 支持音量放大）
    private var soundVolume: Float = 0.75  // 音量控制（0.0-1.0）
    private var tickSoundVolume: Float = 0.5  // 滴答音量（0.0-1.0）
    
    // 自定义提示音配置
    enum AlertSound: String, CaseIterable {
        case sound1 = "1"  // 对应 Sounds/1.mp3
        
        var displayName: String {
            switch self {
            case .sound1: return NSLocalizedString("敲醒", comment: "Alert sound display name")
            }
        }
        
        var fileName: String {
            // 返回音频文件名（不含扩展名）
            return self.rawValue
        }
    }
    
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
        
        // 从 UserDefaults 加载提示音开关状态
        enableAlertSound = UserDefaults.standard.bool(forKey: "enableAlertSound")
        if UserDefaults.standard.object(forKey: "enableAlertSound") == nil {
            enableAlertSound = true
        }
        
        // 加载滴答音效设置
        enableTickSound = UserDefaults.standard.bool(forKey: "enableTickSound")
        tickSoundVolume = UserDefaults.standard.float(forKey: "tickSoundVolume")
        if UserDefaults.standard.object(forKey: "tickSoundVolume") == nil {
            tickSoundVolume = 0.5
        }
        
        // 从 UserDefaults 加载音量设置
        let volumeLevel = UserDefaults.standard.string(forKey: "soundVolume") ?? "medium"
        updateVolume(volumeLevel)
    }
    
    // 更新滴答音量
    func updateTickVolume(_ volume: Float) {
        tickSoundVolume = volume
        UserDefaults.standard.set(volume, forKey: "tickSoundVolume")
    }
    
    // 播放滴答音效
    private func playTickSound() {
        guard enableTickSound, !tickSoundMuted else { return }
        
        if tickPlayer == nil {
            if let url = Bundle.main.url(forResource: "tick", withExtension: "wav") ??
                         Bundle.main.url(forResource: "tick", withExtension: "mp3") ??
                         Bundle.main.url(forResource: "tick", withExtension: "aiff") {
                tickPlayer = try? AVAudioPlayer(contentsOf: url)
                tickPlayer?.prepareToPlay()
            }
        }
        
        tickPlayer?.volume = tickSoundVolume
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
    }
    
    // 停止滴答音效
    func stopTickSound() {
        tickPlayer?.stop()
    }
    
    // 更新音量
    func updateVolume(_ level: String) {
        switch level {
        case "low", "低":
            soundVolume = 0.3
        case "high", "高":
            soundVolume = 1.0
        default: // "medium" / "中等"
            soundVolume = 0.6
        }
    }
    
    // 解析输入的时间字符串，支持：
    // - "@ 事件名" 语法（如 "30分@写代码"）
    // - 在设置中开启后，使用空格分隔事件名（如 "30分 写代码"）
    func parseTimeInput(_ input: String) -> (duration: TimeInterval, eventName: String?)? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 优先处理 @ 语法，保持兼容
        let atParts = trimmedInput.split(separator: "@", maxSplits: 1)
        if atParts.count > 1 {
            let timePart = String(atParts[0])
            let eventPart = String(atParts[1]).trimmingCharacters(in: .whitespaces)
            
            guard let duration = parseTimeDuration(timePart) else { return nil }
            let eventName = eventPart.isEmpty ? nil : eventPart
            return (duration, eventName)
        }
        
        // 2. 如果开启“用空格代替 @ 输入事件”，尝试用首个空格分隔时间和事件
        let useSpaceForEvent = UserDefaults.standard.bool(forKey: "useSpaceForEvent")
        if useSpaceForEvent, let firstSpaceRange = trimmedInput.range(of: " ") {
            let timeCandidate = String(trimmedInput[..<firstSpaceRange.lowerBound])
            let eventCandidate = String(trimmedInput[firstSpaceRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            
            if let duration = parseTimeDuration(timeCandidate) {
                let eventName = eventCandidate.isEmpty ? nil : eventCandidate
                return (duration, eventName)
            } else {
                // 如果按空格切分后的时间无法解析，退回尝试整体解析为时间（兼容 "1 小时30分" 这类写法）
                if let duration = parseTimeDuration(trimmedInput) {
                    return (duration, nil)
                } else {
                    return nil
                }
            }
        }
        
        // 3. 默认：整体解析为时间，不带事件
        guard let duration = parseTimeDuration(trimmedInput) else { return nil }
        return (duration, nil)
    }
    
    // 解析时间部分
    func parseTimeDuration(_ input: String) -> TimeInterval? {
        // 移除所有空格
        let cleanInput = input.replacingOccurrences(of: " ", with: "")
        var totalSeconds: TimeInterval = 0
        
        // 匹配小时、分钟和秒的正则表达式
        let patterns: [(pattern: String, multipliers: (TimeInterval, TimeInterval, TimeInterval))] = [
            // 三个单位组合
            ("([0-9]+)小时([0-9]+)分([0-9]+)秒", (3600.0, 60.0, 1.0)),   // 1小时30分45秒
            ("([0-9]+)小时([0-9]+)分钟([0-9]+)秒", (3600.0, 60.0, 1.0)), // 1小时30分钟45秒
            ("([0-9]+)h([0-9]+)m([0-9]+)s", (3600.0, 60.0, 1.0)),        // 1h30m45s
            ("([0-9]+):([0-9]+):([0-9]+)", (3600.0, 60.0, 1.0)),         // 1:30:45
            
            // 两个单位组合（包括混合格式）
            ("([0-9]+)小时([0-9]+)分钟", (3600.0, 60.0, 0.0)),           // 2小时30分钟
            ("([0-9]+)小时([0-9]+)分", (3600.0, 60.0, 0.0)),             // 2小时30分
            ("([0-9]+)小时([0-9]+)m", (3600.0, 60.0, 0.0)),              // 2小时30m (混合)
            ("([0-9]+)小时([0-9]+)s", (3600.0, 1.0, 0.0)),               // 2小时30s (混合)
            ("([0-9]+)h([0-9]+)分钟", (3600.0, 60.0, 0.0)),              // 2h30分钟 (混合)
            ("([0-9]+)h([0-9]+)分", (3600.0, 60.0, 0.0)),                // 2h30分 (混合)
            ("([0-9]+)分([0-9]+)秒", (60.0, 1.0, 0.0)),                  // 30分45秒
            ("([0-9]+)分钟([0-9]+)秒", (60.0, 1.0, 0.0)),                // 30分钟45秒
            ("([0-9]+)分钟([0-9]+)s", (60.0, 1.0, 0.0)),                 // 40分钟20s (混合)
            ("([0-9]+)分([0-9]+)s", (60.0, 1.0, 0.0)),                   // 40分20s (混合)
            ("([0-9]+)m([0-9]+)秒", (60.0, 1.0, 0.0)),                   // 40m20秒 (混合)
            ("([0-9]+)h([0-9]+)m", (3600.0, 60.0, 0.0)),                 // 2h30m
            ("([0-9]+)h([0-9]+)s", (3600.0, 1.0, 0.0)),                  // 2h30s (混合)
            ("([0-9]+)m([0-9]+)s", (60.0, 1.0, 0.0)),                    // 30m45s
            ("([0-9]+):([0-9]+)", (60.0, 1.0, 0.0)),                     // 30:45 (分:秒)
            
            // 单个单位
            ("([0-9]+)小时", (3600.0, 0.0, 0.0)),                        // 2小时
            ("([0-9]+)分钟", (60.0, 0.0, 0.0)),                          // 30分钟
            ("([0-9]+)分", (60.0, 0.0, 0.0)),                            // 30分
            ("([0-9]+)秒钟", (1.0, 0.0, 0.0)),                           // 30秒钟
            ("([0-9]+)秒", (1.0, 0.0, 0.0)),                             // 30秒
            ("([0-9]+)h", (3600.0, 0.0, 0.0)),                           // 2h
            ("([0-9]+)m", (60.0, 0.0, 0.0)),                             // 30m
            ("([0-9]+)s", (1.0, 0.0, 0.0))                               // 45s
        ]
        
        // 尝试匹配每个模式
        for (pattern, multipliers) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(cleanInput.startIndex..., in: cleanInput)
                if let match = regex.firstMatch(in: cleanInput, range: range) {
                    let nsString = cleanInput as NSString
                    
                    // 提取所有捕获的数字
                    let firstNumber = match.numberOfRanges > 1 ? 
                        (Double(nsString.substring(with: match.range(at: 1))) ?? 0) : 0
                    let secondNumber = match.numberOfRanges > 2 ? 
                        (Double(nsString.substring(with: match.range(at: 2))) ?? 0) : 0
                    let thirdNumber = match.numberOfRanges > 3 ? 
                        (Double(nsString.substring(with: match.range(at: 3))) ?? 0) : 0
                    
                    // 计算总秒数
                    totalSeconds = firstNumber * multipliers.0 + 
                                   secondNumber * multipliers.1 + 
                                   thirdNumber * multipliers.2
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
    func addTimer(duration: TimeInterval, eventName: String? = nil) {
        let newTimer = TimerData(
            remainingTime: duration,
            originalDuration: duration,
            isRunning: true,
            isPaused: false,
            eventName: eventName
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
        
        // 使用 RunLoop.main 确保在主线程的正确 RunLoop 中
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 直接在 Timer 回调中更新（Timer 已经在主线程上）
            var hasTimerCompleted = false
            
            var hasActiveTimer = false
            for index in self.timers.indices {
                if self.timers[index].isRunning && !self.timers[index].isPaused {
                    self.timers[index].remainingTime -= 1
                    hasActiveTimer = true
                    
                    // 检查是否完成
                    if self.timers[index].remainingTime <= 0 {
                        self.timers[index].isRunning = false
                        hasTimerCompleted = true
                    }
                }
            }
            
            // 播放滴答音效
            if hasActiveTimer && !hasTimerCompleted {
                self.playTickSound()
            }
            
            // 如果有计时器完成，停止滴答声并发送通知
            if hasTimerCompleted {
                self.stopTickSound()
                // 记录已完成的计时器到事件存储
                let completedTimers = self.timers.filter { $0.remainingTime <= 0 }
                for completed in completedTimers {
                    self.eventStore?.addEntry(
                        name: self.normalizedEventName(completed.eventName),
                        duration: completed.originalDuration
                    )
                }
                
                self.notifyTimerComplete()
                self.timers.removeAll { $0.remainingTime <= 0 }
                self.sortTimers()
            }
            
            // 如果没有活动的计时器，停止全局计时器
            if !self.timers.contains(where: { $0.isRunning && !$0.isPaused }) {
                self.stopGlobalTimer()
            }
        }
        
        // 确保 Timer 添加到主 RunLoop
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // 停止全局计时器
    private func stopGlobalTimer() {
        guard let currentTimer = timer else { return }
        currentTimer.invalidate()
        timer = nil
        stopTickSound()
    }
    
    // 暂停特定计时器
    func pauseTimer(id: UUID) {
        if let index = timers.firstIndex(where: { $0.id == id }) {
            timers[index].isPaused = true
            timers[index].isRunning = false
        }
        // 没有活动计时器时停止滴答声
        if !timers.contains(where: { $0.isRunning && !$0.isPaused }) {
            stopTickSound()
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
        if let timerToRemove = timers.first(where: { $0.id == id }) {
            recordElapsedTimeIfNeeded(for: timerToRemove)
        }
        timers.removeAll { $0.id == id }
        // 没有活动计时器时停止滴答声
        if !timers.contains(where: { $0.isRunning && !$0.isPaused }) {
            stopTickSound()
        }
    }

    // 暂停所有计时器
    func pauseAllTimers() {
        for index in timers.indices {
            if timers[index].isRunning && !timers[index].isPaused {
                timers[index].isPaused = true
                timers[index].isRunning = false
            }
        }
        stopTickSound()
    }

    // 删除所有计时器
    func removeAllTimers() {
        for timer in timers {
            recordElapsedTimeIfNeeded(for: timer)
        }
        timers.removeAll()
        stopTickSound()
    }

    private func normalizedEventName(_ eventName: String?) -> String {
        let normalized = eventName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalized?.isEmpty == false) ? normalized! : defaultFocusEventName
    }

    // 用户手动取消计时时，记录已经消耗掉的时长
    private func recordElapsedTimeIfNeeded(for timer: TimerData) {
        let elapsed = max(0, timer.originalDuration - max(0, timer.remainingTime))
        guard elapsed > 0 else { return }
        eventStore?.addEntry(name: normalizedEventName(timer.eventName), duration: elapsed)
    }
    
    // 格式化时间显示（用于展开的菜单列表 - 不显示"限定"）
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(
                format: NSLocalizedString("TIME_FORMAT_H_M", comment: "Time format for hours and minutes"),
                locale: AppLanguage.currentLocale,
                hours,
                minutes
            )
        } else if minutes > 0 {
            return String(
                format: NSLocalizedString("TIME_FORMAT_M_S", comment: "Time format for minutes and seconds"),
                locale: AppLanguage.currentLocale,
                minutes,
                seconds
            )
        } else {
            return String(
                format: NSLocalizedString("TIME_FORMAT_S", comment: "Time format for seconds"),
                locale: AppLanguage.currentLocale,
                seconds
            )
        }
    }
    
    // 格式化时间显示（用于菜单栏图标 - 显示"限定"）
    func formatTimeForMenuBar(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(
                format: NSLocalizedString("MENU_BAR_TIME_HMS", comment: "Menu bar timer format with hours"),
                locale: AppLanguage.currentLocale,
                hours,
                minutes,
                seconds
            )
        } else if minutes > 0 {
            return String(
                format: NSLocalizedString("MENU_BAR_TIME_MS", comment: "Menu bar timer format with minutes"),
                locale: AppLanguage.currentLocale,
                minutes,
                seconds
            )
        } else {
            return String(
                format: NSLocalizedString("MENU_BAR_TIME_S", comment: "Menu bar timer format for under one minute"),
                locale: AppLanguage.currentLocale,
                seconds
            )
        }
    }
    
    // 播放提示音
    func playAlertSound(_ sound: AlertSound = .sound1) {
        // 检查是否启用提示音
        guard enableAlertSound else { return }
        
        // 确保在主线程执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 停止之前的声音
            self.currentSound?.stop()
            self.currentSound = nil
            
            // 从 Bundle 加载自定义音频文件
            // 支持的格式: .mp3, .wav, .aiff, .m4a, .caf
            if let soundURL = Bundle.main.url(forResource: sound.fileName, withExtension: "mp3") ?? 
                               Bundle.main.url(forResource: sound.fileName, withExtension: "wav") ??
                               Bundle.main.url(forResource: sound.fileName, withExtension: "aiff") ??
                               Bundle.main.url(forResource: sound.fileName, withExtension: "m4a") ??
                               Bundle.main.url(forResource: sound.fileName, withExtension: "caf") {
                
                if let newSound = NSSound(contentsOf: soundURL, byReference: false) {
                    self.currentSound = newSound
                    // 设置音量
                    newSound.volume = self.soundVolume
                    newSound.play()
                } else {
                    print("⚠️ 无法创建声音对象: \(sound.fileName)")
                    NSSound.beep()
                }
            } else {
                print("⚠️ 找不到音频文件: \(sound.fileName)")
                NSSound.beep()
            }
        }
    }
    
    // 获取当前选择的提示音
    func getCurrentAlertSound() -> AlertSound {
        let soundName = UserDefaults.standard.string(forKey: "alertSound") ?? AlertSound.sound1.rawValue
        return AlertSound(rawValue: soundName) ?? .sound1
    }
    
    // 保存提示音设置
    func saveAlertSound(_ sound: AlertSound) {
        UserDefaults.standard.set(sound.rawValue, forKey: "alertSound")
    }
    
    // 发送通知
    private func notifyTimerComplete() {
        // 显示全屏弹窗
        DispatchQueue.main.async { [weak self] in
            self?.showOverlayWindow()
        }
    }
    
    private func showOverlayWindow() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showOverlayWindow()
            }
            return
        }
        
        // 取消之前的清理任务
        cleanupWorkItem?.cancel()
        
        // 如果窗口已存在，直接返回
        if overlayWindow != nil {
            return
        }
        
        guard let screen = NSScreen.main else { return }
        
        // 使用自定义的 NonActivatingWindow，配置为辅助窗口
        let window = NonActivatingWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow = window
        
        // 关键配置：确保窗口不会影响应用的激活状态
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .transient  // 标记为临时窗口
        ]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        window.animationBehavior = .none
        
        // 创建视图
        let overlayView = OverlayView(isVisible: .init(
            get: { true },
            set: { [weak self] newValue in
                if !newValue {
                    self?.cleanup()
                }
            }
        ))
        let hostingView = NSHostingView(rootView: overlayView)
        overlayHostingView = hostingView
        window.contentView = hostingView
        
        // 使用 orderFrontRegardless 而不是 makeKeyAndOrderFront，避免激活应用
        window.orderFrontRegardless()
        
        // 播放选择的提示音（重复两遍）
        let sound = getCurrentAlertSound()
        playAlertSound(sound)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playAlertSound(sound)
        }
        
        // 更新状态
        showOverlay = true
        
        // 5秒后自动关闭
        let workItem = DispatchWorkItem { [weak self] in
            self?.cleanup()
        }
        cleanupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }
    
    private func cleanup() {
        // 取消待执行的清理任务
        cleanupWorkItem?.cancel()
        cleanupWorkItem = nil
        
        // 停止声音播放
        currentSound?.stop()
        currentSound = nil
        
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.cleanup()
            }
            return
        }
        
        guard let window = overlayWindow else { return }
        
        // 先重置状态
        showOverlay = false
        
        // 立即隐藏窗口
        window.orderOut(nil)
        
        // 延迟清理视图
        DispatchQueue.main.async { [weak self] in
            window.contentView = nil
            self?.overlayHostingView = nil
            window.close()
            self?.overlayWindow = nil
        }
    }
    
    // 清理资源
    deinit {
        // 停止声音播放
        currentSound?.stop()
        currentSound = nil
        tickPlayer?.stop()
        tickPlayer = nil
        
        cleanupWorkItem?.cancel()
        timer?.invalidate()
        timer = nil
        
        let window = overlayWindow
        let hostingView = overlayHostingView
        
        if Thread.isMainThread {
            window?.orderOut(nil)
            window?.contentView = nil
            window?.close()
        } else {
            DispatchQueue.main.async {
                window?.orderOut(nil)
                window?.contentView = nil
                window?.close()
                _ = hostingView
            }
        }
    }
}

