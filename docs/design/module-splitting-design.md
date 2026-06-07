# 模块化拆分设计

## 背景

当前项目源码主要集中在 `Sources/MacHealthGuardian/main.swift`，该文件约 1780 行，承载了 App 入口、菜单栏 UI、状态栏渲染、系统采样、温度/风扇读取、在线更新、开机启动、Shell 调用、格式化和值对象等职责。

这种结构对小型工具的早期迭代足够直接，但继续增加功能时会带来几个问题：

- 功能边界不清，改更新逻辑时容易碰到 UI、采样或传感器代码。
- 纯逻辑难以单元测试，尤其是版本比较、Release 解析、SHA256、`vm_stat` 解析等。
- 文件超过工程规范里的评审门槛，评审时很难判断变更影响范围。
- 系统 API、外部命令和用户界面混在一起，失败路径和 fallback 难以独立验证。

本设计只定义后续拆分方案，不改变现有功能行为。

## 拆分目标

- 保留现有全部功能和用户行为。
- 先按职责拆文件，再逐步引入可测试核心模块。
- 将纯逻辑和值对象放入可被测试 target 依赖的核心模块。
- 将 AppKit、SwiftUI、NSAlert、NSStatusItem 等 UI 生命周期代码限制在 App 入口层。
- 将 IOKit、ServiceManagement、外部命令等系统能力隔离在明确模块内。
- 每个 Swift 文件控制在工程规范建议范围内，超出门槛时有清晰职责说明。

## 功能保留清单

拆分后必须保留以下能力：

| 功能 | 当前实现位置 | 拆分后归属 |
| --- | --- | --- |
| SwiftUI `@main` 入口 | `MacHealthGuardianApp` | `MacHealthGuardian/App/MacHealthGuardianApp.swift` |
| 菜单栏 App 生命周期 | `AppDelegate` | `MacHealthGuardian/App/AppDelegate.swift` |
| 顶栏状态项与菜单 | `AppDelegate` | `MacHealthGuardian/App/StatusMenuController.swift` |
| 顶栏图像渲染 | `StatusImageRenderer` | `MacHealthGuardian/Rendering/StatusImageRenderer.swift` |
| 命令行 `--help`、`--sample`、`--doctor` | `MacHealthGuardianApp` | `MacHealthGuardian/App/CommandLineMode.swift` |
| 2 秒定时刷新 | `SystemMonitor` | `MacHealthGuardianCore/Monitoring/SystemMonitor.swift` |
| 内存采样与 `vm_stat` 解析 | `SystemSampler` | `MacHealthGuardianCore/Monitoring/MemorySampler.swift`、`VMStatParser.swift` |
| CPU tick 采样 | `CPUTicks`、`SystemSampler` | `MacHealthGuardianCore/Monitoring/CPUTicks.swift`、`CPUSampler.swift` |
| 系统快照和值对象 | `SystemSnapshot`、`MemorySnapshot`、`FanSpeedSnapshot` | `MacHealthGuardianCore/Models/` |
| Apple Silicon 核心温度读取 | `AppleSiliconTemperatureReader` | `MacHealthGuardianCore/Sensors/AppleSiliconTemperatureReader.swift` |
| 外部温度命令 fallback | `TemperatureReader`、`TemperatureCommand` | `MacHealthGuardianCore/Sensors/TemperatureReader.swift` |
| AppleSMC 风扇读取 | `AppleSMCReader`、SMC structs | `MacHealthGuardianCore/Sensors/AppleSMC/` |
| `istats` / `smc` 风扇 fallback | `FanSpeedReader` | `MacHealthGuardianCore/Sensors/FanSpeedReader.swift` |
| 开机启动 | `LaunchAtLoginController` | `MacHealthGuardian/LaunchAtLogin/LaunchAtLoginController.swift` |
| GitHub Release 最新版本发现 | `UpdateController`、`ReleaseAtomParser` | `MacHealthGuardianCore/Updates/ReleaseService.swift`、`ReleaseAtomParser.swift` |
| `.app.zip` 优先、DMG 回退 | `GitHubRelease` asset 选择 | `MacHealthGuardianCore/Updates/ReleaseAssetResolver.swift` |
| SHA256 下载校验 | `UpdateController` | `MacHealthGuardianCore/Updates/ChecksumVerifier.swift` |
| 更新确认、错误弹窗、Release 打开 | `UpdateController` | `MacHealthGuardian/Updates/UpdateUIController.swift` |
| ZIP/DMG 安装脚本生成和执行 | `UpdateController` | `MacHealthGuardian/Updates/UpdateInstaller.swift` |
| Shell 调用和 `which` | `Shell` | `MacHealthGuardianCore/Support/Shell.swift` |
| 日期、百分比、GB 文案格式化 | `Date`、`Double` extensions | `MacHealthGuardianCore/Support/Formatting.swift` |
| 构建、打包、发布脚本 | `Scripts/` | 保持目录不变，按需另行拆脚本 |

