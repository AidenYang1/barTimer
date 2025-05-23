import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 添加对窗口控制器的引用
    let windowDelegate: SettingsWindowController
    
    // 设置项状态变量
    @AppStorage("timerFormat") private var timerFormat = "数字"
    @AppStorage("soundType") private var soundType = "马林巴"
    @AppStorage("soundVolume") private var soundVolume = "中等"
    @AppStorage("showNotification") private var showNotification = true
    @AppStorage("showSuggestions") private var showSuggestions = true
    @AppStorage("preventSleep") private var preventSleep = false
    
    // 快捷键记录状态
    @State private var isRecordingNewTimer = false
    @State private var isRecordingPauseTimer = false
    
    let soundTypes = ["马林巴", "铃声", "经典", "数字音"]
    let volumeLevels = ["低", "中等", "高"]
    
    var body: some View {
        VStack(spacing: 24) {
            // 快捷键设置
            Group {
                HStack {
                    Text("创建新计时器:")
                        .frame(width: 150, alignment: .trailing)
                    Button("记录快捷键") {
                        isRecordingNewTimer.toggle()
                    }
                    .frame(width: 200)
                }
                
                HStack {
                    Text("暂停当前计时器:")
                        .frame(width: 150, alignment: .trailing)
                    Button("记录快捷键") {
                        isRecordingPauseTimer.toggle()
                    }
                    .frame(width: 200)
                }
            }
            
            // 计时器格式设置
            HStack {
                Text("计时器格式:")
                    .frame(width: 150, alignment: .trailing)
                Menu {
                    Button("数字（默认）", action: { timerFormat = "数字" })
                    Button("自然语言", action: { timerFormat = "自然语言" })
                } label: {
                    Text(timerFormat)
                        .frame(width: 200, alignment: .leading)
                }
            }
            
            // 声音设置
            Group {
                HStack {
                    Text("计时结束音:")
                        .frame(width: 150, alignment: .trailing)
                    Menu {
                        ForEach(soundTypes, id: \.self) { type in
                            Button(type, action: { soundType = type })
                        }
                    } label: {
                        Text(soundType)
                            .frame(width: 200, alignment: .leading)
                    }
                }
                
                HStack {
                    Text("声音音量:")
                        .frame(width: 150, alignment: .trailing)
                    Menu {
                        ForEach(volumeLevels, id: \.self) { level in
                            Button(level, action: { soundVolume = level })
                        }
                    } label: {
                        Text(soundVolume)
                            .frame(width: 200, alignment: .leading)
                    }
                }
            }
            
            // 通知和其他设置
            Group {
                HStack {
                    Text("通知:")
                        .frame(width: 150, alignment: .trailing)
                    Toggle("计时结束时显示通知", isOn: $showNotification)
                        .frame(width: 200, alignment: .leading)
                }
                
                HStack {
                    Text("自动完成:")
                        .frame(width: 150, alignment: .trailing)
                    Toggle("显示输入建议", isOn: $showSuggestions)
                        .frame(width: 200, alignment: .leading)
                }
                
                HStack {
                    Text("防止睡眠:")
                        .frame(width: 150, alignment: .trailing)
                    Toggle("计时期间防止系统睡眠", isOn: $preventSleep)
                        .frame(width: 200, alignment: .leading)
                }
            }
            
            Spacer()
            
            // 底部按钮
            HStack {
                Spacer()
                Button("完成") {
                    windowDelegate.closeWindow()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    SettingsView(windowDelegate: SettingsWindowController.shared)
} 