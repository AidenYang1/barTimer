import AppKit

/// SwiftUI `MenuBarExtra` 与 `LSUIElement` 搭配时，反复切换 `NSApplication.ActivationPolicy`
/// 容易造成状态栏图标重复或残留。仅在确实需要 Dock/完整前台行为（例如 Sparkle 更新对话框）时
/// 临时切到 `.regular`，并用引用计数配对恢复 `.accessory`。
enum MenuBarActivationPolicy {
    private static var accessoryDepth = 0

    /// 进入需要 regular 外观的流程（例如 Sparkle 正在展示更新 UI）。
    static func pushRegularAppearance() {
        assert(Thread.isMainThread)
        accessoryDepth += 1
        if accessoryDepth == 1 {
            NSApp.setActivationPolicy(.regular)
        }
    }

    /// 与 `pushRegularAppearance` 配对调用。
    static func popRegularAppearance() {
        assert(Thread.isMainThread)
        accessoryDepth = max(0, accessoryDepth - 1)
        if accessoryDepth == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
