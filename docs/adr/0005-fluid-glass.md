# ADR-0005：用 FluidGlass 实现真实液态玻璃

- 状态：已采纳
- 日期：2026-11-11（2026-11-12 更新）
- 相关：ADR-0002、ADR-0004、`flutter_app/pubspec.yaml`

## 背景

仅用 `BackdropFilter` + 半透明白面 + 高光描边，只能得到磨砂玻璃，缺少
真正的边缘折射、色散和方向性镜面高光。底部 Dock 和顶部栏需要更接近
iOS 26 / FlClash 的液态玻璃，而不是「透明模糊卡片」。

## 决策

引入 **FluidGlass 0.5.7**（Apache-2.0）：

- 底部 Dock 使用 `LayerBackdrop` + `LiquidBottomTabs`，开启 vibrancy、blur、
  lens 折射和标准 rim/shadow；选中镜片支持长按 78/56 膨胀、跟手拖动、
  跨 Tab 弹簧回位、放大高亮副本和色散边；
- 顶部栏继续使用轻量 `BackdropFilter` 玻璃，避免每个页面再复制一份
  backdrop capture；
- 页面内容用 `BackdropLayer` 提供可采样源，Dock 在页面之上做真实折射；
  运动时用较低 `motionPixelRatio` 采样，静止后恢复清晰；
- 保留本应用自己的图标、颜色令牌和 FlClash 布局，不使用 FluidGlass 的
  组件皮肤来替换整个设计系统。
- 质量分级交给 `GlassDeviceTier`，不强行把所有设备钉在 `liquid`；
  Android x86_64 模拟器/非 ARM 环境强制 `GlassQuality.plain`，避免多个
  fragment program 造成冷启动阻塞；`MYHOURS_PLAIN_GLASS=true` 可再次
  强制普通玻璃，用于低端机验证。

## 许可

FluidGlass 及其上游 AndroidLiquidGlass / Shapes / coui17 均为 Apache-2.0，
与本仓库的 GPL 规避约束兼容。声明见 `flutter_app/THIRD_PARTY_NOTICES.md`。
`prism_ui` 仍是 GPL-3.0，继续禁止引入。

## 后果

- Dock 在支持 Impeller 的 ARM 设备上有真实折射；不支持 runtime shader
  时 FluidGlass 自动退化为模糊/色调，不会崩溃。
- x86_64 模拟器实测：`liquid` 冷启动约 15 秒，`plain` 约 2.6 秒；
  因此不能在所有构建目标上无条件启用折射。
- 页面内容会被 `BackdropLayer` 采样，滚动时通过其 ScrollNotification
  自动失效缓存；低端 ARM 由 `GlassDeviceTier` 决定是否降到 plain。
- 顶部栏仍是玻璃模糊而非折射，避免每页重复 capture；如需顶部折射，下一步
  应把页面 body 与 header 拆成独立 backdrop 源。
