# 动动枪的电脑体温计

一个安静待在 macOS 顶栏里的电脑状态小组件。内存、CPU、核心温度，一眼看完。

![动动枪的电脑体温计主视觉](docs/assets/hero-preview.png)

## 下载

公开版本会放在 GitHub Release：

- 下载最新版：`Releases` 页面里的 `动动枪的电脑体温计-0.1.0.dmg`
- 当前版本：`v0.1.0`
- 许可证：MIT

安装方式：打开 DMG，把 `动动枪的电脑体温计.app` 拖到 `Applications`。

> 当前安装包是本地临时签名，未做 Apple Developer ID 公证。首次打开时如遇到系统拦截，可右键 App 选择“打开”，或到“系统设置 > 隐私与安全性”里允许打开。

## 它显示什么

![顶栏小组件展示](docs/assets/widget-closeup.png)

- 左侧蓝色迷你柱：内存占用率
- 右侧绿色迷你柱：CPU 占用率
- 紧贴的数字：核心温度
- 鼠标悬停：显示完整的内存、CPU、核心温度
- 点击菜单：刷新或退出

## 介绍页面

静态介绍页在：

```text
docs/index.html
```

推到 GitHub 后可以直接启用 GitHub Pages，发布 `docs/` 目录。

## 本地打包

```bash
cd /Users/zhanglongxin/Desktop/longxincode/mac-health-guardian
chmod +x Scripts/build-app.sh Scripts/package-dmg.sh
Scripts/package-dmg.sh
```

生成：

```text
dist/动动枪的电脑体温计-0.1.0.dmg
dist/动动枪的电脑体温计-0.1.0.dmg.sha256
```

只构建 App：

```bash
Scripts/build-app.sh
open "build/动动枪的电脑体温计.app"
```

终端采样：

```bash
".build/release/MacHealthGuardian" --sample
```

## 温度说明

Apple Silicon 机器会优先读取系统里的 `PMU tdie` 温度传感器，并取最高核心温度显示。其他机型或读取失败时，会自动尝试本机已安装的命令：

- `osx-cpu-temp`
- `istats`
- `smc`

如果直接读取和外部命令都失败，顶栏温度会显示 `--`，但内存和 CPU 仍会正常显示。

## 发布到 GitHub

本机需要先登录 GitHub CLI：

```bash
gh auth login
```

然后运行：

```bash
Scripts/publish-github.sh
```
