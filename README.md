# Terminal Hearts

一个用 `Godot 4` 制作的红心大战单机原型：窗口程序，但视觉上模拟终端/像素风牌桌。

当前版本已经可以完整游玩：

- 1 名玩家对战 3 个 AI
- 标准红心大战基础规则
- 传牌轮换：左 / 右 / 对家 / 不传
- 首墩 `2♣` 开局
- 跟花、破心、首墩禁出红心和 `Q♠`
- 红心每张 1 分，`Q♠` 13 分
- `shoot the moon`
- 累计到 100 分结束

项目仓库：<https://github.com/jmydurant/hearts_game>

开发记录见：[DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md)

## 当前状态

这是一个已经可玩的原型，不是完成版。

已完成：

- 核心规则与回合流程
- 基础 AI
- 终端像素风 UI
- 中文界面
- 动态整数倍 viewport 缩放
- 窗口化 / 最大化 / 全屏切换
- 固定种子启动
- 基础自动化测试

还没做：

- 更强的 AI 策略
- 多档高分屏布局 profile
- 音效、动画细化、设置页
- 导出预设和正式发布流程
- 联网、多存档、回放

## 运行要求

- `Godot 4.6.x`
- 桌面平台
- 当前 UI 版本推荐显示器分辨率至少 `1920x1080`

说明：

- 这版的逻辑画布固定为像素风整数缩放方案。
- 基础逻辑网格为 `640x360`。
- 启动时会优先以 `3x` 整数缩放打开；如果可用区域不足，会回退到 `2x`。
- 窗口尺寸变化、最大化和全屏时，会按当前窗口可容纳的最近整数倍动态扩展逻辑 viewport。
- 在 macOS 上，如果只能以 `2x` 启动，会默认使用更大的窗口形态避免初始窗口过小。
- 低于 `1280x720` 时，程序会显示“不支持”的覆盖提示。

为什么从固定 `1920x1080` viewport 改成动态 viewport：

- 旧方案把根 viewport 固定在 `1920x1080`，等价于把 `640x360` 的逻辑网格锁死在 `3x`。
- 在 macOS 高分屏和系统缩放下，窗口即使已经全屏，Godot 里的有效桌面尺寸也可能不是传统 `1920x1080` 语义，结果就是启动门槛过严，小屏或缩放桌面会被误判成“不支持”。
- 更关键的是，全屏后窗口虽然变大了，但内部仍然只是在放大同一张 `1920x1080` 画布，逻辑网格不会继续扩展，显示体感和可用空间不匹配。
- 现在改成以 `640x360` 为基础网格，再按当前窗口可容纳的最大整数倍动态设置 viewport，这样既保住像素风整数缩放，也能让大窗口和全屏真正吃到更多逻辑像素。

## 启动方式

如果你的系统里已经有 Godot：

```bash
godot --path .
```

如果你和当前开发环境一样，把 Godot 二进制放在固定路径，也可以这样启动：

```bash
/home/jmydurant/software/Godot_v4.6.2-stable_linux.x86_64 --path /home/jmydurant/CLionProjects/Hearts_game
```

## 启动参数

- `--seed=<int>`：固定洗牌种子，方便复现牌局
- `--ascii`：强制 ASCII 花色回退显示

示例：

```bash
godot --path . -- --seed=42
```

## 操作说明

传牌阶段：

- `Left / Right`：移动当前选中的手牌或按钮
- `Up / Down`：在手牌区和按钮区之间切换
- `Enter`：选中/取消选中一张牌，或确认传牌

出牌阶段：

- `Left / Right`：移动当前选中的手牌
- `Up / Down`：切换焦点区
- `Enter`：出牌

全局：

- `F11`：切换全屏
- `Esc`：打开暂停菜单，可切换 `窗口化 / 最大化 / 全屏`

## 测试

当前包含规则和流程层面的 headless 测试。

运行方式：

```bash
/home/jmydurant/software/Godot_v4.6.2-stable_linux.x86_64 --headless --path /home/jmydurant/CLionProjects/Hearts_game -s res://tests/test_runner.gd
```

## 项目结构

```text
assets/         字体和资源
scenes/         Godot 场景
scripts/core/   规则、状态机、计分
scripts/ai/     AI 策略
scripts/ui/     界面、绘制、输入
tests/          Headless 测试
```

## 第三方资源

当前 UI 使用了外部像素字体资源：

- Fusion Pixel Font
- 仓库：<https://github.com/TakWolf/fusion-pixel-font>
- 字体许可证：`SIL Open Font License 1.1`

对应字体文件和许可证已放在仓库内：

- [`assets/fonts/fusion/fusion-pixel-8px-monospaced-zh_hans.ttf`](assets/fonts/fusion/fusion-pixel-8px-monospaced-zh_hans.ttf)
- [`assets/fonts/fusion/fusion-pixel-12px-monospaced-zh_hans.ttf`](assets/fonts/fusion/fusion-pixel-12px-monospaced-zh_hans.ttf)
- [`assets/fonts/fusion/OFL.txt`](assets/fonts/fusion/OFL.txt)
