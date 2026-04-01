import Foundation

// 单次计时记录
struct EventEntry: Codable, Identifiable {
    let id: UUID
    let duration: TimeInterval
    let date: Date
    
    init(duration: TimeInterval, date: Date = Date()) {
        self.id = UUID()
        self.duration = duration
        self.date = date
    }
}

// 事件记录（包含所有同名计时的累积）
struct EventRecord: Codable, Identifiable {
    let id: UUID
    var name: String
    var entries: [EventEntry]
    var lastUsed: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.entries = []
        self.lastUsed = Date()
    }
    
    var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }
}

class EventStore: ObservableObject {
    @Published var records: [EventRecord] = []
    
    private let fileURL: URL
    private var iCloudEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableiCloudSync")
    }
    
    init() {
        // 存储到 Application Support 目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("barTimer", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        fileURL = appDir.appendingPathComponent("event_history.json")
        loadRecords()
        
        // 设置 iCloud 监听
        setupiCloudObserver()
    }
    
    // MARK: - iCloud 同步
    
    private func setupiCloudObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        // 首次同步
        if iCloudEnabled {
            NSUbiquitousKeyValueStore.default.synchronize()
            loadFromiCloud()
        }
    }
    
    @objc private func iCloudDataChanged(_ notification: Notification) {
        guard iCloudEnabled else { return }
        DispatchQueue.main.async { [weak self] in
            self?.loadFromiCloud()
        }
    }
    
    private func syncToiCloud() {
        guard iCloudEnabled else { return }
        do {
            let data = try JSONEncoder().encode(records)
            NSUbiquitousKeyValueStore.default.set(data, forKey: "event_records")
            NSUbiquitousKeyValueStore.default.synchronize()
        } catch {
            print("iCloud 同步失败: \(error.localizedDescription)")
        }
    }
    
    private func loadFromiCloud() {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: "event_records"),
              let cloudRecords = try? JSONDecoder().decode([EventRecord].self, from: data) else { return }
        mergeRecords(from: cloudRecords)
    }
    
    private func mergeRecords(from cloudRecords: [EventRecord]) {
        var changed = false
        for cloudRecord in cloudRecords {
            if let localIndex = records.firstIndex(where: { $0.name == cloudRecord.name }) {
                let localEntryIds = Set(records[localIndex].entries.map { $0.id })
                let newEntries = cloudRecord.entries.filter { !localEntryIds.contains($0.id) }
                if !newEntries.isEmpty {
                    records[localIndex].entries.append(contentsOf: newEntries)
                    changed = true
                }
                if cloudRecord.lastUsed > records[localIndex].lastUsed {
                    records[localIndex].lastUsed = cloudRecord.lastUsed
                    changed = true
                }
            } else {
                records.append(cloudRecord)
                changed = true
            }
        }
        if changed {
            saveToLocal()
        }
    }
    
    /// 手动触发 iCloud 全量上传（开启同步时调用）
    func forceUploadToiCloud() {
        do {
            let data = try JSONEncoder().encode(records)
            NSUbiquitousKeyValueStore.default.set(data, forKey: "event_records")
            NSUbiquitousKeyValueStore.default.synchronize()
        } catch {
            print("iCloud 上传失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD
    
    // 添加一次计时记录到指定事件
    func addEntry(name: String, duration: TimeInterval) {
        let entry = EventEntry(duration: duration)
        
        if let index = records.firstIndex(where: { $0.name == name }) {
            records[index].entries.append(entry)
            records[index].lastUsed = Date()
        } else {
            var record = EventRecord(name: name)
            record.entries.append(entry)
            records.append(record)
        }
        
        saveRecords()
    }
    
    // 返回最近使用的事件名（按 lastUsed 降序）
    func recentEventNames(limit: Int = 5) -> [String] {
        records
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(limit)
            .map { $0.name }
    }
    
    // 删除事件记录
    func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
        saveRecords()
    }
    
    // MARK: - 统计
    
    /// 所有条目（跨事件扁平化）
    var allEntries: [EventEntry] {
        records.flatMap { $0.entries }
    }
    
    /// 今日条目
    var todayEntries: [EventEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDateInToday($0.date) }
    }
    
    /// 今日计时次数
    var todayCount: Int { todayEntries.count }
    
    /// 总计时次数
    var totalCount: Int { allEntries.count }
    
    /// 今日限定时长
    var todayDuration: TimeInterval {
        todayEntries.reduce(0) { $0 + $1.duration }
    }
    
    /// 总限定时长
    var totalDuration: TimeInterval {
        allEntries.reduce(0) { $0 + $1.duration }
    }
    
    // MARK: - 持久化
    
    private func saveRecords() {
        saveToLocal()
        syncToiCloud()
    }
    
    private func saveToLocal() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL)
        } catch {
            print("保存事件记录失败: \(error.localizedDescription)")
        }
    }
    
    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([EventRecord].self, from: data)
        } catch {
            print("加载事件记录失败: \(error.localizedDescription)")
        }
    }
    
    // 格式化累积时间
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return String(
                format: NSLocalizedString("TIME_FORMAT_H_M", comment: "Time format for hours and minutes"),
                locale: AppLanguage.currentLocale,
                hours,
                minutes
            )
        } else {
            return String(
                format: NSLocalizedString("TIME_FORMAT_MINUTES", comment: "Time format for minutes"),
                locale: AppLanguage.currentLocale,
                max(minutes, 1)
            )
        }
    }
    
    /// 格式化为 XhYm 格式（用于统计视图）
    static func formatDurationCompact(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
