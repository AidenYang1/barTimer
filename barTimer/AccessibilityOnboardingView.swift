import SwiftUI

struct AccessibilityOnboardingView: View {
  let onOpenSettings: () -> Void
  let isTrusted: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(NSLocalizedString("需要开启辅助功能权限", comment: "Accessibility permission required title"), systemImage: "keyboard.badge.ellipsis")
        .font(.system(size: 24, weight: .semibold))

      Image(systemName: "accessibility.fill")
        .font(.system(size: 32, weight: .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .padding(.top, -4)

      Text(NSLocalizedString("barTimer 使用全局快捷键来快速呼出限定计时框（例如在任意应用中按下快捷键即可记录倒计时）。", comment: "Accessibility onboarding description 1"))
        .font(.system(size: 15))
        .foregroundStyle(.secondary)

      Text(NSLocalizedString("macOS 要求这类全局键盘监听必须获得“辅助功能”授权。不开启时，快捷键会按下无效，可能只听到系统提示音。", comment: "Accessibility onboarding description 2"))
        .font(.system(size: 15))
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        Image(systemName: isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundStyle(isTrusted ? .green : .orange)
        Text(isTrusted
              ? NSLocalizedString("当前状态：已授权，正在进入应用...", comment: "Accessibility granted status line")
              : NSLocalizedString("当前状态：未授权（未授权时无法继续使用）", comment: "Accessibility not granted status line"))
          .font(.system(size: 14, weight: .medium))
      }
      .padding(.vertical, 4)

      HStack(spacing: 12) {
        Label(NSLocalizedString("仅用于监听你设置的快捷键", comment: "Privacy statement - hotkeys only"), systemImage: "checkmark.shield")
        Label(NSLocalizedString("不会用于其他用途", comment: "Privacy statement - not used elsewhere"), systemImage: "lock")
      }
      .font(.system(size: 13))
      .foregroundStyle(.secondary)
      .padding(.top, 2)

      Spacer()

      HStack {
        Button(NSLocalizedString("去设置并启用", comment: "Open settings button")) { onOpenSettings() }
          .buttonStyle(.borderedProminent)
        Spacer()
        Text(NSLocalizedString("授权后将自动继续", comment: "Continue after enabling text"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(NSColor.windowBackgroundColor))
  }
}

#Preview("未授权") {
  AccessibilityOnboardingView(
    onOpenSettings: {},
    isTrusted: false
  )
  .frame(width: 560, height: 360)
}

#Preview("已授权") {
  AccessibilityOnboardingView(
    onOpenSettings: {},
    isTrusted: true
  )
  .frame(width: 560, height: 360)
}
