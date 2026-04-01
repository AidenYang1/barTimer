import Foundation
import AppKit

class UpdateChecker: ObservableObject {
    // TODO: 填入你的 GitHub 仓库地址，格式: "owner/repo"
    static let githubRepo = "OWNER/REPO"
    
    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var isNewVersionAvailable = false
    
    // 当前应用版本号
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    // 检查更新
    func checkForUpdate() {
        let urlString = "https://api.github.com/repos/\(Self.githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String,
                   let htmlURL = json["html_url"] as? String {
                    
                    // 去掉版本号前缀 "v"
                    let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                    
                    DispatchQueue.main.async {
                        self.latestVersion = remoteVersion
                        self.downloadURL = htmlURL
                        self.isNewVersionAvailable = self.isNewer(remoteVersion, than: self.currentVersion)
                        
                        if self.isNewVersionAvailable {
                            self.showUpdateAlert(newVersion: remoteVersion, downloadURL: htmlURL)
                        }
                    }
                }
            } catch {
                print("解析更新信息失败: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // 比较版本号
    private func isNewer(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteParts.count, currentParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
    
    // 弹出更新提示
    private func showUpdateAlert(newVersion: String, downloadURL: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("发现新版本", comment: "Update available alert title")
        alert.informativeText = String(
            format: NSLocalizedString("UPDATE_ALERT_INFO_FORMAT", comment: "Update available alert body"),
            locale: AppLanguage.currentLocale,
            newVersion,
            currentVersion
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("前往下载", comment: "Update alert download button"))
        alert.addButton(withTitle: NSLocalizedString("稍后再说", comment: "Update alert later button"))
        if alert.buttons.count > 1 {
            let cancelButton = alert.buttons[1]
            cancelButton.hasDestructiveAction = true
            cancelButton.bezelColor = .systemRed
            cancelButton.contentTintColor = .white
        }
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: downloadURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
