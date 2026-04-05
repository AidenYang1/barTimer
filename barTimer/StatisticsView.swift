import SwiftUI
import AppKit
import Charts

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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
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
        newWindow.minSize = NSSize(width: 760, height: 460)
        
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

    private enum StatMode {
        case time
        case event
        case detail
    }

    private enum TimeNav {
        case yesterday
        case today
        case specific
    }

    @State private var mode: StatMode = .time
    @State private var selectedEventName: String?

    // 时间统计导航
    @State private var timeNav: TimeNav = .today
    @State private var specificDate: Date = Date()
    @State private var isSpecificDatePopoverPresented = false

    // 搜索
    @State private var isSearchPresented = false
    @State private var searchText: String = ""
    @State private var hoveredEventName: String?
    @State private var hoveredPieRecord: EventRecord?
    @State private var hoveredPieLocation: CGPoint = .zero
    @FocusState private var isSearchFieldFocused: Bool

    // 详情悬停
    @State private var hoveredDetailEntry: EventEntry?
    @State private var hoveredDetailLocation: CGPoint = .zero

    private let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    private let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if mode != .detail {
                        overviewSection
                        modeToggleSection

                        if isSearchPresented {
                            searchSection
                        }
                    }

                    if mode == .detail, let selectedEventName {
                        detailSection(eventName: selectedEventName)
                    } else {
                        switch mode {
                        case .time:
                            timeBreakdownSection
                        case .event:
                            eventBreakdownSection
                        case .detail:
                            EmptyView()
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 760, minHeight: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - 顶栏
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text(NSLocalizedString("统计", comment: "Statistics header"))
                    .font(.title2.bold())

                Spacer()

                if mode == .detail {
                    Button(NSLocalizedString("返回", comment: "Back from detail")) {
                        mode = .event
                        selectedEventName = nil
                        isSearchPresented = false
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    isSearchPresented.toggle()
                    if isSearchPresented {
                        isSearchFieldFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button(NSLocalizedString("完成", comment: "Done button")) {
                    windowDelegate.closeWindow()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

        }
        .padding(.vertical, 12)
    }

    private var modeToggleSection: some View {
        HStack(spacing: 12) {
            modeToggleButton(
                title: NSLocalizedString("按时间统计", comment: "Time stats"),
                active: mode == .time
            ) {
                mode = .time
                selectedEventName = nil
            }

            modeToggleButton(
                title: NSLocalizedString("按事件统计", comment: "Event stats"),
                active: mode == .event
            ) {
                mode = .event
                selectedEventName = nil
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func modeToggleButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? .white : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(active ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 概览
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("概览", comment: "Overview section title"))
                .font(.headline)

            HStack(spacing: 12) {
                    StatCard(
                    value: "\(eventStore.todayCount)",
                    label: NSLocalizedString("今日次数", comment: "Today count"),
                    comparison: todayComparisonText
                )
                StatCard(
                    value: "\(eventStore.totalCount)",
                    label: NSLocalizedString("总次数", comment: "Total count"),
                    comparison: nil
                )
                StatCard(
                    value: EventStore.formatDurationCompact(eventStore.todayDuration),
                    label: NSLocalizedString("今日限定时长", comment: "Today duration"),
                    comparison: nil
                )
                StatCard(
                    value: EventStore.formatDurationCompact(eventStore.totalDuration),
                    label: NSLocalizedString("总限定时长", comment: "Total duration"),
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
            return String(
                format: NSLocalizedString("STATS_MORE_THAN_YESTERDAY_FORMAT", comment: "More than yesterday"),
                locale: Locale.current,
                diff
            )
        }
        if diff < 0 {
            return String(
                format: NSLocalizedString("STATS_LESS_THAN_YESTERDAY_FORMAT", comment: "Less than yesterday"),
                locale: Locale.current,
                -diff
            )
        }
        return nil
    }

    // MARK: - 按时间统计
    private var timeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("按时间统计", comment: "Time stats section"))
                .font(.headline)

            timeNavBar

            Divider()
                .padding(.vertical, 4)

            if timeEvents.isEmpty {
                Text(NSLocalizedString("暂无数据", comment: "No data"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    // 固定表头
                    HStack(spacing: 12) {
                        Text(NSLocalizedString("事件名", comment: "Event name header"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)

                        Text(NSLocalizedString("时长", comment: "Duration header"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .center)

                        Spacer(minLength: 0)

                        Text(NSLocalizedString("次数", comment: "Count header"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.bottom, 2)

                    Divider()

                    VStack(spacing: 6) {
                        ForEach(timeEvents) { row in
                            HStack(spacing: 12) {
                                Text(row.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer(minLength: 0)

                                Text(EventStore.formatDuration(row.duration))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 140, alignment: .center)

                                Spacer(minLength: 0)

                                Text("\(row.count)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
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

    private var timeNavBar: some View {
        HStack(spacing: 12) {
            timeNavButton(NSLocalizedString("昨天", comment: "Yesterday"), active: timeNav == .yesterday) { timeNav = .yesterday }
            timeNavButton(NSLocalizedString("今天", comment: "Today (nav)"), active: timeNav == .today) { timeNav = .today }
            timeNavButton(NSLocalizedString("特定时间", comment: "Specific date"), active: timeNav == .specific) {
                timeNav = .specific
                isSpecificDatePopoverPresented = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .popover(isPresented: $isSpecificDatePopoverPresented) {
            VStack(spacing: 12) {
                Text(NSLocalizedString("选择日期", comment: "Choose date"))
                    .font(.headline)

                DatePicker(
                    NSLocalizedString("日期", comment: "Date label"),
                    selection: $specificDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)

                Button(NSLocalizedString("确定", comment: "Confirm date")) {
                    isSpecificDatePopoverPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(width: 320)
        }
    }

    private func timeNavButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? .white : .primary)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(active ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private struct TimeEventRow: Identifiable {
        let id = UUID()
        let name: String
        let latestDate: Date
        let duration: TimeInterval
        let count: Int
    }

    private var activeTimeDate: Date {
        let calendar = Calendar.current
        switch timeNav {
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .today:
            return Date()
        case .specific:
            return specificDate
        }
    }

    private var timeEvents: [TimeEventRow] {
        let calendar = Calendar.current
        let targetDate = activeTimeDate
        let dayEvents = eventStore.records.compactMap { record -> TimeEventRow? in
            let dayEntries = record.entries.filter { calendar.isDate($0.date, inSameDayAs: targetDate) }
            guard !dayEntries.isEmpty else { return nil }
            let latest = dayEntries.max(by: { $0.date < $1.date })!
            let duration = dayEntries.reduce(0) { $0 + $1.duration }
            return TimeEventRow(name: record.name, latestDate: latest.date, duration: duration, count: dayEntries.count)
        }

        return dayEvents.sorted(by: { $0.latestDate > $1.latestDate })
    }

    // MARK: - 按事件统计（饼图 + 条形图）
    private var eventBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("按事件统计", comment: "By event section"))
                .font(.headline)

            if eventStore.records.isEmpty {
                Text(NSLocalizedString("暂无数据", comment: "No data"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    pieChartSection
                        .frame(width: 240)

                    VStack(alignment: .leading, spacing: 10) {
                        barChartSection
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var palette: [Color] {
        [
            Color(red: 0.34, green: 0.62, blue: 0.86),
            Color(red: 0.36, green: 0.74, blue: 0.52),
            Color(red: 0.92, green: 0.66, blue: 0.34),
            Color(red: 0.70, green: 0.48, blue: 0.86),
            Color(red: 0.86, green: 0.42, blue: 0.62),
            Color(red: 0.36, green: 0.72, blue: 0.72),
            Color(red: 0.50, green: 0.56, blue: 0.86),
            Color(red: 0.48, green: 0.78, blue: 0.84),
            Color(red: 0.72, green: 0.58, blue: 0.44),
            Color(red: 0.84, green: 0.44, blue: 0.44)
        ]
    }

    private var eventItemsSorted: [EventRecord] {
        eventStore.records.sorted(by: { $0.totalDuration > $1.totalDuration })
    }

    private func itemColor(_ item: EventRecord) -> Color {
        guard let idx = eventItemsSorted.firstIndex(where: { $0.id == item.id }) else { return .accentColor }
        return palette[idx % palette.count]
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("搜索", comment: "Search title"))
                .font(.headline)
            searchPanel
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // 搜索面板（候选框 + 回车进入）
    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(NSLocalizedString("搜索事件名称…", comment: "Search field placeholder"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    if let first = searchSuggestions.first {
                        openDetail(for: first)
                    }
                }

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !searchSuggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(searchSuggestions) { record in
                            Button {
                                openDetail(for: record)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(itemColor(record))
                                        .frame(width: 8, height: 8)
                                    Text(record.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text("x\(record.entries.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 160)
            }
        }
    }

    private var searchSuggestions: [EventRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return eventItemsSorted.filter { $0.name.lowercased().contains(q) }
    }

    private func openDetail(for record: EventRecord) {
        selectedEventName = record.name
        mode = .detail
        isSearchPresented = false
        searchText = ""
        hoveredDetailEntry = nil
    }

    private var pieChartSection: some View {
        ZStack(alignment: .topLeading) {
            Chart(eventItemsSorted, id: \.id) { record in
                let angleValue = record.totalDuration
                SectorMark(
                    angle: .value("Duration", max(angleValue, 0.0001))
                )
                .foregroundStyle(itemColor(record))
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let plotFrame = proxy.plotFrame.map({ geo[$0] }) {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let hoveredPieRecord {
                                    selectedEventName = hoveredPieRecord.name
                                    mode = .detail
                                }
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case let .active(location):
                                    hoveredPieLocation = location
                                    let cx = plotFrame.midX
                                    let cy = plotFrame.midY
                                    let dx = location.x - cx
                                    let dy = location.y - cy
                                    let distance = sqrt(dx * dx + dy * dy)
                                    let radius = min(plotFrame.width, plotFrame.height) / 2
                                    guard distance <= radius, radius > 0, !eventItemsSorted.isEmpty else {
                                        hoveredEventName = nil
                                        hoveredPieRecord = nil
                                        return
                                    }

                                    var angle = atan2(dy, dx)
                                    if angle < 0 { angle += 2 * .pi }

                                    let total = eventItemsSorted.reduce(0) { $0 + max($1.totalDuration, 0) }
                                    guard total > 0 else {
                                        hoveredEventName = nil
                                        hoveredPieRecord = nil
                                        return
                                    }

                                    var current = 0.0
                                    for record in eventItemsSorted {
                                        let v = max(record.totalDuration, 0)
                                        let sweep = v / total * 2 * .pi
                                        let next = current + sweep
                                        if angle >= current && angle < next {
                                            hoveredEventName = record.name
                                            hoveredPieRecord = record
                                            return
                                        }
                                        current = next
                                    }
                                    hoveredEventName = nil
                                    hoveredPieRecord = nil
                                case .ended:
                                    hoveredPieRecord = nil
                                @unknown default:
                                    break
                                }
                            }
                    } else {
                        Rectangle().fill(Color.clear)
                    }
                }
            }
            .frame(width: 220, height: 220)

            if let hoveredPieRecord {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hoveredPieRecord.name)
                        .font(.caption)
                        .foregroundStyle(.white)
                    Text(
                        String(
                            format: NSLocalizedString("时长_FORMAT", comment: "Tooltip duration"),
                            EventStore.formatDuration(hoveredPieRecord.totalDuration)
                        )
                    )
                        .font(.caption2)
                        .foregroundStyle(.white)
                    Text(
                        String(
                            format: NSLocalizedString("次数_FORMAT", comment: "Tooltip count"),
                            hoveredPieRecord.entries.count
                        )
                    )
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.75))
                )
                .position(x: min(max(hoveredPieLocation.x + 90, 90), 200), y: max(hoveredPieLocation.y - 20, 20))
            }
        }
    }

    private var barChartSection: some View {
        Chart(eventItemsSorted, id: \.id) { record in
            BarMark(
                x: .value("Duration", record.totalDuration),
                y: .value("Event", record.name)
            )
            .foregroundStyle(itemColor(record))
            .cornerRadius(3)
            .annotation(position: .top) {
                VStack(spacing: 2) {
                    Text(record.name)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(itemColor(record).opacity(0.9))
                        )
                    Text("x\(record.entries.count)")
                        .font(.caption2)
                        .foregroundStyle(itemColor(record))
                        .padding(.top, 1)
                }
            }
        }
        .chartYScale(domain: eventItemsSorted.map { $0.name })
        .frame(height: 260)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame.map({ geo[$0] }) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case let .active(location):
                                guard !eventItemsSorted.isEmpty else { return }
                                let relativeY = (location.y - plotFrame.minY) / plotFrame.height
                                guard relativeY >= 0, relativeY <= 1 else {
                                    hoveredEventName = nil
                                    return
                                }
                                let idx = min(max(Int(floor(relativeY * Double(eventItemsSorted.count))), 0), eventItemsSorted.count - 1)
                                hoveredEventName = eventItemsSorted[idx].name
                            case .ended:
                                break
                            @unknown default:
                                break
                            }
                        }
                        .onTapGesture {
                            if let hoveredEventName {
                                selectedEventName = hoveredEventName
                                mode = .detail
                            }
                        }
                } else {
                    Rectangle().fill(Color.clear)
                }
            }
        }
    }

    // MARK: - 具体统计详情（折线图 + 悬停）
    private func detailSection(eventName: String) -> some View {
        let record = eventStore.records.first(where: { $0.name == eventName })
        let entries = record?.entries.sorted(by: { $0.date < $1.date }) ?? []
        let totalDuration = record?.totalDuration ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eventName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(EventStore.formatDuration(totalDuration))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
            }

            if entries.isEmpty {
                Text(NSLocalizedString("暂无数据", comment: "No data"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                detailLineChart(entries: entries, accent: .blue)
                    .frame(height: 320)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func detailLineChart(entries: [EventEntry], accent: Color) -> some View {
        let minDate = entries.first?.date ?? Date()
        let maxDate = entries.last?.date ?? Date()

        return ZStack(alignment: .topLeading) {
            Chart(entries) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Duration", entry.duration)
                )
                .foregroundStyle(accent)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Duration", entry.duration)
                )
                .foregroundStyle(accent)
            }
            .chartXScale(domain: minDate...maxDate)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(EventStore.formatDuration(v))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case let .active(location):
                                // 用 X 坐标反推日期，再找最接近的点做 tooltip。
                                if let hoveredDate = proxy.value(atX: location.x, as: Date.self) {
                                    if let closest = entries.min(by: { abs($0.date.timeIntervalSince(hoveredDate)) < abs($1.date.timeIntervalSince(hoveredDate)) }) {
                                        hoveredDetailEntry = closest
                                        hoveredDetailLocation = location
                                    }
                                }
                            case .ended:
                                hoveredDetailEntry = nil
                            @unknown default:
                                break
                            }
                        }
                }
            }

            if let hoveredDetailEntry {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detailDateFormatter.string(from: hoveredDetailEntry.date))
                        .font(.caption)
                        .foregroundStyle(.white)
                    Text(
                        String(
                            format: NSLocalizedString("时长_FORMAT", comment: "Tooltip duration"),
                            EventStore.formatDuration(hoveredDetailEntry.duration)
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.75))
                )
                .position(x: hoveredDetailLocation.x, y: max(20, hoveredDetailLocation.y))
            }
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
