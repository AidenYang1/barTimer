import SwiftUI
import AppKit

// MARK: - KeyablePanel

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Controller

class QuickInputWindowController: NSObject {
    static let shared = QuickInputWindowController()

    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?
    weak var timerManager: TimerManager?
    weak var eventStore: EventStore?

    func show(timerManager: TimerManager, eventStore: EventStore) {
        self.timerManager = timerManager
        self.eventStore = eventStore

        if panel?.isVisible == true {
            dismiss()
            return
        }

        previousApp = NSWorkspace.shared.frontmostApplication

        let panelWidth: CGFloat = 560
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let newPanel = KeyablePanel(
            contentRect: NSRect(
                x: screen.midX - panelWidth / 2,
                y: screen.midY - 50,      // 屏幕垂直居中（输入框约 80px 高，偏上一点）
                width: panelWidth,
                height: 200
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.level = .popUpMenu
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = false
        newPanel.hidesOnDeactivate = false
        newPanel.becomesKeyOnlyIfNeeded = false

        let hostingView = NSHostingView(rootView: QuickTimerInputView(
            timerManager: timerManager,
            eventStore: eventStore,
            onDismiss: { [weak self] in self?.dismiss() }
        ))
        newPanel.contentView = hostingView
        panel = newPanel

        // 附属应用下用 activate + 可成为 Key 的 NSPanel 即可聚焦输入；勿切换 activationPolicy，
        // 否则易与 SwiftUI MenuBarExtra 叠加出多余或失灵的状态栏图标。
        NSApp.activate(ignoringOtherApps: true)
        newPanel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        panel?.close()
        panel = nil

        let prev = previousApp
        previousApp = nil

        prev?.activate()
    }
}

// MARK: - SwiftUI View

struct QuickTimerInputView: View {
    let timerManager: TimerManager
    let eventStore: EventStore
    let onDismiss: () -> Void

    @State private var timeInput: String = ""
    @State private var showSuggestions: Bool = false
    @State private var selectedIndex: Int = -1
    @FocusState private var focused: Bool
    @AppStorage("useSpaceForEvent") private var useSpaceForEvent = false
    @StateObject private var keyHandler = SuggestionKeyHandler()

    private var suggestions: [String] {
        if timeInput.contains("@") {
            let parts = timeInput.split(separator: "@", maxSplits: 1)
            let query = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces).lowercased() : ""
            let recent = eventStore.recentEventNames(limit: 5)
            return query.isEmpty ? recent : recent.filter { $0.lowercased().contains(query) }
        }
        if useSpaceForEvent, let spaceIdx = timeInput.firstIndex(of: " ") {
            let timePart = String(timeInput[..<spaceIdx])
            if timerManager.parseTimeDuration(timePart) != nil {
                let eventPart = String(timeInput[timeInput.index(after: spaceIdx)...])
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let recent = eventStore.recentEventNames(limit: 5)
                return eventPart.isEmpty ? recent : recent.filter { $0.lowercased().contains(eventPart) }
            }
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 输入行
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.tertiary)

                TextField(
                    NSLocalizedString("30分@写代码", comment: ""),
                    text: $timeInput
                )
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .focused($focused)
                .onSubmit { submitTimer() }
                .onChange(of: timeInput) { _, newVal in
                    let hasAt = newVal.contains("@")
                    var hasSpace = false
                    if useSpaceForEvent, let si = newVal.firstIndex(of: " ") {
                        hasSpace = timerManager.parseTimeDuration(String(newVal[..<si])) != nil
                    }
                    showSuggestions = hasAt || hasSpace
                    selectedIndex = -1
                }

                if !timeInput.isEmpty {
                    Button(action: { timeInput = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            // 建议列表（有内容时才展开）
            if showSuggestions && !suggestions.isEmpty {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 18)

                VStack(spacing: 2) {
                    ForEach(Array(suggestions.enumerated()), id: \.element) { idx, name in
                        Button(action: { applySuggestion(name) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                Text(name)
                                    .font(.system(size: 14))
                                Spacer()
                                if let rec = eventStore.records.first(where: { $0.name == name }) {
                                    Text(EventStore.formatDuration(rec.totalDuration))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(idx == selectedIndex
                                          ? Color.accentColor.opacity(0.2)
                                          : Color.clear)
                            )
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 14)
        .fixedSize(horizontal: false, vertical: true)  // 高度随内容自适应
        .padding(30)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
            keyHandler.onSelect = { i in
                if i >= 0 && i < suggestions.count {
                    applySuggestion(suggestions[i])
                }
            }
            keyHandler.onSubmit = { submitTimer() }
            keyHandler.start()
        }
        .onDisappear { keyHandler.stop() }
        .onChange(of: showSuggestions) { _, v in
            keyHandler.isActive = v && !suggestions.isEmpty
            if !v { selectedIndex = -1 }
        }
        .onChange(of: suggestions) { _, v in
            keyHandler.suggestionCount = v.count
            keyHandler.isActive = showSuggestions && !v.isEmpty
            selectedIndex = -1
        }
        .onChange(of: keyHandler.selectedIndex) { _, v in selectedIndex = v }
        .onKeyPress(.escape) { onDismiss(); return .handled }
    }

    private func applySuggestion(_ name: String) {
        if let i = timeInput.firstIndex(of: "@") {
            timeInput = String(timeInput[...i]) + name
        } else if useSpaceForEvent, let i = timeInput.firstIndex(of: " ") {
            timeInput = String(timeInput[...i]) + name
        }
        showSuggestions = false
        selectedIndex = -1
        keyHandler.selectedIndex = -1
    }

    private func submitTimer() {
        if let result = timerManager.parseTimeInput(timeInput) {
            timerManager.addTimer(duration: result.duration, eventName: result.eventName)
            onDismiss()
        }
    }
}
