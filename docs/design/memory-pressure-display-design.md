# 内存压力展示与菜单栏配置设计

## 背景

当前菜单栏图像展示两条小进度条：内存占用和 CPU 占用。内存占用来自 `MemorySnapshot.usedPercent`，由可用内存反推得到。

这个指标适合回答“内存空间被使用了多少”，但不适合作为 macOS 上的内存负载告警。macOS 会主动使用空闲内存做文件缓存、压缩不活跃页面，并在需要时回收缓存。仅看已用内存百分比，容易把正常的缓存行为误判为内存紧张。

后续应新增“内存压力”指标，用来回答“系统为了维持内存是否已经开始付出明显代价”。内存占用继续保留，但从主告警指标降级为容量参考。

## 目标

- 新增一条直观的“内存压力”进度条。
- 保留现有“内存占用”展示，避免丢失容量视角。
- 支持用户在菜单里选择菜单栏默认展示哪些进度条。
- 将压力计算放在 core 模块，渲染层只消费稳定模型。
- 给压力计算、菜单显示配置和渲染行为留下可测试边界。

## 非目标

- 不追求完全复刻 Activity Monitor 的 Memory Pressure 算法。
- 不把内存压力等同于 `used / total`。
- 不在状态栏塞入完整内存明细；完整明细仍放在点击菜单后展示。
- 不把用户配置存入云端或项目配置文件；使用本机 `UserDefaults` 即可。

## macOS 内存理解

macOS 的内存状态应拆成两类概念：

| 概念 | 回答的问题 | 是否适合作为告警 |
| --- | --- | --- |
| 内存占用 | 当前有多少物理内存不在“可用”集合里 | 不适合作为主告警 |
| 内存压力 | 系统是否开始压缩、换页、缺少可快速回收空间 | 适合作为主告警 |

典型判断：

- 已用内存高、缓存多、swap 很低：通常是正常状态。
- 压缩内存明显增加、swap 开始出现：压力上升。
- swap 持续增长、swap out 速率高、可用内存低：压力紧张。
- wired memory 过高：可回收空间减少，也会推高压力。

因此菜单栏的主视觉应该优先展示“压力”，而不是单纯展示“占用”。

本设计参考 Activity Monitor 的 Memory Pressure 思路：内存压力是一个综合状态，不是单一的已用内存百分比。Apple 文档说明 Memory Pressure 会结合 free memory、swap rate、wired memory 和 file cached memory 判断。

Swap 是强压力信号，但不应只看 `Swap Used` 的绝对值：

- `Swap Used` 很高，说明系统曾经或正在把一部分内存页放到磁盘，通常代表压力升高过。
- `Swap Used` 很高但长时间不增长、没有明显 swap in/out，可能是压力已经缓解后的残留状态。
- `Swapouts` 持续增长，或单位时间 swap out 速率高，才更接近“当前正在内存紧张”。
- 因此压力算法应同时看 swap 使用量和 swap out 速率，并让 swap out 速率拥有更高权重。

## 状态栏展示方案

状态栏进度条拆成可配置的 display metrics：

| 指标 | 文案 | 默认 | 颜色语义 |
| --- | --- | --- | --- |
| `memoryPressure` | 内存压力 | 开启 | 绿 / 橙 / 红 |
| `memoryUsage` | 内存占用 | 开启 | 蓝 / 橙 / 红 |
| `cpuUsage` | CPU 占用 | 开启 | 绿 / 橙 / 红 |

默认展示三条小进度条：内存压力、内存占用、CPU 占用。这样既满足直观压力判断，也保留原来的容量视角。

如果用户觉得状态栏太挤，可以在菜单里关闭任意进度条。至少保留一条进度条；当用户尝试关闭最后一条时，该项应保持开启或置灰不可关。

温度文本继续展示在进度条右侧，不纳入开关。这个项目的核心价值之一是温度监控，隐藏温度会削弱工具定位。

### 推荐视觉结构

```text
[压力][内存][CPU]  62°
```

每条进度条仍使用窄竖条，宽度按展示数量动态计算：

| 展示数量 | 推荐宽度 | 用途 |
| ---: | ---: | --- |
| 1 条 | 7-8 px | 单指标模式 |
| 2 条 | 5-6 px | 压力 + CPU 或内存 + CPU |
| 3 条 | 4-5 px | 默认完整模式 |

渲染层不应固定假设只有两条 bar，应改为根据 display metrics 数组循环绘制。

## 菜单交互

点击菜单后增加一个“菜单栏显示”分组：

```text
菜单栏显示
✓ 内存压力
✓ 内存占用
✓ CPU 占用
```

交互规则：

