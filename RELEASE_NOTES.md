# DDQ's Cyber Thermometer v0.5.0

中文名：动动枪赛博体温计

本版本修复 macOS 26.4 / Apple Silicon M5 机型上风扇转速显示为“未读取”的问题。

## 功能

- 顶栏融合小组件：左侧双柱显示内存和 CPU，右侧显示核心温度。
- 鼠标悬停显示完整数值。
- 点击菜单显示风扇当前转速；顶栏仍只保留内存、CPU 和核心温度。
- 修复 AppleSMC 读取结构体偏移，支持在 M5 / macOS 26.4 上读取 `FNum`、`F0Ac`、`F1Ac` 等风扇键。
- 修复 Apple Silicon 风扇 RPM 的 `flt` 原生浮点解码。
- 点击菜单可勾选“开机启动”。
- 点击菜单可“检查更新…”，从 GitHub Release 获取最新版本和更新内容。
- 检查更新不再依赖 `api.github.com`，改为读取 GitHub Release Atom feed 和 latest 重定向，避免匿名 API 频率限制导致 403。
- 用户确认后优先下载 `.app.zip`，校验 SHA256，退出当前 App，替换安装后重新打开。
- 如果 Release 没有 zip 更新包，会回退到 DMG 更新流程。
- 自动安装失败时会打开更新包，方便手动安装。
- 点击菜单支持刷新和退出。
- Apple Silicon 优先读取 `PMU tdie` 核心温度。
- 温度读取失败时仍正常显示内存和 CPU。

## 安装

下载 `DDQs-Cyber-Thermometer-0.5.0.dmg`，打开后把 `动动枪赛博体温计.app` 拖到 Applications。

Release 同时提供 `DDQs-Cyber-Thermometer-0.5.0.app.zip`，供 App 内在线升级优先使用。

当前安装包为本地临时签名，未做 Apple Developer ID 公证。首次打开时如遇到系统拦截，可右键 App 选择“打开”，或在“系统设置 > 隐私与安全性”中允许打开。
