//
//  ContentView.swift
//  barTimer
//
//  Created by AidenYang on 2025/5/23.
//

import SwiftUI
import AppKit
import UserNotifications

// 修改窗口控制器类
class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var hostingView: NSHostingView<AnyView>? // 改为具体类型
    var window: NSWindow?
    weak var timerManager: TimerManager? // 添加对 timerManager 的引用
    
    func showWindow(timerManager: TimerManager) {
        self.timerManager = timerManager // 保存引用
        
        // 如果窗口已存在，直接显示
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // 创建设置窗口
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // 创建设置视图
        let settingsView = SettingsView(windowDelegate: self)
            .environmentObject(timerManager)
        
        // 使用 AnyView 包装
        let anyView = AnyView(settingsView)
        hostingView = NSHostingView(rootView: anyView)
        
        newWindow.contentView = hostingView
        newWindow.title = NSLocalizedString("设置", comment: "Settings window title")
        newWindow.center()
        newWindow.level = .floating
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false // 防止窗口自动释放
        
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    func closeWindow() {
        guard let windowToClose = window else { return }
        
        // 确保在主线程执行
        DispatchQueue.main.async { [weak self] in
            // 先移除 delegate
            windowToClose.delegate = nil
            
            // 关闭窗口
            windowToClose.close()
            
            // 清理引用
            self?.window = nil
            self?.hostingView = nil
        }
    }
    
    // 处理窗口关闭事件（用户点击关闭按钮）
    func windowWillClose(_ notification: Notification) {
        // 清理引用
        window?.delegate = nil
        window = nil
        hostingView = nil
    }
}

// 键盘导航处理器（用于事件建议列表的上下选择）
class SuggestionKeyHandler: ObservableObject {
    @Published var selectedIndex: Int = -1
    var isActive: Bool = false
    var suggestionCount: Int = 0
    var onSelect: ((Int) -> Void)?
    var onSubmit: (() -> Void)?
    private var monitor: Any?
    
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isActive, self.suggestionCount > 0 else { return event }
            switch Int(event.keyCode) {
            case 125: // Down arrow
                self.selectedIndex = min(self.selectedIndex + 1, self.suggestionCount - 1)
                return nil
            case 126: // Up arrow
                self.selectedIndex = max(self.selectedIndex - 1, -1)
                return nil
            case 36: // Return
                if self.selectedIndex >= 0 {
                    self.onSelect?(self.selectedIndex)
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }
    
    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    deinit { stop() }
}

struct ContentView: View {
    @EnvironmentObject var timerManager: TimerManager  // 使用环境对象
    @EnvironmentObject var eventStore: EventStore  // 事件存储
    @Binding var isShowingPopover: Bool
    @State private var timeInput: String = ""
    @State private var showEventSuggestions: Bool = false
    @State private var selectedSuggestionIndex: Int = -1
    @StateObject private var keyHandler = SuggestionKeyHandler()
    @FocusState private var isFocused: Bool
    @AppStorage("useSpaceForEvent") private var useSpaceForEvent = false
    @State private var isHoveringMuteButton = false
    @State private var muteBellRotation: Double = 0

    private let timerRowHeight: CGFloat = 36
    private let timerItemSpacing: CGFloat = 12

    // 单个计时器行占用的总高度（含间距）
    private var timerListNaturalHeight: CGFloat {
        guard !timerManager.timers.isEmpty else { return 0 }
        return CGFloat(timerManager.timers.count) * timerRowHeight
            + CGFloat(timerManager.timers.count - 1) * timerItemSpacing
            + 8 // 上下内边距
    }

    // 可用最大高度：屏幕高度 - 菜单栏 - 固定头部区域
    private var maxTimerListHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let fixedContentHeight: CGFloat = 185 // 头部 + 输入框 + padding
        let menuBarHeight: CGFloat = 24
        return max(screenHeight - fixedContentHeight - menuBarHeight, 100)
    }

    private var timerListHeight: CGFloat {
        guard !timerManager.timers.isEmpty else { return 0 }
        return min(timerListNaturalHeight, maxTimerListHeight)
    }
    