## 目标目录结构

推荐最终结构：

```text
Sources/
├── MacHealthGuardian/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── CommandLineMode.swift
│   │   ├── MacHealthGuardianApp.swift
│   │   └── StatusMenuController.swift
│   ├── LaunchAtLogin/
│   │   └── LaunchAtLoginController.swift
│   ├── Rendering/
│   │   └── StatusImageRenderer.swift
│   └── Updates/
│       ├── UpdateInstaller.swift
│       └── UpdateUIController.swift
└── MacHealthGuardianCore/
    ├── Models/
    │   ├── FanSpeedSnapshot.swift
    │   ├── MemorySnapshot.swift
    │   └── SystemSnapshot.swift
    ├── Monitoring/
    │   ├── CPUSampler.swift
    │   ├── CPUTicks.swift
    │   ├── MemorySampler.swift
    │   ├── SystemMonitor.swift
    │   ├── SystemSampler.swift
    │   └── VMStatParser.swift
    ├── Sensors/
    │   ├── AppleSiliconTemperatureReader.swift
    │   ├── AppleSMC/
    │   │   ├── AppleSMCReader.swift
    │   │   ├── SMCKeyData.swift
    │   │   └── SMCValue.swift
    │   ├── FanSpeedReader.swift
    │   ├── TemperatureCommand.swift
    │   └── TemperatureReader.swift
    ├── Support/
    │   ├── Formatting.swift
    │   ├── Shell.swift
    │   └── ShellQuoting.swift
    └── Updates/
        ├── ChecksumVerifier.swift
        ├── GitHubRelease.swift
        ├── GitHubReleaseAsset.swift
        ├── ReleaseAssetResolver.swift
        ├── ReleaseAtomParser.swift
        ├── ReleaseService.swift
        ├── ReleaseVersion.swift
        ├── UpdateError.swift
        └── UpdateInstallAsset.swift
Tests/
└── MacHealthGuardianCoreTests/
    ├── ReleaseAssetResolverTests.swift
    ├── ReleaseAtomParserTests.swift
    ├── ReleaseVersionTests.swift
    ├── TextFormattingTests.swift
    └── VMStatParserTests.swift
```

## Package 结构

推荐从一个 executable target 演进为 executable + core library + tests：

```swift
products: [
    .executable(
        name: "MacHealthGuardian",
        targets: ["MacHealthGuardian"]
    ),
    .library(
        name: "MacHealthGuardianCore",
        targets: ["MacHealthGuardianCore"]
    )
],
targets: [
    .executableTarget(
        name: "MacHealthGuardian",
        dependencies: ["MacHealthGuardianCore"],
        linkerSettings: [
            .linkedFramework("ServiceManagement")
        ]
    ),
    .target(
        name: "MacHealthGuardianCore",
        linkerSettings: [
            .linkedFramework("IOKit")
        ]
    ),
    .testTarget(
        name: "MacHealthGuardianCoreTests",
        dependencies: ["MacHealthGuardianCore"]
    )
]
```

如果拆分初期不想一次调整 target，可以先在 `Sources/MacHealthGuardian/` 内按目录拆文件；但第一批单元测试落地前，应完成 `MacHealthGuardianCore` target。

过渡期如果本机工具链缺少 `XCTest` 或 Swift `Testing` 模块，可以先增加 `MacHealthGuardianCoreTestRunner` executable target，用 `swift run MacHealthGuardianCoreTestRunner` 覆盖 Core 纯逻辑。该方式不替代最终的 `.testTarget`，只用于保证重构过程中有可运行的自动化验证。

