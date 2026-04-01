# barTimer

> 一个适用于 macOS 的任务栏自然语言快速倒计时小工具。

在菜单栏直接输入「20min」「1h30m」即可开始计时，无需打开完整应用。

🔗 **[GitHub Releases](https://github.com/AidenYang1/barTimer/releases)**

---

## ✨ 功能特性

- **自然语言输入**：支持「20min」「1h30m」「90s」等格式
- **事件绑定**：输入「20min @开会」或「20min 开会」，计时与事件名称关联
- **菜单栏实时显示**：最近计时器的剩余时间直接显示在菜单栏
- **历史记录**：查看过去所有计时记录
- **统计数据**：按事件类型统计时间分配
- **日历集成**：计时事件可同步到系统日历
- **iCloud 同步**：计时数据跨设备同步
- **提示音**：计时结束时播放提示音，支持音量调节
- **倒计时滴答音**：可开启滴答声增强专注感
- **系统通知**：计时结束时弹出系统通知
- **防止睡眠**：计时期间可阻止系统进入睡眠
- **登录自动启动**：支持开机自启
- **多语言**：支持简体中文 / English，跟随系统
- **自动更新**：内置 Sparkle 更新框架，一键下载安装新版本

---

## 💻 环境要求

- macOS 13.0 及以上
- Xcode 15+（源码构建）

---

## 🚀 安装方式

1. 前往 [Releases](https://github.com/AidenYang1/barTimer/releases) 下载最新版本的 `.dmg`
2. 打开 `.dmg`，将 `barTimer.app` 拖入 Applications 文件夹
3. 运行 app，在菜单栏根据提示授予日历权限即可使用

---

## 🛠️ 技术栈

| 模块 | 技术 |
|---|---|
| 语言 | Swift 5 / SwiftUI |
| 更新框架 | Sparkle 2.x |
| 日历 | EventKit |
| 通知 | UserNotifications |
| 持久化 | UserDefaults / iCloud NSUbiquitousKeyValueStore |

---

## 📦 发版流程（开发者）

1. 改代码 → Xcode 修改版本号（General → Version）
2. `Product → Archive → Export` → 制作 `.dmg`
3. GitHub 发布 Release，上传 `.dmg`
4. 运行脚本自动更新 appcast 并推送：

```bash
./release.sh 1.0.1 "/path/to/barTimer_1.0.1.dmg"
```

---

## 📄 License

MIT License © 2026 AidenYang