- 菜单项使用 `NSMenuItem.state` 表示开关状态。
- 点击后立即刷新状态栏图像。
- 配置写入 `UserDefaults`，下次启动继续生效。
- 最后一项不允许关闭，避免状态栏只剩温度文本导致语义不清。
- 菜单明细始终展示完整指标，不受状态栏开关影响。
- 菜单应固定展示当前 App 版本号，版本号来自 `Info.plist` 的 `CFBundleShortVersionString`，不参与展示开关。
- 菜单应提供“复制诊断信息”操作，将当前系统信息、App 版本、内存明细、CPU、温度、风扇、热状态和采样时间复制为纯文本。

菜单明细建议调整为：

```text
内存压力 正常  23%
内存占用 68%  10.9 GB / 16.0 GB
可用内存 5.1 GB
压缩内存 0.8 GB
交换空间 0.0 GB
CPU 占用 18%
核心温度 62°C  热状态正常
风扇转速 --
更新 19:20
复制诊断信息
版本 0.7.1
```

当信息过多时，可以先保留一级明细：

```text
内存压力 正常  23%
内存占用 68%  10.9 GB / 16.0 GB
CPU 占用 18%
核心温度 62°C  热状态正常
风扇转速 --
更新 19:20
```

后续再按需要增加二级明细。

## 数据模型

在 `MacHealthGuardianCore` 增加内存压力模型：

```swift
public enum MemoryPressureLevel: String, Sendable {
    case normal
    case warning
    case critical
}

public struct MemoryPressureSnapshot: Sendable {
    public let score: Double
    public let level: MemoryPressureLevel
    public let availableRatio: Double
    public let compressedRatio: Double
    public let wiredRatio: Double
    public let swapUsedGB: Double
    public let swapOutsPerSecond: Double
}
```

扩展 `MemorySnapshot`：

```swift
public struct MemorySnapshot: Sendable {
    public let totalGB: Double
    public let usedGB: Double
    public let usedPercent: Double
    public let availableGB: Double
    public let activeGB: Double
    public let wiredGB: Double
    public let compressedGB: Double
    public let pressure: MemoryPressureSnapshot
}
```

如果为了兼容迁移，可以先让 `pressure` 提供 `.empty` 默认值，避免大范围调用点一次性变复杂。

## 压力计算

压力分数范围为 `0...100`，等级按分数映射：

| 分数 | 等级 | UI |
| ---: | --- | --- |
| `0..<55` | `normal` | 绿色 |
| `55..<80` | `warning` | 橙色 |
| `80...100` | `critical` | 红色 |

建议初版使用启发式计算，而不是单一阈值：

| 输入 | 压力含义 |
| --- | --- |
| `availableGB / totalGB` | 可快速使用空间越低，压力越高 |
| `compressedGB / totalGB` | 压缩越多，说明系统已经在节省内存 |
| `wiredGB / totalGB` | 不可回收内存越多，越容易挤压可用空间 |
| `swapUsedGB` | 已经发生磁盘换页 |
| `swapOutsPerSecond` | 当前正在持续把页面换出，压力更强 |

伪代码：

```swift
var score = 0.0

score += availableRatioScore(availableGB / totalGB)
score += min(20, compressedRatio * 120)
score += wiredRatio > 0.35 ? 10 : 0
score += wiredRatio > 0.50 ? 10 : 0
score += swapUsedGB > 0.5 ? 10 : 0
score += swapUsedGB > 2.0 ? 10 : 0
score += swapOutsPerSecond > 50 ? 10 : 0
score += swapOutsPerSecond > 500 ? 15 : 0

score = min(100, max(0, score))
```

`availableRatioScore` 建议：

| 可用比例 | 分数 |
| ---: | ---: |
| `>= 0.35` | 5 |
| `0.20..<0.35` | 20 |
| `0.10..<0.20` | 40 |
| `0.05..<0.10` | 60 |
| `< 0.05` | 75 |

这套算法的目标是稳定表达“压力趋势”，不是精确表达某个系统内部私有指标。后续可以根据真实机器观察调整阈值。

## 数据来源

现有 `vm_stat` 已能提供大部分页面计数：

- `Pages free`
- `Pages speculative`
- `Pages inactive`
- `Pages purgeable`
- `Pages active`
- `Pages wired down`
- `Pages occupied by compressor`
- `Compressions`
- `Decompressions`
- `Swapins`
- `Swapouts`

新增 swap 使用量可以通过 `sysctl vm.swapusage` 读取，并增加独立 parser。

建议新增：

