# 测试报告：菜单 CPU 占用前三名

## 基本信息

- 日期：2026-10-17
- 分支：main，基于 afb1157 的功能变更。
- 系统：macOS 26.5.2 (25F84)，arm64。
- 工具链：Xcode Swift 6.2.4，通过 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 指定。
- App Bundle 版本仍为 0.8.2；本功能尚未打包为新的 GitHub Release。

## 变更范围

- CPU 占用下方新增固定 260x90 的三行进程列表，名称截断、百分比固定右对齐，悬停显示完整名称和 PID。
- 菜单展开后先采集基线，约一秒后显示最近区间排名，之后每两秒刷新；关闭菜单取消采样，重新展开清除旧排名。
- 使用 libproc 读取进程累计 CPU 时间，以两次采样的增量计算；跳过退出、无法读取、PID 重用和计数倒退的进程。
- AppDelegate 仅增加菜单与生命周期接线；采样、任务管理、列表控件均放在独立文件，避免扩大已有菜单管理代码的职责。

## 自动化与本机验证

| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| Debug 构建 | PASS | 使用完整 Xcode 工具链构建成功 |
| 单元测试 | PASS | 37 项测试全部通过，新增 5 项覆盖最近区间排序、系统 CPU 时间、多核百分比、PID 重用、退出、新进程、无效区间和空样本 |
| Release / App 构建 | PASS | `BUILD_UNIVERSAL=0 Scripts/build-app.sh` 成功生成 arm64 App |
| 代码签名检查 | PASS | `codesign --verify --deep --strict` 通过，本地临时签名 |
| 真实进程采样 | PASS | `--top-cpu` 返回本机实际进程名称、PID 和前三名 CPU 占用 |
| 受控单核负载 | PASS | 临时启动 `/usr/bin/yes`，新采样器将其排为第一，显示 99.7%；验证结束已停止该进程 |
| 原有指标采样 | PASS | `--sample` 正常返回内存、网络、CPU、37°C 核心温度及风扇读数 |
| 控件离屏渲染 | PASS | 浅色和深色截图检查通过；长名称截断、1200.5% 多核数值和固定列对齐通过 |
| 采样生命周期 | PASS | 独立验证程序收到真实排名后停止监控，等待超过刷新间隔未再收到回调；重新开启立即显示采样中，取消后无过期回调 |
| 实际展开菜单交互 | BLOCKED_ENVIRONMENT | 界面自动化工具选择本地 App 时超时，未确认完整菜单实际展开与悬停行为 |

## CPU 计时校准

受控测试发现，直接将 `rusage_info_v2` 的 CPU 时间与纳秒时间相除，在本机单核负载下仅显示 2.4%。已改为使用 `mach_absolute_time()` 作为同单位的采样时间，再次实测得到 99.7%。CPU 百分比保留“一个逻辑核心满载为 100%”的口径，多核进程可超过 100%。

系统实现参考：[Apple XNU 的进程 CPU 时间读取](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c)、[Apple Recount 计时说明](https://github.com/apple-oss-distributions/xnu/blob/main/doc/observability/recount.md)。

## 限制与产物

- 这是 CPU 占用排名，用来辅助排查发热来源，不表示每个进程的独立温度。
- 未验证 Intel 设备；无法读取的进程会跳过，刚启动的进程需要形成两个有效样本后参与排序。
- GUI 完整菜单交互仍需人工验收；离屏控件验证不替代此项。
- 本地 App：`build/动动枪赛博体温计.app`。
- 独立验证程序及深浅色截图位于已忽略的 `build/` 目录，不进入发布资产。
- 本报告不包含 DMG、标签或 GitHub Release 发布验证。
