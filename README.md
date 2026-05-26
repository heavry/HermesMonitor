# Hermes Monitor

macOS 浮窗桌面组件，实时监控 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 的任务状态。

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能

- 🟢 实时任务状态监控（活跃/空闲/已结束）
- 📊 进度条显示（基于工具调用计数的对数算法）
- 🔄 多任务列表，一键切换
- 📁 文件拖拽发送给 Hermes 分析
- ❓ 内置提问功能（直接问 Agent 当前情况）
- 🩺 Watcher 守护进程健康检查 + 自动重启
- 🪟 毛玻璃悬浮窗，始终置顶，跨桌面显示

## 安装

### 预编译版本

从 [Releases](https://github.com/heavry/HermesMonitor/releases) 下载 `Hermes Monitor.app`，拖入 `/Applications` 即可。

### 从源码构建

```bash
git clone https://github.com/heavry/HermesMonitor.git
cd HermesMonitor
xcodebuild -project HermesMonitor.xcodeproj -scheme HermesMonitor -configuration Release build
cp -R build/Build/Products/Release/Hermes\ Monitor.app /Applications/
```

## 依赖

- macOS 14.0+
- [Hermes Agent](https://github.com/NousResearch/hermes-agent)（已安装且在 PATH 中）
- `~/.hermes/activity_watcher.py` 守护进程（自动检测，也可由 app 自动拉起）

## 架构

```
~/.hermes/sessions/*.json  →  activity_watcher.py  →  ~/.hermes/status.json
                                                          ↓
                                              Hermes Monitor.app (悬浮窗)
```

- DispatchSource + 1.5s 轮询双重监听 `status.json`
- 文件描述符自动重建（监听 delete/rename 事件）
- 安全的 Process.arguments 调用（无 shell 注入风险）

## 截图

<img width="320" alt="Hermes Monitor" src="https://github.com/heavry/HermesMonitor/assets/screenshot.png">

## License

MIT