```text
Sources/MacHealthGuardianCore/Monitoring/MemorySampler.swift
Sources/MacHealthGuardianCore/Monitoring/MemoryPressureCalculator.swift
Sources/MacHealthGuardianCore/Monitoring/SwapUsageParser.swift
Sources/MacHealthGuardianCore/Models/MemoryPressureSnapshot.swift
Sources/MacHealthGuardian/App/MenuBarDisplayMetric.swift
Sources/MacHealthGuardian/App/MenuBarDisplaySettings.swift
```

`MemorySampler` 负责保存上一轮 `Swapouts` 计数，计算 `swapOutsPerSecond`。`MemoryPressureCalculator` 负责纯压力分数计算，便于单元测试。`SystemSampler` 只聚合 CPU、内存、温度和风扇，不继续承担内存细节。

## 配置模型

状态栏展示配置只属于 App 层：

```swift
enum MenuBarDisplayMetric: String, CaseIterable, Sendable {
    case memoryPressure
    case memoryUsage
    case cpuUsage
}

struct MenuBarDisplaySettings: Sendable {
    var metrics: [MenuBarDisplayMetric]
}
```

存储建议：

```text
UserDefaults key: menuBarDisplayMetrics
Default value: ["memoryPressure", "memoryUsage", "cpuUsage"]
```

`StatusImageRenderer` 接口调整为：

```swift
func image(
    for snapshot: SystemSnapshot,
    displayMetrics: [MenuBarDisplayMetric],
    appearance: NSAppearance
) -> NSImage
```

为了保持 core 不依赖 AppKit，`MenuBarDisplayMetric` 可以放在 core，或者放在 App 层并由 App 层映射为 renderer 专用 display model。推荐放 App 层，避免 core 关心菜单栏显示策略。

## 模块边界

| 模块 | 职责 |
| --- | --- |
| `MacHealthGuardianCore/Models` | 内存压力值对象、等级和值格式化 |
| `MacHealthGuardianCore/Monitoring` | `vm_stat`、swap 读取、压力分数计算 |
| `MacHealthGuardian/Rendering` | 按配置绘制 1-3 条进度条 |
| `MacHealthGuardian/App` | 菜单开关、UserDefaults、菜单文案 |

约束：

- 压力分数计算不得放进 `StatusImageRenderer`。
- `UserDefaults` 不进入 core。
- 菜单开关不影响采样，只影响状态栏渲染。
- 菜单明细展示完整指标，不受开关影响。

## 开发顺序

1. 增加 `MemoryPressureSnapshot` 和 `MemoryPressureLevel`。
2. 抽出 `MemorySampler`，把 `SystemSampler.readMemory()` 的逻辑迁移过去。
3. 增加 `SwapUsageParser`，解析 `sysctl vm.swapusage`。
4. 在 `MemorySampler` 中计算压力分数和等级。
5. 调整 `SystemSnapshot.toolTipText` 和菜单文案，加入内存压力。
6. 增加 `MenuBarDisplaySettings`，用 `UserDefaults` 保存展示项。
7. 调整 `StatusImageRenderer`，支持按 display metrics 循环绘制进度条。
8. 在菜单里增加“菜单栏显示”开关。
9. 补充单元测试和手动验证记录。

## 测试要求

新增单元测试：

| 测试文件 | 覆盖点 |
| --- | --- |
| `MemoryPressureCalculatorTests.swift` | available、compressed、wired、swap、swap out 对分数和等级的影响 |
| `SwapUsageParserTests.swift` | 解析 `sysctl vm.swapusage` 的 MB/GB、空输出和异常格式 |
| `MenuBarDisplaySettingsTests.swift` | 默认值、持久化、最后一项不可关闭 |
| `StatusImageRendererTests.swift` | 可选；验证 display metrics 为空时 fallback，不做像素级强依赖 |

手动验证：

- 默认启动展示三条进度条和温度文本。
- 菜单里关闭/开启任意进度条，状态栏立即刷新。
- 重启 App 后开关状态保留。
- 内存压力、内存占用、CPU 占用在菜单明细中都能看到。
- `swift test` 通过。
- `swift build -c release` 通过。

## 风险与取舍

- 三条小进度条会比现有两条更密集，因此必须提供菜单开关。
- 压力算法是启发式指标，PR 描述和菜单文案应避免暗示它是 Apple 私有算法。
- swap out 速率依赖前后两次采样，首次采样应返回 0 或 unknown，不应造成红色误报。
- 如果 `sysctl vm.swapusage` 读取失败，压力仍可由 available、compressed、wired 计算，但 swap 相关分数应降级为 0。
- 旧版用户升级后默认展示三条进度条；如果担心视觉变化过大，可以在发布说明里说明新增开关。
