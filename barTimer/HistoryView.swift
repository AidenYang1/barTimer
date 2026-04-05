import SwiftUI
import AppKit

// 历史记录窗口控制器
class HistoryWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryWindowController()
    private var hostingView: NSHostingView<AnyView>?
    var window: NSWindow?
    
    func showWindow(eventStore: EventStore) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let historyView = HistoryView(windowDelegate: self)
            .environmentObject(eventStore)
        
        let anyView = AnyView(historyView)
        hostingView = NSHostingView(rootView: anyView)
        
        newWindow.contentView = hostingView
        newWindow.title = NSLocalizedString("今日历史限定", comment: "History window title")
        newWindow.center()
        newWindow.level = .floating
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 350, height: 300)
        
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    func closeWindow() {
        guard let windowToClose = window else { return }
        DispatchQueue.main.async { [weak self] in
            windowToClose.delegate = nil
            windowToClose.close()
            self?.window = nil
            self?.hostingView = nil
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window = nil
        hostingView = nil
    }
}

// 历史记录视图
struct HistoryView: View {
    @EnvironmentObject var eventStore: EventStore
    let windowDelegate: HistoryWindowController
    @State private var selectedRecord: EventRecord?

    private var todayRecords: [EventRecord] {
        let calendar = Calendar.current
        return eventStore.records.compactMap { record in
            let todayEntries = record.entries.filter { calendar.isDateInToday($0.date) }
            guard !todayEntries.isEmpty else { return nil }
            var copy = record
            copy.entries = todayEntries
            copy.lastUsed = todayEntries.map(\.date).max() ?? record.lastUsed
            return copy
        }
        .sorted(by: { $0.lastUsed > $1.lastUsed })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if todayRecords.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("今天还没有历史限定", comment: "No history today"))
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("使用 @ 语法关联事件，如：30分@写代码", comment: "Use @ syntax hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // 事件列表
                List {
                    ForEach(todayRecords) { record in
                        EventRowView(record: record, isExpanded: selectedRecord?.id == record.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedRecord?.id == record.id {
                                        selectedRecord = nil
                                    } else {
                                        selectedRecord = record
                                    }
                                }
                            }
                    }
                    .onDelete { indexSet in
                        let sorted = todayRecords
                        for index in indexSet {
                            eventStore.deleteRecord(id: sorted[index].id)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 350, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottomLeading) {
            Button(action: {
                StatisticsWindowController.shared.showWindow(eventStore: eventStore)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                    Text(NSLocalizedString("历史统计", comment: "History stats button title"))
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .padding(12)
        }
    }
}

// 单个事件行
struct EventRowView: View {
    let record: EventRecord
    let isExpanded: Bool
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()
    
    var body: some View {
        let todayCount = record.entries.count
        let todayDuration = record.entries.reduce(0) { $0 + $1.duration }

        VStack(alignment: .leading, spacing: 8) {
            // 主行
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name)
                        .font(.system(size: 15, weight: .medium))
                    Text(
                        String(
                            format: NSLocalizedString("HISTORY_TOTAL_COUNT_FORMAT", comment: "History total count"),
                            locale: Locale.current,
                            todayCount
                        )
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(EventStore.formatDuration(todayDuration))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.orange)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 展开的详情
            if isExpanded {
                Divider()
                ForEach(record.entries.sorted(by: { $0.date > $1.date })) { entry in
                    HStack {
                        Text(dateFormatter.string(from: entry.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(EventStore.formatDuration(entry.duration))
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView(windowDelegate: HistoryWindowController.shared)
        .environmentObject(EventStore())
}
