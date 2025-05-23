//
//  ContentView.swift
//  barTimer
//
//  Created by 杨翼臣 on 2025/5/23.
//

import SwiftUI
import AppKit
import UserNotifications

// 修改窗口控制器类
class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var hostingView: NSHostingView<SettingsView>? // 保持对 hostingView 的引用
    var window: NSWindow?
    
    func showWindow() {
        if window == nil {
            // 创建设置窗口
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            // 先创建并保持对 hostingView 的引用
            hostingView = NSHostingView(rootView: SettingsView(windowDelegate: self))
            window?.contentView = hostingView
            window?.title = "设置"
            window?.center()
            window?.level = .floating
            window?.delegate = self
        }
        
        window?.makeKeyAndOrderFront(nil)
    }
    
    func closeWindow() {
        // 先移除 hostingView
        window?.contentView = nil
        hostingView = nil
        window?.close()
        window = nil
    }
    
    // 处理窗口关闭事件
    func windowWillClose(_ notification: Notification) {
        // 确保清理顺序正确
        window?.contentView = nil
        hostingView = nil
        window = nil
    }
}

struct ContentView: View {
    @StateObject private var timerManager = TimerManager()
    @Binding var isShowingPopover: Bool
    @State private var timeInput: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) { // 新增: 添加VStack来垂直排列文本
                    Text("为一个\"行为\",限定时间。") // 新增: 添加提示文本
                        .font(.system(size: 14))
                       
                    Text("计时器")
                        .font(.system(size: 25))
                        .bold()
                }
                
                Spacer()
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .onTapGesture {
                        // 新增: 修复openSettings未定义的问题
                        SettingsWindowController.shared.showWindow()
                    }
            }
            
            HStack {
                TextField("2小时30分", text: $timeInput)
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
                
                Button(action: addNewTimer) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.blue)
                        .cornerRadius(15)
                }
            }
            
            // 计时器列表
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(timerManager.timers) { timer in
                        TimerItemView(timer: timer, timerManager: timerManager)
                    }
                }
            }
        }
        .padding()
        .frame(width: 350)
        .frame(minHeight: 170)
        .sheet(isPresented: $showingSettings) {
            SettingsView(windowDelegate: SettingsWindowController.shared)
        }
    }
    
    private func addNewTimer() {
        if let duration = timerManager.parseTimeInput(timeInput) {
            timerManager.addTimer(duration: duration)
            timeInput = ""
        }
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
    
    var body: some View {
        HStack {
            // 修改时间显示部分
            Text(timerManager.formatTime(timer.remainingTime))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(
                    RoundedRectangle(cornerRadius: 16)
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
                Image(systemName: timer.isRunning && !timer.isPaused ? "pause.fill" : "play.fill")
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            
            // 删除按钮
            Button(action: {
                timerManager.removeTimer(id: timer.id)
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.gray)
                    .cornerRadius(15)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentView(isShowingPopover: .constant(true))
}
