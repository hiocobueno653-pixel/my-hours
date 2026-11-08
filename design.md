# Design — 我的工时（My Hours）

A locked design system for this app. Every page redesign reads this file before
emitting code. Do not regenerate per page — extend or amend this file when the
system needs to grow.

## Genre

modern-minimal（工具型 App / 个人数据仪表盘）。

## Macrostructure family

一个 App 页面的基础架构：**Workbench**（数据工作台）——页面由一组功能性的数据卡片构成，
不靠营销文案，靠"数据在眼前、操作在手边"。三个 Tab（记工 / 记账 / 我的）共享同一种卡片
语言，只变化卡片内的内容与操作。

- App pages: Workbench — 变体旋钮 = 每页主卡的数量、密度、操作位
- Content pages（设置 / 分类管理 / 工作管理 / 备份）: 弹出层表单，遵循同一表单原语

## Theme

Cobalt 系（冷蓝石板 · 电光钴蓝强调）。浅色为带蓝调冷纸，深色为带蓝调深纸。
 两种模式使用同一蓝色系锚点，只移动明度与彩度。

- `--color-paper`   oklch(96% 0.008 258)   /* #edf2f8 冷蓝石板背景 */
- `--color-paper-2` oklch(99% 0.004 258)   /* 卡片表面，微蓝白 */
- `--color-ink`     oklch(21% 0.03 262)    /* 主文字，带蓝调深蓝灰 */
- `--color-ink-2`   oklch(45% 0.02 260)    /* 次级文字 */
- `--color-ink-3`   oklch(58% 0.015 258)   /* 弱化文字 */
- `--color-rule`    oklch(88% 0.012 258)   /* 边框 */
- `--color-accent`  oklch(52% 0.18 262)    /* 电光钴蓝 —— 高亮器 */
- `--color-accent-2` oklch(60% 0.13 262)   /* 强调柔化（选中态背景） */
- `--color-income`  oklch(52% 0.12 152)    /* 收入/入账语义 */
- `--color-expense` oklch(52% 0.15 25)     /* 支出语义 */
- `--color-gold`    oklch(58% 0.11 75)     /* 工资/金额语义（第二强调） */
- `--color-focus`   oklch(58% 0.19 262)

**强调纪律**：accent 是"高亮器"，不是"填充块"。占据每个视口 ≤ 5%。主操作按钮可填充，
但次级一律用边框/文字色。金色仅用于"钱/工资"数字与进度——永不用于装饰。

## Typography

- Display / Body: Outfit Variable（项目已在用，`@fontsource-variable/outfit`）
  - display 用 700–850，`letter-spacing: -0.035em` ~ `-0.02em`
  - body 用 400–650，`letter-spacing: 0`
- Mono（outlier，仅用于大数字/金额）: 不引入新字体，用 `font-variant-numeric: tabular-nums`
  保证数字对齐
- Type scale: 1.25（major third），从 16px body 起
- 数字一律 `font-variant-numeric: tabular-nums`
- 禁止斜体标题；强调用字重与颜色承载

## Spacing

4pt 命名刻度（见 tokens.css）。页面必须用命名令牌 `var(--space-*)`，不写裸 px。

## Motion

- 曲线：`--ease-out: cubic-bezier(0.16, 1, 0.3, 1)`；`--ease-spring` 仅用于入口与液体镜头
- 时长五档：press 140ms / micro 120ms / short 220ms / medium 340ms / exit 280ms
- Reveal: 页面进入时一次 orchestrated entrance（stagger ≤ 500ms）；之后不再滚动触发
- Reduced-motion: 所有空间动效折叠为 ≤150ms 透明度 crossfade
- Navigation lens: active tab lens 使用 transform 过渡，切换从当前位置移动；禁止 bounce

## Navigation material

- Bottom navigation: Apple Liquid Glass 风格的浮动胶囊，不是贴边不透明栏
- Light mode: semi-transparent white material + blur/saturate + top specular edge
- Dark mode: dark translucent material remains dark; never反白成浅色导航
- Active state: independent lens surface with highlight/refraction; active label/icon uses high contrast
- Content extends behind the material; main content reserves safe bottom space
- `prefers-reduced-transparency: reduce`: remove blur and use opaque surface
- `prefers-contrast: more`: opaque surface + explicit border
- Each tab: minimum 44px hit target, short label + familiar icon, exactly one selected tab

## Material discipline

- Liquid Glass 只用于底部导航、sticky 页头、弹层；内容卡片不叠加毛玻璃
- 内容卡分层：表面色差 + 发丝边框 + 轻接触投影，不堆叠镜面高光
- 阴影使用 Apple 双层投影：
  - --shadow-sm 内容卡/小控件：0 1px 2px / 4%, 0 8px 24px / 5%
  - --shadow-hover 指针悬停：0 2px 4px / 5%, 0 12px 32px / 10%
  - --shadow-nav 底部导航：0 2px 8px / 10%, 0 18px 44px / 14%
  - --shadow-sheet 底部弹层：0 -2px 8px / 8%, 0 -30px 80px / 18%
  - --shadow-overlay 对话框/toast：0 2px 8px / 10%, 0 30px 80px / 24%
- 卡片圆角：--radius-s/m/l/xl = 10/14/20/26px，按钮/胶囊 999px
- prefers-reduced-transparency：玻璃转实色、去掉 blur；prefers-contrast: more：实色 + 明确描边
- 移动端模糊降载：页头 16px、滚动后 20px；底部导航 24px，避免中低端 GPU 掉帧

