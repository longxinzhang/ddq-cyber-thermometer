# 项目结构与现状

## 项目定位

DDQ's Cyber Thermometer，中文名“动动枪赛博体温计”，是一个 macOS 顶栏状态小组件。它以 Swift Package 形式组织，打包后生成一个不显示 Dock 图标的菜单栏 App。

项目当前主要用途：

- 在 macOS 顶栏展示内存占用、CPU 占用和核心温度。
- 鼠标悬停时展示完整指标摘要。
- 点击菜单查看内存、CPU、核心温度、风扇转速和刷新时间。
- 支持手动刷新、退出、开机启动设置。
- 支持从 GitHub Release 检查更新，优先下载 `.app.zip` 自动替换安装，并回退支持 DMG。
- 提供静态介绍页和发布脚本，便于通过 GitHub Release 与 GitHub Pages 分发。

## 技术栈

- 语言：Swift 6.0
- 最低系统：macOS 13
- UI 框架：SwiftUI 入口 + AppKit 菜单栏能力
- 系统能力：IOKit、ServiceManagement
- 分发方式：本地构建 `.app`，再打包为 `.dmg` 和 `.app.zip`

## 当前目录结构

```text
.
├── Info.plist
├── LICENSE
├── Package.swift
├── README.md
├── RELEASE_NOTES.md
├── Scripts/
│   ├── build-app.sh
│   ├── generate-icon.swift
│   ├── generate-marketing-assets.swift
│   ├── package-dmg.sh
│   └── publish-github.sh
├── Sources/
│   ├── MacHealthGuardian/
│   │   ├── App/
│   │   ├── LaunchAtLogin/
│   │   ├── Rendering/
│   │   └── Updates/
│   └── MacHealthGuardianCore/
│       ├── Models/
│       ├── Monitoring/
│       ├── Sensors/
│       ├── Support/
│       └── Updates/
├── Tests/
│   └── MacHealthGuardianCoreTests/
└── docs/
    ├── assets/
    │   ├── app-icon.png
    │   ├── hero-preview.png
    │   └── widget-closeup.png
    ├── design/
    │   ├── README.md
    │   ├── engineering-standards.md
    │   ├── module-splitting-design.md
    │   ├── project-structure.md
    │   ├── test-report-template.md
    │   └── testing-guidelines.md
    ├── test-reports/
    │   └── 2026-06-07-module-splitting.md
    └── index.html
```

生成物目录不进入 git：`.build/`、`.swiftpm/`、`build/`、`dist/`。

## 关键文件说明

### `Package.swift`

Swift Package 配置。当前定义：

- `MacHealthGuardian`：菜单栏 App 可执行产物，依赖 `MacHealthGuardianCore`，链接 `ServiceManagement`。
- `MacHealthGuardianCore`：核心逻辑库，承载模型、监控、传感器、更新解析和支持工具，链接 `IOKit`。
- `MacHealthGuardianCoreTests`：标准 XCTest 单元测试 target，覆盖核心纯逻辑。

### `Info.plist`

App Bundle 元信息。当前 bundle 标识为 `com.dongdongqiang.cyber-thermometer`，展示名为“动动枪赛博体温计”，版本为 `0.5.0`。`LSUIElement` 为 `true`，表示 App 作为菜单栏应用运行，不显示 Dock 图标。

### `Sources/MacHealthGuardian/`

App target，负责菜单栏应用入口和用户界面相关逻辑：

- `App/`：SwiftUI App 入口、`AppDelegate` 和命令行模式。
- `Rendering/`：状态栏图像绘制。
- `Updates/`：更新检查 UI 流程和 ZIP/DMG 安装脚本执行。
- `LaunchAtLogin/`：通过 `SMAppService.mainApp` 管理开机启动。

### `Sources/MacHealthGuardianCore/`

Core target，负责可复用、可测试的核心逻辑：

- `Models/`：`SystemSnapshot`、`MemorySnapshot`、`FanSpeedSnapshot` 等值对象。
- `Monitoring/`：定时刷新、CPU/内存采样、`vm_stat` 解析。
- `Sensors/`：Apple Silicon 温度、AppleSMC 风扇、外部命令 fallback。
- `Updates/`：Release Atom 解析、版本比较、资产选择、更新错误模型。
- `Support/`：Shell 调用、字符串转义、时间/百分比/容量格式化。

### `Tests/MacHealthGuardianCoreTests/`

标准 XCTest 单元测试 target。当前覆盖版本比较、Release 资产选择、Release Atom 解析、`vm_stat` 解析和格式化逻辑。

### `Scripts/`

构建、打包、发布和素材生成脚本：

- `build-app.sh`：执行 release 构建，生成 `.app` 目录，生成并写入图标，进行本地临时代码签名。
- `package-dmg.sh`：调用构建脚本，生成 DMG、`.app.zip` 和对应 SHA256 文件。
- `publish-github.sh`：使用 GitHub CLI 推送代码、标签和 Release 资产，并尝试启用 GitHub Pages。
- `generate-icon.swift`：生成 App iconset 和 icns 所需的 PNG 图标。
- `generate-marketing-assets.swift`：生成介绍页使用的宣传图与展示图。

### `docs/`

面向用户和项目维护的文档目录：

- `index.html`：静态介绍页，可用于 GitHub Pages。
- `assets/`：介绍页和 README 使用的图片资源。
- `design/`：新增的设计文档目录，用于沉淀项目结构、方案和后续 PR 设计说明。

### `README.md` 与 `RELEASE_NOTES.md`

- `README.md`：面向使用者和维护者的项目说明，包含下载、功能、打包、温度/风扇说明、在线升级和发布方式。
- `RELEASE_NOTES.md`：当前版本发布说明，描述 v0.5.0 的功能和安装信息。

## 当前代码组织特点

- 旧的 `main.swift` 已按模块拆分，App target 与 Core target 分离。
- 菜单栏 UI、采样逻辑、更新逻辑和系统集成逻辑已经拆到独立目录，后续可继续收敛文件边界和补标准测试 target。
- 打包链路由 shell 脚本驱动，构建产物和发布资产都从 `Info.plist` 读取版本号或使用脚本内固定版本信息。
- 静态官网资源和设计文档都位于 `docs/` 下，后续需要注意 GitHub Pages 发布路径是否要包含或隐藏设计文档。