## 依赖规则

- `MacHealthGuardian` 可以依赖 `MacHealthGuardianCore`。
- `MacHealthGuardianCore` 不得依赖 `MacHealthGuardian`。
- `MacHealthGuardianCore` 不引入 AppKit、SwiftUI、NSAlert、NSStatusItem、NSWorkspace 或 NSApplication。
- UI 展示、弹窗和菜单状态只放在 `MacHealthGuardian`。
- 更新检查的网络、版本、资产选择、校验逻辑放在 core；用户确认、错误弹窗、安装后重启放在 App 层。
- 传感器模块可以依赖 IOKit 和 Darwin，但不得依赖 UI。
- Shell 调用集中在 `Support/Shell.swift`，业务模块通过注入或小型协议使用，便于测试替换。
- 格式化扩展保持无副作用，优先放在 core，供 UI 和命令行共用。

## 关键模块设计

### App 模块

职责：

- 处理 SwiftUI `@main` 入口。
- 处理 `--help`、`--sample`、`--doctor` 命令行模式。
- 管理 `NSApplicationDelegate` 生命周期。
- 创建状态栏 item、菜单项和菜单 action。
- 把 `SystemSnapshot` 映射为菜单文案和状态栏图像。

不负责：

- 直接解析 `vm_stat`。
- 直接访问 GitHub Release 数据结构。
- 直接读取 SMC 或 HID 传感器。

### Rendering 模块

职责：

- 根据 `SystemSnapshot` 生成顶栏 `NSImage`。
- 保留现有内存蓝柱、CPU 绿柱、温度文字、颜色阈值和尺寸规则。

边界：

- 可以使用 AppKit。
- 不读取系统指标，不发网络请求，不持有菜单状态。

### Monitoring 模块

职责：

- 维护刷新节奏和采样状态。
- 聚合 CPU、内存、温度、风扇、热状态为 `SystemSnapshot`。
- 把 `vm_stat`、host CPU ticks 等系统输出转换为稳定模型。

可测试点：

- `VMStatParser` 固定文本输入解析。
- CPU 使用率计算。
- 内存 available/used 计算。

### Sensors 模块

职责：

- 读取 Apple Silicon `PMU tdie` 核心温度。
- 使用 `osx-cpu-temp`、`istats`、`smc` 作为温度 fallback。
- 使用 AppleSMC `FNum`、`F0Ac` 等键读取风扇。
- 使用 `istats fan speed` 和 `smc` 作为风扇 fallback。
- 对无风扇机器返回 `fanless`，读取失败返回 `unknown`。

可测试点：

- 外部命令输出数字提取。
- RPM 合理范围过滤。
- 温度合理范围过滤。

硬件读取本身以集成验证和手动验证为主。

### Updates Core 模块

职责：

- 从 GitHub Release Atom feed 获取最新 entry。
- Atom 失败时回退到 `/releases/latest` redirect 解析 tag。
- 从 tag 构造 `.app.zip`、`.app.zip.sha256`、`.dmg`、`.dmg.sha256` 资产 URL。
- 版本比较。
- 选择安装资产：优先 `.app.zip`，缺失或 404 时回退 `.dmg`。
- SHA256 文本提取和校验。

不负责：

- 显示确认弹窗。
- 打开 Release 页面。
- 退出 App 或重新打开 App。

### Updates App 模块

职责：

- 菜单项状态切换：正在检查、正在下载、正在准备安装。
- 显示“发现新版本”“已经是最新版本”“缺少安装包”“检查失败”等弹窗。
- 用户确认后调用 core 下载和校验。
- 生成并执行 ZIP/DMG 安装脚本。
- 自动安装失败时打开更新包并提示手动安装。

### LaunchAtLogin 模块

职责：

- 使用 `SMAppService.mainApp` 读取、注册和取消注册开机启动。
- 将不可切换状态反馈给菜单项。

边界：

- 保留在 App target，避免 core 引入 ServiceManagement。

## 拆分步骤

### 第 1 步：纯移动，不改行为

- 在现有 executable target 内建立目录。
- 将类型按职责移动到多个 Swift 文件。
- 不修改 `Package.swift` target 结构。
- 每次移动后运行 `swift build`。