## Microinteractions stance

- silent success：保存/删除成功后不加庆祝 toast，结果可见即足够
- 删除走乐观删除 + Undo（项目已实现撤销条，保留）
- hover 提示 800ms 延迟；focus 0ms
- 数字展示用 tabular-nums，不做计数动画（数据刷新场景极少）

## CTA voice

- Primary CTA: 黑色填充（浅色）/ 白色填充（深色）+ `--accent-ink` 对比文字，短词（"保存"/"记一笔"）
- Secondary CTA: 表面 + 边框（ghost），同形状同 padding 节奏
- 危险操作: 红色文字 + 边框，实心红仅用于确认对话框的确认键

## Per-page allowances

- App pages MUST NOT use enrichment — 功能即页面，无装饰性配图/动画背景
- 允许克制的品牌背景光晕（浅色顶部一抹蓝），禁玻璃拟态、禁装饰性渐变卡片

## What pages MUST share

- 黑白灰主系统；收入绿 / 支出红是唯一语义彩色
- Outfit 字体（display + body 同一家族）
- 页面骨架：页头 + inline month nav；主数据区不使用同款卡片堆叠
- Apple Liquid Glass 底部导航与浅/深材质规则
- 弹出层：底部 sheet，顶部抓取条，radius-xl 顶部圆角；操作区为浮动工具条
- 数字排版：tabular-nums + 收紧 tracking

## What pages MAY differ on

- 记工：不对称月度主视图 + 今日工作区 + 平面月历
- 记账：结余主视图 + 收支流向对照 + 账目明细工具栏
- 我的：月度个人数据带 + 最近工时时间线 + 功能分区
- 操作位的位置（页头工具组 / 主视图 action / sheet footer）


---

# v2 — Soft UI · Liquid Glass · Bento（2026-10 重构锁定）

在 Cobalt 基础上全面演进为轻新拟态 + 液态玻璃 + Bento 卡片语言。
以下规范覆盖上文冲突项；未提及项沿用上文（字体、间距刻度、图表）。

## Theme（v2）

- 页面底色 `#F4F5F7` 冷灰白 —— 禁止纯白底，为白卡高光描边留层次
- 表面 `#FFFFFF` 卡片、`#F7F8FA` 软表面、`#ECEEF2` 弱表面
- 文字 `#111827` 主 / `#6B7280` 次 / `#9CA3AF` 弱
- 品牌蓝 `#2563EB`（选中/主操作/链接/透镜高亮），深色透镜 `#6D9EFF`
- 收入绿 `#12B362`、支出红 `#E53935`、危险确认文字红 `#E53935`
- 内部分割线 `#E5E7EB`；**卡片描边一律白高光** `1px solid rgb(255 255 255 / 90%)`（深色 `rgb(255 255 255 / 8%)`）

## Elevation（v2 —— 无硬黑影）

- 卡片 `--shadow: 0 8px 24px rgb(17 24 39 / 3%)`；小件 `0 4px 12px / 5%`
- 玻璃件（胶囊按钮组/菜单/Dock）：外投影 + `inset 0 1px 2px #FFF` 内高光 + `1.5px solid #FFF` 描边
- 新拟态浮雕（仪表盘中心盘）：`linear-gradient(145deg,#FFF,#F2F3F7)` + 白描边 + 外影/内高光双阴影

## 结构组件（v2）

- **无界悬浮顶栏**：fixed/sticky 透明，无 border-bottom；滚动虚化交给 96px 渐进式模糊遮罩
  （`progressive-blur`，blur 14px + 纵向 mask 羽化，z 在页头之下）。右上胶囊操作组 42px 高玻璃胶囊
- **Bento 网格**：`gap: 12px`、卡片圆角 `--radius-card: 26px`、一大两小（记工页月总计）
- **底部 Dock**：380px（窄屏全宽-24）× 68px、圆角 9999、`rgb(255 255 255 / 74%)` + blur 22 saturate 180、
  bottom 24px；上滑下沉 58px
- **Tab 滑块双态**：静止 = 浅蓝 `rgb(37 99 235 / 12%)` 胶囊无阴影；按住拖拽 = 膨胀
  `scale(1.16, 1.22)` + 水滴凸透镜材质（彩虹内色散 + `url(#liquid-lens)` 湍流置换）
- **双层 clip-path 变色**：`.nav-tint` 品牌色副本层，JS 按透镜窗口实时
  `clip-path: inset(0 calc(100% - R) 0 L round 999px)`，滑过哪哪变色并 `scale(1.07)`
- **上下文菜单**：`.glass-menu`，圆角 22、`rgb(255 255 255 / 80%)` + blur 20 saturate 190 + 湍流置换，
  锚点 `transform-origin: top right`，弹出 `scale(.4)→1` 弹簧 `--ease-menu: cubic-bezier(0.22,1.15,0.36,1)`
- **确认弹窗（HyperOS）**：310px、圆角 28、`#F7F8FA`、内容居中、双胶囊按钮 46px
  灰底 `#E8EAEF`（取消灰字 / 删除红粗体），`scale(.85)→1` 弹簧
- **底部抽屉**：圆角 `28px 28px 0 0`、底色 `--bg`、36×4 拖拽条、头部 36px 浅灰浮雕圆按钮、输入白底浮起

## 动效纪律（v2）

- 所有生长/弹出用 `--ease-menu`（~8% 过冲弹簧）；拖拽跟手 `transition: none`
- `prefers-reduced-motion`: 弹窗/菜单动画折叠至 1ms
