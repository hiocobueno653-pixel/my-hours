# Agent 重构方案执行记录（1.7.2）

对照 `My Hours Agent Refactoring Plan.md` 与 `My Hours Onboarding Transition Plan.md`，本轮逐项落地并在 Flutter / React 两端验证。

## M1 数据精度

- Flutter 与 React 的金额、工时统一走百分位定点换算，半值按远离零方向舍入。
- 单日工资、月度工资、结算汇总、年度趋势均先累加整数分再转元。
- 覆盖 `1.005`、`-1.005`、大批量聚合与双端对账测试。

## M2 持久化

- 本地存档改为逐条容错：外层标识/版本/JSON 损坏仍整份回退；单条坏记录跳过并记录 `droppedItems`。
- 备份导入同步采用容错解析；全部条目都无效时仍拒绝导入，避免空文件覆盖现有数据。
- 启动提示会明确显示“已跳过 N 条无法识别的本地记录”。
- 每日快照优先 `rename` 原子替换，Windows 才回退到删除后替换。
- 普通编辑使用 `300ms` 合并写盘；导入、清空、重试保持立即落盘。应用进入后台/销毁时调用 `flushPendingPersist()`，避免最后一次编辑丢失。

## M3 状态与渲染

- `AppController.build()` 的启动对账写盘改为 `Future.microtask`，不再在 build 内同步 IO。
- 首页统计通过 `currentMonthWorkSummaryProvider` 按月派生；页面只订阅 `records` / `entries` / `workProfiles` 的必要切片。
- Bento 概览拆到 `work_bento_header.dart`；日历拖动由独立 `_SwipeableCalendarState` 持有 `_dragDx`，拖动时不会重建首页 Bento。
- 已构建 Tab 缓存 Widget 实例；切走后先完成淡出，再 `Offstage` 并关闭 `TickerMode`，隐藏页不参与布局、绘制和 ticker。

## M4 动效

- `MotionOrigin.consumeRecent()` 一次性消费点击坐标，连续弹窗不再复用旧起点。
- 弹窗/Sheet 的位置、缩放与透明度使用不同曲线；透明度使用无过冲的 `easeOutCubic`。
- 弹窗背景只做全屏渐暗，不做高斯模糊；Sheet 背景同样只渐暗。
- 关闭动画沿入场路径反向返回，避免从屏幕边缘凭空消失。

## UI / 动效升级

- 首页 1+2 Bento：今日大卡 + 本月工时/工资双小卡，支持 `+0.5h` / `+1h` / `8h` 快捷记工。
- 日历三层：日期与结算点、按状态着色的工时胶囊、备注/日薪标识；未记录日期只留 3px 淡点。
- 四套主题色 `vivid / atmospheric / soft / monochrome` 的 `page / card / block / inset` 保持独立明度层级，并校验主按钮文字对比度。
- 数字使用 `AnimatedNumericText` 滚动；保存、结算、快捷记工均有轻触觉反馈。
- Flutter Dock 使用液态玻璃胶囊：长按放大、跟手拖动、弹簧回位、折射与色散；普通磨砂回退时补白色内高光。
- React 首页同步 Bento 与日历三层视觉，保留原有数据契约与冻结基线。

## 启动与欢迎页

- 首帧立即显示 TIMEPAGE 品牌加载页，数据准备完成后 `280ms` 淡出。
- 加载记号支持深浅色资源、主题色描边与“减少动效”静态降级（冻结在 0.95）。
- 欢迎页使用主题化径向环境光、1+2 Bento 预览、8h/10h 预设与弹性交错入场。
- 欢迎页到首页使用 Shared Axis Z 轴转场；Dock 延迟 `80ms` 上浮，避免首页一次性全部出现。

## 验证

- `flutter analyze`：通过
- `flutter test`：162 项通过
- `npm test`：103 项通过
- `npm run build`：通过
- `npx oxlint src scripts`：通过
