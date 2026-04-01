import SwiftUI
import AppKit

// 统计窗口控制器
class StatisticsWindowController: NSObject, NSWindowDelegate {
    static let shared = StatisticsWindowController()
    private var hostingView: NSHostingView<AnyView>?
    var window: NSWindow?
    
    func showWindow(eventStore: EventStore) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let view = StatisticsView(windowDelegate: self)
            .environmentObject(eventStore)
        
        let anyView = AnyView(view)
        hostingView = NSHostingView(rootView: anyView)
        
        newWindow.contentView = hostingView
        newWindow.title = NSLocalizedString("统计", comment: "Statistics window title")
        newWindow.center()
        newWindow.level = .floating
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 420, height: 400)
        
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

// 统计视图
struct StatisticsView: View {
    @EnvironmentObject var eventStore: EventStore
    let windowDelegate: StatisticsWindowController
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                Text("统计")
                    .font(.title2.bold())
                Spacer()
                Button("完成") {
                    windowDelegate.closeWindow()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 概览卡片
                    overviewSection
                    
                    // 按事件统计
                    eventBreakdownSection
                    
                    // 最近记录
                    recentEntriesSection
                }
                .padding()
            }
        }
        .frame(minWidth: 420, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 概览
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("概览")
                .font(.headline)
            
            HStack(spacing: 12) {
                StatCard(
                    value: "\(eventStore.todayCount)",
                    label: "今日次数",
                    comparison: todayComparisonText
                )
                StatCard(
                    value: "\(eventStore.totalCount)",
                    label: "总次数",
                    comparison: nil
                )
                StatCard(
                    value: EventStore.formatDurationCompact(eventStore.todayDuration),
                    label: "今日限定时长",
                    comparison: nil
                )
                StatCard(
                    value: EventStore.formatDurationCompact(eventStore.totalDuration),
                    label: "总限定时长",
                    comparison: nil
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var todayComparisonText: String? {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayCount = eventStore.allEntries.filter { calendar.isDate($0.date, inSameDayAs: yesterday) }.count
        let diff = eventStore.todayCount - yesterdayCount
        if diff > 0 {
            return "比昨天多\(diff)个"
        } else if diff < 0 {
            return "比昨天少\(-diff)个"
        }
        return nil
    }
    
    // MARK: - 按事件统计
    
    private var eventBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按事件统计")
                .font(.headline)
            
            if eventStore.records.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(eventStore.records.sorted(by: { $0.totalDuration > $1.totalDuration })) { record in
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text(record.name)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(
                            String(
                                format: NSLocalizedString("STATS_EVENT_COUNT_FORMAT", comment: ""),
                                locale: AppLanguage.currentLocale,
                                record.entries.count
                            )
                        )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(EventStore.formatDuration(record.totalDuration))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                    
                    if record.id != eventStore.records.sorted(by: { $0.totalDuration > $1.totalDuration }).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - 最近记录
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("限定记录")
                .font(.headline)
            
            let recentEntries = allEntriesWithNames
                .sorted { $0.entry.date > $1.entry.date }
                .prefix(10)
            
            if recentEntries.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(recentEntries), id: \.entry.id) { item in
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text(dateFormatter.string(from: item.entry.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.name)
                            .font(.system(size: 14))
                        Spacer()
                        Text(EventStore.formatDuration(item.entry.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // 辅助：带事件名的条目列表
    private var allEntriesWithNames: [(name: String, entry: EventEntry)] {
        eventStore.records.flatMap { record in
            record.entries.map { (name: record.name, entry: $0) }
        }
    }
}

// 统计卡片组件
struct StatCard: View {
    let value: String
    let label: String
    let comparison: String?
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            if let comparison {
                Text(comparison)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    StatisticsView(windowDelegate: StatisticsWindowController.shared)
        .environmentObject(EventStore())
}