建议顺序：

1. `Models`：`SystemSnapshot`、`MemorySnapshot`、`FanSpeedSnapshot`。
2. `Support`：`Shell`、`Date`/`Double` 格式化、`String.shellQuoted`。
3. `Updates` 模型：`ReleaseVersion`、`GitHubRelease`、`GitHubReleaseAsset`、`UpdateError`、`UpdateInstallAsset`。
4. `Monitoring`：`SystemMonitor`、`SystemSampler`、`CPUTicks`。
5. `Sensors`：温度、风扇、AppleSMC 和 HID 温度读取。
6. `Rendering`：`StatusImageRenderer`。
7. `App`：入口、Delegate、菜单控制。

### 第 2 步：抽出 Core target

- 新增 `MacHealthGuardianCore` target。
- 将 Models、Monitoring、Sensors、Support、Updates Core 迁入 core。
- App target 依赖 core。
- 保持 App 层只处理菜单栏、弹窗、安装执行和开机启动。

### 第 3 步：补单元测试

首批测试优先覆盖：

- `ReleaseVersion` 比较。
- Release 资产选择和 zip/dmg fallback 顺序。
- SHA256 文本提取。
- Atom feed entry 解析。
- `vm_stat` 页大小和页数解析。
- 温度/RPM 数字提取。
- 百分比、GB、时间、温度展示文案。

### 第 4 步：收敛 UI 与安装边界

- 将 `UpdateController` 拆成 `ReleaseService`、`UpdateUIController`、`UpdateInstaller`。
- 安装脚本生成保留在 App target，但把纯字符串构造尽量封装为可测试函数。
- 菜单项配置和 snapshot 渲染映射从 `AppDelegate` 中抽出，降低 Delegate 体积。

## PR 拆分建议

不要在一个 PR 中同时完成所有拆分。推荐 PR 顺序：

1. `docs`：提交本设计文档。
2. `refactor/models-support`：移动模型和支持工具，不改行为。
3. `refactor/updates-core`：拆更新模型、版本比较、资产选择和 Release 解析，补测试。
4. `refactor/monitoring-sensors`：拆采样和传感器读取，补解析类测试。
5. `refactor/app-ui`：拆 AppDelegate、菜单控制、渲染和更新 UI。
6. `test/core-coverage`：补全 core 单元测试和测试报告。

每个 PR 都应保持可编译，并在测试报告里记录执行结果。

## 验收标准

模块化完成后应满足：

- `main.swift` 只保留 `@main` 入口或极薄启动代码。
- 单个业务 Swift 文件原则上不超过工程规范评审门槛。
- `swift build` 通过。
- `swift test` 通过。
- 如当前工具链缺少测试框架模块，则 `swift run MacHealthGuardianCoreTestRunner` 必须通过，并在测试报告中记录 `swift test` 的限制。
- `MacHealthGuardian --help` 和 `MacHealthGuardian --sample` 可用。
- App 启动后仍只显示在菜单栏。
- 顶栏仍展示内存、CPU、核心温度。
- 菜单仍展示内存、CPU、核心温度、风扇转速、更新时间。
- 刷新、退出、开机启动仍可用。
- 温度读取保持 Apple Silicon 优先和命令 fallback。
- 风扇读取保持 AppleSMC 优先和命令 fallback。
- 检查更新仍支持 Atom feed、redirect fallback、zip 优先、DMG 回退、SHA256 校验和自动/手动安装 fallback。
- 打包脚本仍能生成 `.app`、DMG、`.app.zip` 和 SHA256 文件。

## 风险与控制

- AppleSMC、HID 温度读取属于硬件相关路径，拆分时应先纯移动，不重写算法。
- 更新安装流程涉及退出当前 App 和替换 bundle，拆分时应保留现有脚本文本行为，并补充失败路径手动验证。
- `Package.swift` target 拆分会引入访问级别调整，应优先使用 `internal` 和 `@testable import`，避免过早公开 API。
- `Shell` 注入会影响多个模块，首次改动只做最小封装，避免一次引入复杂依赖注入框架。
- GitHub Pages 发布 `docs/` 时会包含设计文档，如不希望公开，后续应单独调整 Pages 发布路径或文档位置。
