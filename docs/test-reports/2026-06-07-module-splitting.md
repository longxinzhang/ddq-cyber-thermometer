# 测试报告：模块化拆分

## 基本信息

- 日期：2026-06-07
- 分支：`docs/design-standards`
- 提交：待提交
- 测试人：Codex
- macOS 版本：未记录
- 设备架构：Apple Silicon
- App 版本：0.5.0

## 变更范围

- 将 `Sources/MacHealthGuardian/main.swift` 拆分为 App、Rendering、Updates、LaunchAtLogin 模块文件。
- 新增 `MacHealthGuardianCore` target，承载 Models、Monitoring、Sensors、Updates、Support 等核心逻辑。
- 新增 `MacHealthGuardianCoreTests` 标准 XCTest target，覆盖 Core 纯逻辑测试。
- 合并官方 `v0.5.0`，将 AppleSMC 结构体偏移修复和 `flt` 浮点解码修复迁移到 `MacHealthGuardianCore/Sensors/AppleSMC/AppleSMCReader.swift`。
- 新增并更新设计文档、测试规范和本测试报告。

## 测试结论

结论：通过

说明：

- Debug 构建、Release 构建、标准 `swift test`、命令行帮助、命令行采样和 `.app` 构建均通过。

## 自动化检查

| 检查项 | 命令 | 结果 | 备注 |
| --- | --- | --- | --- |
| Debug 构建 | `swift build` | 通过 | 需非沙箱权限写入 SwiftPM/clang 缓存 |
| Release 构建 | `swift build -c release` | 通过 | 生产构建通过 |
| 标准 Swift 测试 | `swift test` | 通过 | 执行 9 个 XCTest，覆盖版本比较、资产选择、checksum 匹配、Atom 解析、`vm_stat` 解析、格式化 |
| App Bundle 构建 | `Scripts/build-app.sh` | 通过 | 生成 `build/动动枪赛博体温计.app` |

## 命令行验证

| 场景 | 命令 | 预期 | 实际 | 结果 |
| --- | --- | --- | --- | --- |
| 帮助信息 | `.build/debug/MacHealthGuardian --help` | 输出帮助 | 输出 App 名称和 `--sample` 用法 | 通过 |
| Debug 指标采样 | `.build/debug/MacHealthGuardian --sample` | 输出内存、CPU、温度、风扇、热状态、时间 | 输出完整摘要，温度为 `--°C`，风扇为 `未读取` | 通过 |
| App Bundle 指标采样 | `build/动动枪赛博体温计.app/Contents/MacOS/MacHealthGuardian --sample` | 打包后可执行文件输出指标摘要 | 输出完整摘要 | 通过 |

## 正确性与边界验证

- 正常路径：构建、Core 逻辑测试、命令行帮助和采样均通过。
- 边界路径：Release 版本号缺失组件按 `0` 比较，Release 缺失 `.app.zip` 时回退 DMG。
- 失败路径：当前测试覆盖 checksum 资产匹配；网络失败、安装失败和 UI 弹窗路径未自动化。
- 回退路径：资产选择测试覆盖 `.app.zip` 优先和 DMG 回退；温度/风扇硬件 fallback 未在自动化测试中覆盖。

## 未覆盖风险

- 菜单栏 UI 未手动启动验证；本次只验证编译和命令行模式。
- 更新安装脚本未执行真实 ZIP/DMG 替换安装，只验证编译。
- AppleSMC、HID 温度和风扇读取受硬件环境影响，本次只通过 `--sample` 做运行验证；官方 v0.5.0 的 SMC 结构修复已迁移到 Core 模块。

## 附件

- 生成物：`build/动动枪赛博体温计.app`
