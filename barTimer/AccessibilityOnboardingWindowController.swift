import AppKit
import SwiftUI

final class AccessibilityOnboardingWindowController: NSObject, NSWindowDelegate {
  static let shared = AccessibilityOnboardingWindowController()
  private var window: NSWindow?
  private var hostingView: NSHostingView<AnyView>?
  private var statusTimer: DispatchSourceTimer?

  func showIfNeeded() {
    if GlobalHotkeyManager.isAccessibilityTrusted() { return }
    showWindow()
  }

  func showWindow() {
    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let newWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    newWindow.center()
    newWindow.title = NSLocalizedString("启用全局快捷键响应", comment: "Accessibility onboarding window title")
    newWindow.isReleasedWhenClosed = false
    newWindow.delegate = self
    newWindow.level = .floating

    let root = AccessibilityOnboardingView(
      onOpenSettings: { [weak self] in
        GlobalHotkeyManager.requestAccessibilityIfNeeded()
        GlobalHotkeyManager.openAccessibilitySettings()
        self?.refreshStatus()
      },
      isTrusted: GlobalHotkeyManager.isAccessibilityTrusted()
    )
    hostingView = NSHostingView(rootView: AnyView(root))
    newWindow.contentView = hostingView

    window = newWindow
    newWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    startStatusPolling()
  }

  func closeWindow() {
    stopStatusPolling()
    window?.close()
    window = nil
    hostingView = nil
  }

  func windowWillClose(_ notification: Notification) {
    stopStatusPolling()
    window = nil
    hostingView = nil
  }

  private func startStatusPolling() {
    stopStatusPolling()
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 0.3, repeating: 0.5)
    timer.setEventHandler { [weak self] in
      self?.refreshStatus()
    }
    timer.resume()
    statusTimer = timer
  }

  private func stopStatusPolling() {
    statusTimer?.cancel()
    statusTimer = nil
  }

  private func refreshStatus() {
    let trusted = GlobalHotkeyManager.isAccessibilityTrusted()

    if trusted {
      GlobalHotkeyManager.shared.startMonitoring()
      closeWindow()
      return
    }

    guard let window else { return }
    let root = AccessibilityOnboardingView(
      onOpenSettings: { [weak self] in
        GlobalHotkeyManager.requestAccessibilityIfNeeded()
        GlobalHotkeyManager.openAccessibilitySettings()
        self?.refreshStatus()
      },
      isTrusted: false
    )
    hostingView = NSHostingView(rootView: AnyView(root))
    window.contentView = hostingView
  }
}
