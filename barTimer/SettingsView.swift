import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    let windowDelegate: SettingsWindowController

    @EnvironmentObject var timerManager: TimerManager

    @AppStorage("alertSound") private var alertSoundRawValue = TimerManager.AlertSound.sound1.rawValue
    @AppStorage("soundVolume") private var soundVolume = "medium"
    @AppStorage("enableAlertSound") private var enableAlertSound = true
    @AppStorage("showNotification") private var showNotification = true
    @AppStorage("showSuggestions") private var showSuggestions = true
    @AppStorage("preventSleep") private var preventSleep = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoCheckUpdate") private var autoCheckUpdate = true
    @AppStorage("useSpaceForEvent") private var useSpaceForEvent = false
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage("enableTickSound") private var enableTickSound = false
    @AppStorage("tickSoundVolume") private var tickSoundVolume: Double = 0.5
    @AppStorage("enableiCloudSync") private var enableiCloudSync = false

    @ObservedObject private var hotkeyManager = GlobalHotkeyManager.shared
    @State private var accessibilityTrusted = GlobalHotkeyManager.isAccessibilityTrusted()

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
                        ShortcutRecorderButton(
                            current: hotkeyManager.newTimerShortcut,
                            onSave: { hotkeyManager.saveNewTimerShortcut($0) }
                        )
                        .frame(width: 200)
                    }

                    HStack {
                        Text("暂停所有计时器:")
                            .frame(width: 150, alignment: .trailing)
                        ShortcutRecorderButton(
                            current: hotkeyManager.pauseAllShortcut,
                            onSave: { hotkeyManager.savePauseAllShortcut($0) }
                        )
                        .frame(width: 200)
                    }

                    HStack(alignment: .top) {
                        Text(NSLocalizedString("辅助功能权限:", comment: "Accessibility permission section title"))
                            .frame(width: 150, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(accessibilityTrusted ? .green : .orange)
                                Text(accessibilityTrusted
                                      ? NSLocalizedString("已授权（全局快捷键可用）", comment: "Accessibility granted status")
                                      : NSLocalizedString("未授权（全局快捷键不可用）", comment: "Accessibility not granted status"))
                                    .font(.system(size: 13))
                            }

                            HStack(spacing: 8) {
                                Button(NSLocalizedString("打开权限引导", comment: "Open permission guide")) {
                                    AccessibilityOnboardingWindowController.shared.showWindow()
                                }
                                .buttonStyle(.bordered)

                                Button(NSLocalizedString("重新检查", comment: "Recheck accessibility permission")) {
                                    accessibilityTrusted = GlobalHotkeyManager.isAccessibilityTrusted()
                                    if accessibilityTrusted {
                                        GlobalHotkeyManager.shared.startMonitoring()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .frame(width: 200, alignment: .leading)
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
                                AppDelegate.shared?.updaterController.updater.automaticallyChecksForUpdates = newValue
                            }
                        ))
                        .frame(width: 200, alignment: .leading)
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("立即检查更新", comment: "")) {
                            AppDelegate.shared?.checkForUpdates()
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
                    
                    // iCloud 同步（暂未开放）
                    HStack {
                        Text("iCloud:")
                            .frame(width: 150, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Toggle("同步计时数据到 iCloud", isOn: .constant(false))
                            .frame(width: 200, alignment: .leading)
                            .disabled(true)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // 版本号 + GitHub 链接
                VStack(spacing: 8) {
                    Text(
                        String(
                            format: NSLocalizedString("VERSION_FORMAT", comment: "App version label"),
                            locale: AppLanguage.currentLocale,
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        )
                    )
                    .font(.body)
                    .foregroundColor(.secondary)

                    Button(action: {
                        if let url = URL(string: "https://github.com/AidenYang1/barTimer") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image("Github")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .help("在 GitHub 上查看项目")
                }
                // 开源项目仓库地址小字显示
                Text("项目开源仓库")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                .frame(maxWidth: .infinity)
                
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
            accessibilityTrusted = GlobalHotkeyManager.isAccessibilityTrusted()
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

// MARK: - ShortcutRecorderButton

/// 快捷键录制状态用 class 持有，避免 SwiftUI struct 捕获 self 副本导致 @State 无法正确更新
private class RecorderState: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?

    func start(onCapture: @escaping (HotkeyCombo?) -> Void) {
        isRecording = true
        GlobalHotkeyManager.shared.stopMonitoring()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 消费当前事件，下一 RunLoop 再处理，避免在回调内部移除自身导致崩溃
            DispatchQueue.main.async {
                if event.keyCode == 53 {
                    self?.stop(result: nil, save: false, onCapture: onCapture)
                } else {
                    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    let combo = HotkeyCombo(keyCode: event.keyCode, modifiers: mods.rawValue)
                    self?.stop(result: combo, save: true, onCapture: onCapture)
                }
            }
            return nil  // 始终消费，防止录制时快捷键触发其他行为
        }
    }

    func stop(result: HotkeyCombo?, save: Bool, onCapture: @escaping (HotkeyCombo?) -> Void) {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if save { onCapture(result) }
        GlobalHotkeyManager.shared.startMonitoring()
    }
}

struct ShortcutRecorderButton: View {
    let current: HotkeyCombo?
    let onSave: (HotkeyCombo?) -> Void

    @StateObject private var state = RecorderState()

    var label: String {
        if state.isRecording {
            return NSLocalizedString("请按下快捷键...", comment: "Recording shortcut prompt")
        }
        return current?.displayString ?? NSLocalizedString("记录快捷键", comment: "Record shortcut button")
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(label) {
                if state.isRecording {
                    state.stop(result: nil, save: false, onCapture: onSave)
                } else {
                    state.start(onCapture: onSave)
                }
            }
            .foregroundColor(state.isRecording ? .red : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)

            if current != nil && !state.isRecording {
                Button(action: { onSave(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
} 
