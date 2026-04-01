import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 添加对窗口控制器的引用
    let windowDelegate: SettingsWindowController
    
    // 添加 TimerManager 引用以访问提示音设置
    @EnvironmentObject var timerManager: TimerManager
    
    // 设置项状态变量
    @AppStorage("alertSound") private var alertSoundRawValue = TimerManager.AlertSound.sound1.rawValue
    @AppStorage("soundVolume") private var soundVolume = "medium"
    @AppStorage("enableAlertSound") private var enableAlertSound = true  // 新增：提示音开关
    @AppStorage("showNotification") private var showNotification = true
    @AppStorage("showSuggestions") private var showSuggestions = true
    @AppStorage("preventSleep") private var preventSleep = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false  // 新增：登录时启动
    @AppStorage("autoCheckUpdate") private var autoCheckUpdate = true  // 自动检查更新
    @AppStorage("useSpaceForEvent") private var useSpaceForEvent = false  // 空格代替@输入事件
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue  // 应用语言
    @AppStorage("enableTickSound") private var enableTickSound = false  // 倒计时滴答音效
    @AppStorage("tickSoundVolume") private var tickSoundVolume: Double = 0.5  // 滴答音量
    @AppStorage("enableiCloudSync") private var enableiCloudSync = false  // iCloud 同步
    
    // 快捷键记录状态
    @State private var isRecordingNewTimer = false
    @State private var isRecordingPauseTimer = false
    
    let volumeLevels = ["low", "medium", "high"]
    let languageOptions: [AppLanguage] = [.system, .zhHans, .en]
    
    // 计算属性获取当前提示音
    var currentAlertSound: TimerManager.AlertSound {
        TimerManager.AlertSound(rawValue: alertSoundRawValue) ?? .sound1
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
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
                
                // 声音设置组
                Group {
                    // 提示音开关
                    HStack {
                        Text("启用提示音:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("", isOn: Binding(
                            get: { enableAlertSound },
                            set: { newValue in
                                enableAlertSound = newValue
                                timerManager.enableAlertSound = newValue
                            }
                        ))
                        .toggleStyle(.switch)
                        .frame(width: 200, alignment: .leading)
                    }
                    
                    // 计时结束音选择（只在启用提示音时可用）
                    HStack {
                        Text("计时结束音:")
                            .frame(width: 150, alignment: .trailing)
                            .foregroundColor(enableAlertSound ? .primary : .secondary)
                        Menu {
                            ForEach(TimerManager.AlertSound.allCases, id: \.self) { sound in
                                Button(action: {
                                    alertSoundRawValue = sound.rawValue
                                    timerManager.saveAlertSound(sound)
                                    // 预览提示音（只在启用时）
                                    if enableAlertSound {
                                        timerManager.playAlertSound(sound)
                                    }
                                }) {
                                    HStack {
                                        Text(sound.displayName)
                                        if sound == currentAlertSound {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentAlertSound.displayName)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .frame(width: 200, alignment: .leading)
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(!enableAlertSound)
                    }
                    
                    // 声音音量（只在启用提示音时可用）
                    HStack {
                        Text("声音音量:")
                            .frame(width: 150, alignment: .trailing)
                            .foregroundColor(enableAlertSound ? .primary : .secondary)
                        Menu {
                            ForEach(volumeLevels, id: \.self) { level in
                                Button(action: {
                                    soundVolume = level
                                    timerManager.updateVolume(level)
                                }) {
                                    Text(volumeDisplayName(level))
                                }
                            }
                        } label: {
                            HStack {
                                Text(volumeDisplayName(soundVolume))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .frame(width: 200, alignment: .leading)
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(!enableAlertSound)
                    }
                }
                
                // 倒计时滴答音效
                Group {
                    HStack {
                        Text("倒计时音效:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("播放滴答声", isOn: Binding(
                            get: { enableTickSound },
                            set: { newValue in
                                enableTickSound = newValue
                                timerManager.enableTickSound = newValue
                            }
                        ))
                        .frame(width: 200, alignment: .leading)
                    }
                    
                    if enableTickSound {
                        HStack {
                            Text("滴答音量:")
                                .frame(width: 150, alignment: .trailing)
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $tickSoundVolume, in: 0...1)
                                    .onChange(of: tickSoundVolume) { _, newValue in
                                        timerManager.updateTickVolume(Float(newValue))
                                    }
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 200)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
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
                    
                    // 事件输入方式设置
                    HStack {
                        Text("事件输入:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("使用空格代替 @ 输入事件", isOn: $useSpaceForEvent)
                            .frame(width: 200, alignment: .leading)
                    }
                    
                    HStack {
                        Text("防止睡眠:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("计时期间防止系统睡眠", isOn: $preventSleep)
                            .frame(width: 200, alignment: .leading)
                    }
                    
                    // 新增：登录时启动
                    HStack {
                        Text("登录与启动:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("登录时自动启动", isOn: Binding(
                            get: { launchAtLogin },
                            set: { newValue in
                                launchAtLogin = newValue
                                setLaunchAtLogin(enabled: newValue)
                            }
                        ))
                        .frame(width: 200, alignment: .leading)
                    }
                    
                    HStack {
                        Text("检查更新:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("自动检查更新", isOn: Binding(
                            get: { autoCheckUpdate },
                            set: { newValue in
                                autoCheckUpdate = newValue
                                (NSApp.delegate as? AppDelegate)?.updaterController.updater.automaticallyChecksForUpdates = newValue
                            }
                        ))
                        .frame(width: 200, alignment: .leading)
                    }

                    HStack {
                        Spacer()
                        Button("立即检查更新") {
                            (NSApp.delegate as? AppDelegate)?.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }

                    // 语言设置
                    HStack {
                        Text("语言:")
                            .frame(width: 150, alignment: .trailing)
                        Menu {
                            ForEach(languageOptions, id: \.self) { lang in
                                Button(action: {
                                    appLanguageRaw = lang.rawValue
                                    // 设置 AppleLanguages 以确保重启后 NSLocalizedString 生效
                                    if lang == .system {
                                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                                    } else {
                                        UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
                                    }
                                }) {
                                    HStack {
                                        Text(languageDisplayName(lang))
                                        if lang.rawValue == appLanguageRaw {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(languageDisplayName(AppLanguage(rawValue: appLanguageRaw) ?? .system))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .frame(width: 200, alignment: .leading)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    // 语言切换提示
                    HStack {
                        Spacer()
                        Text("更改语言后请重启应用以完全生效")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    // iCloud 同步
                    HStack {
                        Text("iCloud:")
                            .frame(width: 150, alignment: .trailing)
                        Toggle("同步计时数据到 iCloud", isOn: Binding(
                            get: { enableiCloudSync },
                            set: { newValue in
                                enableiCloudSync = newValue
                                if newValue {
                                    timerManager.eventStore?.forceUploadToiCloud()
                                }
                            }
                        ))
                        .frame(width: 200, alignment: .leading)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // 版本号显示
                HStack {
                    Spacer()
                    Text(
                        String(
                            format: NSLocalizedString("VERSION_FORMAT", comment: "App version label"),
                            locale: AppLanguage.currentLocale,
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        )
                    )
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Spacer()
                    .frame(height: 20)
            }
            .padding(20)
        }
        .frame(width: 450, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottomLeading) {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("退出 barTimer")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .padding(20)
        }
        .overlay(alignment: .bottomTrailing) {
            Button("完成") {
                windowDelegate.closeWindow()
            }
            .buttonStyle(.borderedProminent)
            .padding(20)
        }
        .onAppear {
            // 同步设置到 TimerManager
            timerManager.enableAlertSound = enableAlertSound
            timerManager.updateVolume(soundVolume)
        }
    }
    
    // 设置登录时启动
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("设置登录启动失败: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 及以下使用旧 API
            SMLoginItemSetEnabled("com.aiden.barTimer" as CFString, enabled)
        }
    }
    
    private func volumeDisplayName(_ level: String) -> LocalizedStringKey {
        switch level {
        case "low", "低":
            return "低"
        case "high", "高":
            return "高"
        default:
            return "中等"
        }
    }

    private func languageDisplayName(_ lang: AppLanguage) -> LocalizedStringKey {
        switch lang {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }
}

#Preview {
    SettingsView(windowDelegate: SettingsWindowController.shared)
        .environmentObject(TimerManager())
} 