    // 根据输入过滤事件建议
    private var eventSuggestions: [String] {
        // @ 语法
        if timeInput.contains("@") {
            let parts = timeInput.split(separator: "@", maxSplits: 1)
            let query = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces).lowercased() : ""
            let recent = eventStore.recentEventNames(limit: 5)
            if query.isEmpty { return recent }
            return recent.filter { $0.lowercased().contains(query) }
        }
        
        // 空格语法（开启时）
        if useSpaceForEvent, let spaceIndex = timeInput.firstIndex(of: " ") {
            let timePart = String(timeInput[..<spaceIndex])
            if timerManager.parseTimeDuration(timePart) != nil {
                let eventPart = String(timeInput[timeInput.index(after: spaceIndex)...])
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let recent = eventStore.recentEventNames(limit: 5)
                if eventPart.isEmpty { return recent }
                return recent.filter { $0.lowercased().contains(eventPart) }
            }
        }
        
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) { // 新增: 添加VStack来垂直排列文本
                    Text("为一个\"行为\", 限定时间。") // 新增: 添加提示文本
                        .font(.system(size: 14))
                       
                    Text("计时器")
                        .font(.system(size: 25))
                        .bold()
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // 滴答音效静音/响铃按钮（仅在设置中启用滴答音效时显示）
                    if timerManager.enableTickSound {
                        Button(action: toggleTickSoundMute) {
                            ZStack {
                                Image(systemName: timerManager.tickSoundMuted ? "bell.slash.fill" : "bell.fill")
                                    .font(.system(size: 16))
                                    .frame(width: 18, height: 18, alignment: .center)
                                    .foregroundColor(timerManager.tickSoundMuted ? .white : .primary)
                                    .rotationEffect(.degrees(muteBellRotation), anchor: .center)
                            }
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(timerManager.tickSoundMuted ? Color.red : Color.gray.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isHoveringMuteButton ? 1.08 : 1.0, anchor: .center)
                        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isHoveringMuteButton)
                        .onHover { hovering in
                            isHoveringMuteButton = hovering
                        }
                    }
                    
                    // 历史记录按钮（奖杯）
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                        .onTapGesture {
                            HistoryWindowController.shared.showWindow(eventStore: eventStore)
                        }
                    
                    // 设置按钮
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .padding(8)
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                        .onTapGesture {
                            SettingsWindowController.shared.showWindow(timerManager: timerManager)
                        }
                }
            }
            
            HStack {
                TextField("30分@写代码", text: $timeInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .frame(height: 40)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onSubmit {
                        addNewTimer()
                    }
                    .focused($isFocused)
                    .onChange(of: timeInput) { _, newValue in
                        // 检测是否应该显示建议
                        let hasAt = newValue.contains("@")
                        var hasSpaceEvent = false
                        if useSpaceForEvent, let spaceIndex = newValue.firstIndex(of: " ") {
                            let timePart = String(newValue[..<spaceIndex])
                            hasSpaceEvent = timerManager.parseTimeDuration(timePart) != nil
                        }
                        showEventSuggestions = hasAt || hasSpaceEvent
                        selectedSuggestionIndex = -1
                    }
                
                Group {
                    let brandColor = Color(red: 90/255, green: 80/255, blue: 222/255)
                    if #available(macOS 26.0, *) {
                        Button(action: addNewTimer) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .padding(8)
                        }
                        .buttonStyle(.glass)
                        .tint(brandColor)
                    } else {
                        Button(action: addNewTimer) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .padding(8)
                        }
                        .buttonStyle(.borderless)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(brandColor)
                        )
                    }
                }
            }
            
            // 事件建议列表
            if showEventSuggestions && !eventSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近事件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    ForEach(Array(eventSuggestions.enumerated()), id: \.element) { index, name in
                        Button(action: {
                            applySuggestion(name)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(name)
                                    .font(.system(size: 14))
                                Spacer()
                                if let record = eventStore.records.first(where: { $0.name == name }) {
                                    Text(EventStore.formatDuration(record.totalDuration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(index == selectedSuggestionIndex ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // 批量操作按钮（超过3个计时器时显示）
            if timerManager.timers.count > 3 {
                HStack(spacing: 16) {
                    Spacer()

                    // 暂停所有
                    Button(action: { timerManager.pauseAllTimers() }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.gray.opacity(0.25)))
                    }
                    .buttonStyle(.plain)

                    // 取消所有
                    Button(action: { timerManager.removeAllTimers() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.red.opacity(0.2)))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }

            // 计时器列表
            if !timerManager.timers.isEmpty {
                ScrollView {
                    VStack(spacing: timerItemSpacing) {
                        ForEach(timerManager.timers) { timer in
                            TimerItemView(timer: timer, timerManager: timerManager)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: timerListHeight)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            keyHandler.onSelect = { index in
                let suggestions = eventSuggestions
                if index >= 0 && index < suggestions.count {
                    applySuggestion(suggestions[index])
                }
            }
            keyHandler.onSubmit = { [self] in
                addNewTimer()
            }
            keyHandler.start()
        }
        .onDisappear {
            keyHandler.stop()
        }
        .onChange(of: showEventSuggestions) { _, newValue in
            keyHandler.isActive = newValue && !eventSuggestions.isEmpty
            if !newValue { selectedSuggestionIndex = -1 }
        }
        .onChange(of: eventSuggestions) { _, newValue in
            keyHandler.suggestionCount = newValue.count
            keyHandler.isActive = showEventSuggestions && !newValue.isEmpty
            selectedSuggestionIndex = -1
        }
        .onChange(of: keyHandler.selectedIndex) { _, newValue in
            selectedSuggestionIndex = newValue
        }
    }
    
    private func applySuggestion(_ name: String) {
        if let atIndex = timeInput.firstIndex(of: "@") {
            timeInput = String(timeInput[...atIndex]) + name
        } else if useSpaceForEvent, let spaceIndex = timeInput.firstIndex(of: " ") {
            timeInput = String(timeInput[...spaceIndex]) + name
        }
        showEventSuggestions = false
        selectedSuggestionIndex = -1
        keyHandler.selectedIndex = -1
    }
    
    private func addNewTimer() {
        if let result = timerManager.parseTimeInput(timeInput) {
            timerManager.addTimer(duration: result.duration, eventName: result.eventName)
            timeInput = ""
            showEventSuggestions = false
            selectedSuggestionIndex = -1
            keyHandler.selectedIndex = -1
        }
    }

    private func toggleTickSoundMute() {
        let willMute = !timerManager.tickSoundMuted
        timerManager.tickSoundMuted = willMute
        if willMute {
            timerManager.stopTickSound()
            animateMuteBellWobble()
        }
    }

    private func animateMuteBellWobble() {
        withAnimation(.easeInOut(duration: 0.08)) {
            muteBellRotation = -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.08)) {
                muteBellRotation = 10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.08)) {
                muteBellRotation = -6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.08)) {
                muteBellRotation = 0
            }
        }
    }
    
    // 更新预览
    static var previews: some View {
        ContentView(isShowingPopover: .constant(true))
            .environmentObject(TimerManager())
            .environmentObject(EventStore())
    }
}

// 单个计时器项的视图
struct TimerItemView: View {
    let timer: TimerData
    let timerManager: TimerManager
    
    // 计算颜色深度
    private var timerColor: Color {
        // 获取所有计时器中最大的剩余时间
        let maxTime = timerManager.timers.map { $0.remainingTime }.max() ?? timer.remainingTime
        
        // 计算当前计时器的时间比例
        let ratio = timer.remainingTime / maxTime
        
        // 根据比例在深红色和橙色之间插值
        let red: Double = 0.8  // 降低红色值使其更深
        let green: Double = 0.2 + (0.35 * ratio)  // 从深红到橙色的绿色分量,降低基础值使红色更深
        let blue: Double = 0.0
        let opacity: Double = 0.9 + (0.1 * (1 - ratio))  // 提高基础不透明度使颜色更深
        
        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    // 计时器标签（时间 + 事件名）
    private var timerLabel: some View {
        HStack(spacing: 6) {
            Text(timerManager.formatTime(timer.remainingTime))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            if let name = timer.eventName {
                Text("· \(name)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间显示部分（含事件名）
            timerLabel
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(timerColor)
                )
            
            // 暂停/播放按钮
            Button(action: {
                if timer.isPaused {
                    timerManager.resumeTimer(id: timer.id)
                } else if timer.isRunning {
                    timerManager.pauseTimer(id: timer.id)
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                    Image(systemName: timer.isRunning && !timer.isPaused ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            // 删除按钮
            Button(action: {
                timerManager.removeTimer(id: timer.id)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.85))
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }
}
