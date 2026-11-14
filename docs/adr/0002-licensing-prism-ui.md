# ADR-002：prism_ui 采用「路线 C：许可白名单 vendor + 其余自研」

- 状态：已采纳（Flutter 版 v1）
- 日期：2026-11-08
- 相关：`E:/蒸馏/prism_ui/`、`E:/蒸馏/FlClash_UI/docs/03-动效系统.md`

## 背景

`E:/蒸馏/prism_ui` 是 Flutter 的 iOS 风格自绘设计系统（145 文件 / 1.43 MB），提供液态玻璃着色器、浮动 Dock、snap sheet、超椭圆圆角、HCT 配色等。它同时是 FlClash 的 UI 底座。

问题在于许可：

- `prism_ui` 整体为 **GPL-3.0**（`pubspec.yaml` + 仓库 LICENSE）。
- Dart AOT 编译产物是单一作品，没有动态链接豁免——`dependencies: prism_ui` 会让整个 APK 落入 GPL-3.0，分发即须提供全部源码，且不可撤回。
- 本仓库当前**没有 LICENSE 文件**（默认保留所有权利）。引入 GPL 依赖是单向门。

同时，prism_ui 是一整套设计系统：自带 `text_field.dart`（52 KB）、`popup.dart`（92 KB）、自绘图标引擎、HCT 配色，并明确「不基于 Material/Cupertino」。整体采用意味着中文 IME、文本选择手柄、日期选择器、触感全部换实现——这些恰好是可用性风险最高的部分。

## 决策

采用**路线 C（混合）**：

**允许 vendor（逐文件核对过文件头）：**

| 路径 | 许可 | 用途 |
|---|---|---|
| `lib/hct/` | Apache-2.0（Google） | HCT 色彩空间与动态配色 |
| `lib/shapes/` | MIT | 超椭圆 / 连续曲率圆角 |
| `lib/sliver_list/` | MIT | 高性能可变高度列表 |
| `lib/navigator_resizable.dart` | MIT | 可调整尺寸的 Navigator |
| `shaders/ink_sparkle.frag` | BSD-3（来自 Flutter） | 按压火花 |

**禁止引入（GPL-3.0）：** `liquid_glass.dart`、`liquid_glass_capture.dart`、`navigation_dock.dart`、`snap_sheet.dart`、`popup.dart`、`page_transition.dart`、`press_sparkle.dart`、`text_field.dart`、`dialog.dart`、`sheet.dart` 及其余未列入白名单的文件。

**动效数值不是代码：** `03-动效系统.md` 里的时长、曲线、弹簧参数是测量值（事实），可自由实现为 `core/motion.dart` 的常量，不构成对 GPL 代码的复制。

## 后果

正面：

- 无 GPL 传染，分发形态自由。
- 保住超椭圆圆角与 HCT 配色这两项「看起来像 iOS」的关键细节。
- 中文 IME、文本选择、日期选择器继续用 Flutter 原生实现，避开最大的可用性风险。

负面：

- 液态玻璃需要自研：v1 用 `BackdropFilter` + 半透明 tint + 1px 描边 + 线性高光近似（观感约九成，成本约 2%）；着色器版仅在 API 24–26 真机帧率达标后评估。
- Dock 的果冻形变、透镜放大、光晕需要自己实现（可参考测量参数，不参考代码）。
- 需要维护一份白名单，并在升级时重新核对文件头。

## 执行约束

1. `pubspec.yaml` 只允许出现白名单依赖；**不得**出现 `prism_ui`。
2. vendor 目录集中放在 `third_party/`，每个子目录保留原始 LICENSE 与文件头，并在根 `NOTICE` 登记来源、版本、许可。
3. CI（或本地检查脚本）grep `pubspec.yaml` 与 `third_party/`，出现未登记路径即失败。
4. 若未来确需 GPL 组件，必须先开新 ADR 并明确「整个 APK 转 GPL-3.0」的后果。

## 验收

- `NOTICE` 列出 5 个来源，每项可追溯到文件头证据。
- `pubspec.yaml` 无 `prism_ui`。
- `third_party/` 内不存在白名单外的 prism_ui 文件。
