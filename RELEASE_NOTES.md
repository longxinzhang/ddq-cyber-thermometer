# DDQ's Cyber Thermometer v0.1.0

中文名：动动枪赛博体温计

第一个公开版本。

## 功能

- 顶栏融合小组件：左侧双柱显示内存和 CPU，右侧显示核心温度。
- 鼠标悬停显示完整数值。
- 点击菜单支持刷新和退出。
- Apple Silicon 优先读取 `PMU tdie` 核心温度。
- 温度读取失败时仍正常显示内存和 CPU。

## 安装

下载 `DDQs-Cyber-Thermometer-0.1.0.dmg`，打开后把 `动动枪赛博体温计.app` 拖到 Applications。

当前安装包为本地临时签名，未做 Apple Developer ID 公证。首次打开时如遇到系统拦截，可右键 App 选择“打开”，或在“系统设置 > 隐私与安全性”中允许打开。
