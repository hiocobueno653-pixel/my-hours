# ADR-0004：采用 FlClash 蒸馏包的视觉语言

- 状态：已采纳
- 日期：2026-11-11
- 相关：`E:/蒸馏/FlClash_UI/`、ADR-0002、`flutter_app/lib/core/theme_tokens.dart`

## 背景

React 版冻结后，Flutter 客户端仍是上一套 Soft UI / Liquid Glass 视觉：
浮动玻璃 Dock、白高光描边卡片、Outfit 字体、26px 普通圆角。它和
`E:/蒸馏/FlClash_UI` 里 FlClash v0.9.3 的移动端语言差异明显。

FlClash 移动端的核心特征：

- 冷灰页面 + 近白卡片 + 更深一档的 block/inset，用填充区分层级；
- 单一 seed `#007AFF` 生成的 vivid 配色，蓝色只做强调；
- 28–34px 连续圆角，卡片几乎无描边；
- 72px 页面 bar、24/30 w600 标题、62px 浮动 Dock；
- 按压只做 10% 墨迹，不做缩放；
- 字体走平台系统字体，数字 tabular。

## 决策

Flutter 客户端切换到 FlClash 的**数值与布局语言**，并保留本应用自己的
业务结构、Material 图标与应用图标。

落地的令牌（详见 `theme_tokens.dart`）：

| 项 | 亮色 | 暗色 |
| --- | --- | --- |
| page | `#EFEDF0` | `#131315` |
| card | `#FCF8F9` | `#252628` |
| block | `#EFEDF0` | `#323235` |
| inset | `#E4E2E4` | `#404042` |
| primary | `#007AFF` | `#2F83FF` |
| text | `#1B1B1E` | `#F8F6F8` |

- 圆角：`xs 4 / sm 8 / md 16 / lg 20 / xl 24 / xxl 28 / alert 34 / pill 999`，
  所有容器使用 `RoundedSuperellipseBorder`。
- 字体：平台系统字体；13 级字号从 40 到 11，页面标题 24/30 w600。
- 外壳：移动端 62px 浮动 Dock（4 内边距、21 左右外边距、26 图标、10 标签）；
  宽度 ≥720dp 时切换为 220/76px 侧栏。
- 页面切换：220ms 交叉淡入，保留各页状态。
- 顶栏：页面色实底 + 底部 18px 渐变淡出，不做每帧 BackdropFilter。
- 按压：10% 内容色墨迹、200ms，无 scale。

## 许可边界（硬约束）

`FlClash` 与 `prism_ui` 都是 **GPL-3.0**。本次只使用 `FlClash_UI` 文档与
`tokens/tokens.json` 中的**测量值与颜色数值**，不复制：

- `prism_ui` 或 FlClash 的 Dart 源码；
- 着色器、Glyph 路径、图标、字体、图片；
- 组件实现或动画代码。

`pubspec.yaml` 仍不得出现 `prism_ui`。本应用继续使用 Flutter 原生
`RoundedSuperellipseBorder` 与自绘组件，图标沿用原有 Material 图标，
`android/` 下的应用图标资源未改动。

## 后果

正面：

- 与 FlClash 的移动端观感对齐，同时不引入 GPL 传染。
- 去掉了顶栏逐帧模糊和 Dock 液态透镜，低端机渲染成本更低。
- 令牌集中在 `theme_tokens.dart`，后续换 seed 或风格只改一处。

负面：

- 只实现 vivid + `#007AFF` 一套配色，没有 FlClash 的 tinted/soft/monochrome
  与动态取色；需要时再扩展。
- 系统字体让拉丁数字不再有 Outfit 的品牌感；`assets/fonts/Outfit.ttf`
  不再声明为字体族，后续可清理。
- 宽屏侧栏是精简版（3 个业务项），没有 FlClash 的展开/收起动画与更多菜单。

## 验收

- `flutter analyze` 零 issue，`flutter test` 91 个用例通过。
- 390×844 移动端：记工/记账/我的三页、编辑弹层、深色模式截图验收。
- 1000×600 宽屏：侧栏 + 内容区布局截图验收。
- 应用图标、底部 Material 图标与原有资源未替换。
