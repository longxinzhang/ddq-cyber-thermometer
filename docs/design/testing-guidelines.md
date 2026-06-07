# 测试规范

## 目标

本规范用于确保每次代码变更都能验证正确性和功能性。测试结论应可复现、可追溯，并清楚说明未覆盖风险。

## 测试分层

### 静态与构建检查

适用于所有 PR：

- `git diff --check`：检查空白和补丁格式问题。
- `swift build`：验证 Swift Package 可以编译。
- `swift build -c release`：涉及打包、发布、性能或运行形态时必须执行。

### 单元测试

适用于有明确输入输出的逻辑。后续新增测试 target 时，优先覆盖：

- 版本比较：`ReleaseVersion` 的大小比较、`v` 前缀、不同位数版本号。
- Release 资产选择：优先 `.app.zip`，缺失时回退 `.dmg`，忽略 `.sha256`。
- 校验解析：SHA256 文本提取、无效校验文件、校验不一致。
- 系统输出解析：`vm_stat` 页大小、内存页统计、外部命令输出解析。
- 格式化逻辑：百分比、GB、时间、温度、风扇展示文案。

单元测试应尽量使用固定输入和 fixture，不依赖当前机器硬件状态、网络状态或 GitHub Release 实时数据。

#### Swift 单元测试落地方式

Swift Package 支持通过 `swift test` 执行单元测试。当前项目只有一个 executable target，且入口代码包含 `@main`、AppKit 菜单栏生命周期和系统 API。为了让测试稳定、边界清晰，新增单元测试时应优先采用“可测试核心库 + 可执行 App 入口”的结构：

```text
Sources/
├── MacHealthGuardian/
│   └── main.swift
└── MacHealthGuardianCore/
    ├── Models/
    ├── Monitoring/
    ├── Sensors/
    ├── Updates/
    └── Support/
Tests/
└── MacHealthGuardianCoreTests/
    ├── ReleaseVersionTests.swift
    ├── GitHubReleaseAssetSelectionTests.swift
    └── VMStatParsingTests.swift
```

推荐的 `Package.swift` target 关系：

```swift
targets: [
    .executableTarget(
        name: "MacHealthGuardian",
        dependencies: ["MacHealthGuardianCore"],
        linkerSettings: [
            .linkedFramework("IOKit"),
            .linkedFramework("ServiceManagement")
        ]
    ),
    .target(
        name: "MacHealthGuardianCore",
        linkerSettings: [
            .linkedFramework("IOKit"),
            .linkedFramework("ServiceManagement")
        ]
    ),
    .testTarget(
        name: "MacHealthGuardianCoreTests",
        dependencies: ["MacHealthGuardianCore"]
    )
]
```

落地要求：

- `MacHealthGuardian` 保留 App 启动、菜单栏生命周期和命令行入口。
- `MacHealthGuardianCore` 承载可复用、可测试的业务逻辑和值对象。
- 单元测试依赖 `MacHealthGuardianCore`，不直接依赖菜单栏 App 入口。
- 与网络、文件系统、外部命令、IOKit 或 ServiceManagement 交互的代码应通过协议或小型封装隔离，测试中使用固定输入或替身对象。
- 新增可测试纯逻辑时，应同步补充或更新对应单元测试；暂不能测试时，在 PR 测试报告中说明原因。

执行命令：

```bash
swift test
```

当前仓库尚未配置 `Tests/` 目录和测试 target。第一次引入单元测试的 PR 应先完成核心逻辑抽取和测试 target 配置，再补充首批测试用例。

如果当前本机工具链缺少 `XCTest` 或 Swift `Testing` 模块，可以临时使用可执行测试 runner 验证纯逻辑：

```bash
swift run MacHealthGuardianCoreTestRunner
```

该 runner 只能作为过渡方案。后续切换到完整 Xcode/Swift 测试工具链后，应优先恢复标准 `.testTarget` 和 `swift test`。

### 集成与命令行验证

适用于运行时行为：

- `MacHealthGuardian --help`：验证命令行帮助可用。
- `MacHealthGuardian --sample`：验证可以输出一组系统指标。
- `Scripts/build-app.sh`：验证可生成 `.app`。
- `Scripts/package-dmg.sh`：涉及发布资产时验证 DMG、`.app.zip` 和 SHA256 文件生成。

硬件相关指标允许不同机器结果不同，但输出结构必须稳定，失败时要有清晰 fallback。

### 手动功能验证

涉及菜单栏 UI、系统权限或安装更新流程时，需要手动验证：

- App 启动后只出现在菜单栏，不显示 Dock 图标。
- 顶栏展示内存、CPU、温度，温度读取失败时显示 `--` 且其他指标正常。
- 鼠标悬停展示完整摘要。
- 点击菜单可看到内存、CPU、核心温度、风扇转速和更新时间。
- 刷新、退出可用。
- 开机启动勾选状态与系统登录项状态一致。
- 检查更新流程在最新版本、发现新版本、缺少安装包、校验失败、自动安装失败时都有明确提示。

## PR 最低测试要求

| PR 类型 | 最低要求 |
| --- | --- |
| 纯文档 | `git diff --check`，人工确认链接可读 |
| 普通代码改动 | `git diff --check`，`swift build`，相关单元测试或命令行验证 |
| 系统采样/传感器 | 普通代码要求，加 `--sample`，记录测试机器和可用传感器情况 |
| 菜单栏 UI | 普通代码要求，加手动启动验证和截图或文字记录 |
| 更新/安装 | `swift build -c release`，资产选择测试，下载/校验/失败路径验证 |
| 打包/发布脚本 | `Scripts/build-app.sh`，必要时 `Scripts/package-dmg.sh`，记录生成物 |

如果某项测试无法执行，测试报告必须写明原因、影响范围和替代验证方式。

## 正确性验证要求

验证代码正确性时，至少关注：

- 正常路径：输入有效时输出符合预期。
- 边界路径：空值、缺失字段、版本号位数不同、传感器不可用。
- 失败路径：网络失败、HTTP 非 2xx、校验失败、权限不足、外部命令不存在。
- 回退路径：直接读取失败后是否尝试 fallback，更新包缺失时是否回退 DMG。
- 线程与主线程：UI 更新必须回到主线程，后台采样不能阻塞菜单栏。

## 功能性验证要求

验证功能性时，至少关注：

- 用户是否能完成目标操作。
- 操作结果是否有明确反馈。
- 失败时是否给出可理解的提示和下一步。
- 旧功能是否保持兼容。
- 构建产物是否符合 README 和 Release 说明。

## 测试报告要求

每个涉及代码、构建、发布或用户流程的 PR 都应附测试报告。报告可以写在 PR 描述中；如果测试较复杂或需要长期保留，应按模板保存为独立 Markdown 文件。

建议长期保存路径：

```text
docs/test-reports/YYYY-MM-DD-short-title.md
```

报告模板见 [测试报告模板](test-report-template.md)。
