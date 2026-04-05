import AppKit
import CoreGraphics
import ApplicationServices

// MARK: - HotkeyCombo

struct HotkeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt

    var displayString: String {
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += keyCodeToChar(keyCode)
        return result
    }

    private func keyCodeToChar(_ code: UInt16) -> String {
        let map: [UInt16: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",
            8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",
            16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",
            23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",
            30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",
            38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",
            45:"N",46:"M",47:".",50:"`",
            36:"↩",48:"⇥",49:"Space",51:"⌫",53:"⎋",
            123:"←",124:"→",125:"↓",126:"↑"
        ]
        return map[code] ?? "?"
    }
}

// MARK: - GlobalHotkeyManager
// 使用 CGEventTap（系统会话层）代替 NSEvent globalMonitor。
// CGEventTap 不依赖 app 激活状态，不会被 NSApp.activate/setActivationPolicy 影响。

class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()

    @Published var newTimerShortcut: HotkeyCombo?
    @Published var pauseAllShortcut: HotkeyCombo?

    var onNewTimer: (() -> Void)?
    var onPauseAll: (() -> Void)?

    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var watchdogTimer: DispatchSourceTimer?

    private init() {
        loadShortcuts()
        startMonitoring()
    }

    // MARK: Persistence

    func loadShortcuts() {
        newTimerShortcut = load(key: "newTimerShortcut")
        pauseAllShortcut = load(key: "pauseAllShortcut")
    }

    private func load(key: String) -> HotkeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data)
        else { return nil }
        return combo
    }

    func saveNewTimerShortcut(_ combo: HotkeyCombo?) {
        newTimerShortcut = combo
        save(combo, key: "newTimerShortcut")
    }

    func savePauseAllShortcut(_ combo: HotkeyCombo?) {
        pauseAllShortcut = combo
        save(combo, key: "pauseAllShortcut")
    }

    private func save(_ combo: HotkeyCombo?, key: String) {
        if let combo, let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: Accessibility

    /// 检查辅助功能权限；未授权时弹出系统设置引导对话框
    static func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: Monitoring

    func startMonitoring() {
        stopMonitoring()

        // 辅助功能权限是 CGEventTap 的必要条件；未授权时启动 watchdog 轮询，授权后自动重建
        guard AXIsProcessTrusted() else {
            startWatchdog()
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                // macOS 会在回调超时后自动禁用 tap，此处立即重新启用以保持最高优先级
                if type.rawValue == 0xFFFFFFFE || type.rawValue == 0xFFFFFFFF {
                    if let tap = mgr.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return nil
                }

                guard type == .keyDown else { return Unmanaged.passRetained(event) }
                if mgr.handleCG(event) { return nil }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )

        guard let tap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        tapSource = source

        startWatchdog()
    }

    func stopMonitoring() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = tapSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
        eventTap = nil
        tapSource = nil
    }

    // 看门狗：每 3 秒检查一次
    // - 若 tap 存在但被禁用 → 立即重新启用
    // - 若 tap 不存在但辅助功能权限已获得 → 重建 tap
    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if let tap = self.eventTap {
                if !CGEvent.tapIsEnabled(tap: tap) {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } else if AXIsProcessTrusted() {
                // 用户刚授权辅助功能，重建 tap
                self.startMonitoring()
            }
        }
        timer.resume()
        watchdogTimer = timer
    }

    private func handleCG(_ cgEvent: CGEvent) -> Bool {
        let keyCode = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))
        let cg = cgEvent.flags
        var mods: NSEvent.ModifierFlags = []
        if cg.contains(.maskShift)     { mods.insert(.shift) }
        if cg.contains(.maskControl)   { mods.insert(.control) }
        if cg.contains(.maskAlternate) { mods.insert(.option) }
        if cg.contains(.maskCommand)   { mods.insert(.command) }
        let raw = mods.intersection(.deviceIndependentFlagsMask).rawValue

        if let c = newTimerShortcut, keyCode == c.keyCode, raw == c.modifiers {
            DispatchQueue.main.async { [weak self] in self?.onNewTimer?() }
            return true
        }
        if let c = pauseAllShortcut, keyCode == c.keyCode, raw == c.modifiers {
            DispatchQueue.main.async { [weak self] in self?.onPauseAll?() }
            return true
        }
        return false
    }
}
