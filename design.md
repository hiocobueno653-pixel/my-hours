# Design — 时页 TIMEPAGE

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

---

# v3 — FlClash 蒸馏语言（2026-11-11）

以 `E:/蒸馏/FlClash_UI` 的移动端令牌与版式测量为基线，覆盖 v2 的
Soft UI / Liquid Glass / Bento。只取数值与布局事实，不引入 GPL 代码或资源
（见 `docs/adr/0004-flclash-visual-language.md`）。

## Theme（v3）

| 角色 | 亮色 | 暗色 |
| --- | --- | --- |
| page | `#EFEDF0` | `#131315` |
| card | `#FCF8F9` | `#252628` |
| block | `#EFEDF0` | `#323235` |
| inset | `#E4E2E4` | `#404042` |
| text / text2 / text3 | `#1B1B1E` / `#414755` / `#717786` | `#F8F6F8` / `#C1C6D7` / `#8B90A0` |
| primary / onPrimary | `#007AFF` / `#FFFFFF` | `#2F83FF` / `#FFFFFF` |
| primaryContainer / on | `#D8E2FF` / `#0E448E` | `#0E448E` / `#D8E2FF` |
| income / expense | `#006E1C` / `#BA1A1A` | `#78DC77` / `#FFB4AB` |
| divider | `rgba(27,27,30,.14)` | `rgba(248,246,248,.14)` |

- 用填充区分 page / card / block / inset 四级，不用描边。
- 蓝色只做选中、主操作、链接；金额仍用收入绿 / 支出红。
- 卡片阴影为极轻三层投影；暗色用两级黑影。

## Typography（v3）

- UI 字体走平台系统字体（Android Roboto + 系统中文字体），不再加载 Outfit 字体族。
- 页面标题 24/30 w600；卡片标题 15/20 w600；正文 15/20；脚注 13/18；
  小标签 11–12；大数字 28–34，`tabular-nums`。

## Shape（v3）

- 所有容器使用超椭圆：`RoundedSuperellipseBorder`。
- 卡片 28；主视觉卡 32；sheet 顶部 34；Dock 31；分段块 14–18；胶囊 999。

## Shell（v3）

- 移动端：62px 浮动 Dock，4px 内边距，左右 21px，底部 `max(12, safe-6)`；
  单目标最大 86，图标 26，标签 10/14；选中项为 block 填充 + primary 图标/标签。
- 宽屏（≥720dp）：左侧侧栏 220（≥900dp）或 76；chrome 底 + 右分割线；
  选中项 3×16 primary 指示条；主内容保留页面 bar。
- Tab 切换：220ms 交叉淡入；页面保活，隐藏页不接指针/焦点。

## Header / Surface（v3）

- 页面 bar 高 72（不含状态栏），页面色实底，底部 18px 渐变淡出。
- 标题左对齐，24/30 w600；操作按钮 44×44，透明底，按压 10% 墨迹。
- 二级页返回按钮 44×44 block 底；标题 20/25 w600。
- sheet：card 底、顶部 34 超椭圆、36×5 拖拽条、17/22 标题、36×36 关闭键。
- 弹窗：310 宽、28 超椭圆、card 底、双块面按钮；危险操作红字 + 浅红底。

---

# v4 — 时页 TIMEPAGE 品牌（2026-11-14）

品牌从「时账」升级为「时页 / TIMEPAGE」。v4 覆盖 v3 的色值与启动视觉；
字体族、数据契约和功能骨架不变。品牌决策见
`docs/adr/0006-timepage-brand.md`。

## Theme（v4）

| 角色 | 亮色 | 暗色 |
| --- | --- | --- |
| page | `#F3F5F9` | `#0B1120` |
| card | `#FFFFFF` | `#151D2E` |
| block | `#EDF1F7` | `#1E293B` |
| inset | `#E2E8F2` | `#273449` |
| text / text2 / text3 | `#111827` / `#4B5563` / `#667085` | `#F8FAFC` / `#C7D2E5` / `#8FA0B9` |
| primary / onPrimary | `#2563EB` / `#FFFFFF` | `#6D9EFF` / `#FFFFFF` |
| primaryContainer / on | `#DBEAFE` / `#1E3A8A` | `#1E3A8A` / `#DBEAFE` |
| income / expense / warning | `#047857` / `#DC2626` / `#B45309` | `#34D399` / `#F87171` / `#FBBF24` |
| divider | `rgba(17,24,39,.14)` | `rgba(248,250,252,.14)` |

- 浅色背景改为冷灰蓝，卡片使用纯白；深色背景使用深蓝夜色，禁止中性的
  纯黑/纯灰导航材质。
- 品牌蓝只用于主操作、选中态、链接与关键数字；收入绿 / 支出红 / 结算
  琥珀仍是唯一语义色。
- 顶栏胶囊、下载/新增/分类按钮使用同一套 `HeaderGlassSurface` bright
  材质：白到 `#F8F9FC` 渐变、1.5px 白边、轻投影和内侧顶高光；不再混用
  灰底与透明底。

## Brand assets（v4）

- 应用图标：用户提供的蓝色日历 `TP` 立体图标；Android 自适应图标背景
  `#FBFDFF`，移除 monochrome 引用以保留彩色主题图标。
- 原生开屏：Android 12+ 图标 + 底部 `TIMEPAGE` branding image；旧版
  Android 使用同一字标的 splash drawable。深色系统使用 `#0B1120` 底与
  浅色字标。
- Flutter 加载页：`loading_wordmark.png` 作为擦除动画主体；1900ms 一个
  完整周期，启动页最低停留 2000ms，至少完整播放一次。字标擦除到尾部留下
  笔点，再平滑聚合；`reduceMotion` 下只显示静态字标。

## Welcome（v4）

- 首启欢迎页顺序：中英文字标 →「时间页 · 本地优先」小胶囊 →
  「记录时间，记下生活。」标题 → 说明 → 三张 22px 圆角能力卡 → 本地
  隐私说明 → 底部 56px 蓝色高光「开始使用」。
- 三张卡分别用品牌蓝（日历记工）、收入绿（工资核算）、结算琥珀（收支）
  作为图标语义色；背景为白卡 + 白描边 + `0 6px 20px rgba(15,23,42,.03)`。
- 入场：标题/卡片/按钮以 70–120ms 错峰从下往上淡入，曲线
  `easeOutCubic`；无动画偏好时直接显示终态。

## Density（v4）

- 本月日历：7 列等宽、`mainAxisSpacing: 2`、`childAspectRatio:
  1.50 / textScale`；保留 44pt 横向命中宽度，纵向行高收紧，减少空行。
- 月历选中态仍为 14px 圆角、白边、蓝色微立体渐变；未记工日期不画
  长横线，只留呼吸空间。
- 宽屏侧栏展开态显示应用图标 +「时页」+ TIMEPAGE + Slogan；收窄态只
  显示图标。移动端悬浮 Dock 仍是 68px 液态玻璃胶囊。

## Motion / Press（v3）

- 按压只做 10% 内容色墨迹，200ms 淡入淡出；不缩放。
- 页面切换 220ms easeInOut；主题切换 200ms；sheet 约 300ms。
- 顶栏不做逐帧 BackdropFilter；Dock 保留真模糊 + 饱和提升 + 白色内高光。

## Icons（v3）

- 底部导航、页面操作、列表图标继续使用现有 Material 图标与原有应用图标。
- 不引入 FlClash 的 Glyph 资源或 prism_ui 图标引擎。

---

# v3.1 — 液态玻璃与动效收口（2026-11-12）

覆盖 v3 中与当前实现冲突的静态描述；颜色、字体、间距令牌不变。

## Header

- 顶栏是「视频式雾化遮挡」而不是实色：单一 sigma 16 高斯模糊 +
  白/页面色 98%→0 的纵向渐隐；标题 26/32.5 w700，内容从雾层下穿过。
- 空白遮罩用 `AbsorbPointer`；高对比度模式退回页面色实底；不使用
  ProgressiveBlur 的多条 shader，避免首帧加载额外 shader。

## Dock

- 68px 浮动胶囊，左右 20px，最大宽 356，底部 `max(20, safeBottom+8)`；
  使用 FluidGlass
  `LiquidBottomTabs`，不是普通 `GlassSurface`。
- 选中镜片静止为行高 56 的超椭圆；按住放大到 78/56，跟手横向拖动，
  松手按弹簧回到最近 Tab；镜片内是放大并染成品牌蓝的 Tab 副本。
- 底层 Tab 始终中性色，不随 `active` 变蓝；蓝色只存在于移动镜片内的
  放大副本，拖动时原位置不会残留蓝色。
- 图标 24.5、标签 10.5；再次点击当前 Tab 滚回顶部，切换/回顶带轻触觉。
- ARM/ARM64 且设备分级允许时使用 `liquid`：真实边缘折射、色散、镜面
  高光；x86_64 模拟器、非 Android 或低端设备使用 `plain`：高斯模糊 +
  半透明染色，保留同样的位移/放大/回弹。

## Controls

- `HeaderGlassSurface` 统一顶栏材质：浅色 block 面、深色更亮 block 面，
  加轻投影、白色内高光和超椭圆边，不套第二层 BackdropFilter。
  `GlassIconButton` 44×44 圆形；sheet 关闭使用 36×36 紧凑档，按压 0.94。
- 月份翻页是单颗 44px 玻璃胶囊（左右箭头 + 月份 + 展开箭头），仍然
  位于标题行原位置；下载/新增/分类/导出共用同一颗圆钮材质。
- 主按钮/次按钮走 FluidGlass `LiquidButton`，但质量钉为 `plain`：
  不逐颗编译折射 shader，保留玻璃模糊、按压形变和光晕。
- 分段控件只有一个滑动指示器（220ms），文字颜色同步过渡；分类筛选、
  月份格、年份快捷块使用 180–220ms 颜色过渡。
- 月份标签切换用 220ms 淡出上移 + 淡入落定；Tab 页面切换用 220ms
  方向性横移 + 淡入淡出，隐藏页保持保活但不接指针/焦点。

## Overlays

- 确认框：sigma 18 全屏高斯模糊 + 16% 黑色遮罩，180ms 淡入，
  0.92→1 缩放；按钮为 46px 胶囊，保留白色内高光。
- 底部 sheet：sigma 20 全屏高斯模糊 + 18% 遮罩，300ms 淡入，
  8% 上滑；关闭、下滑、返回键共享同一 `guard` 语义。
- sheet 根节点包透明 `Material`，否则 `MaterialApp` 的 fallback
  错误文字样式会给正文添加黄色双下划线。

## Performance

- x86_64 模拟器冷启动：`liquid` 约 15s → `plain` 约 2.6s；
  这是 ABI 自动降级的原因。
- 页面 `BackdropLayer` 运动采样上限 1.5x，`changeMargin` 24；
  静止时保留设备原分辨率。
- 浅色 tertiary 文本使用 `#666C7A`（页面/卡片对比度约 4.5/5.0），
  不再使用低于小字可读阈值的 `#717786`。
- 系统文本缩放与应用大字模式相乘，全局上限 1.30；图表和进度条提供语义摘要。

---

# v3.2 — 体验与能效收口（2026-11-14）

覆盖 v3.1 中已经实现的顶栏描述；颜色、字体、间距令牌仍不变。

## Header

- 顶栏玻璃层改用 `ShaderMask(dstIn)` 做整体纵向羽化，模糊层和染色层
  一起渐隐，去除固定高度裁切产生的水平硬边。
- 玻璃带按设备能力自动降档：liquid 7 段 / plain 5 段 / 减少动效 3 段，
  最大 sigma 分别为 20 / 15 / 12；高对比度仍退回页面色实底。
- 标题行顶部保持高不透明度雾层，滚动内容只保留轮廓，不再透出可读文字。

## Controls

- 浅色主题的 page 与 block 同值，因此放在页面上的搜索框、筛选胶囊、
  年份翻页按钮和说明块统一改用 `inset` 面，避免控件在背景里消失。
- 搜索清除、回到本月改用 `Pressable` 自绘反馈；不再使用关闭 splash 后
  没有任何按压反馈的 Material `IconButton` / `TextButton`。
- `Pressable` 的触觉反馈从按下沿移到点击成立时；滚动列表起手不会误震。
- `Pressable` 暴露无障碍 button/tap 语义；所有带自定义 label 的按钮
  同时提供语义 `onTap`，隐藏 Tab 的语义树被排除。

## Overlays

- 确认框和 sheet 的模糊强度按设备分级：liquid 18/20，plain 或减少动效
  10/11；遮罩仍保留，以维持焦点层级。
- 主题切换使用零时长，不触发整页 200ms 渐变。

## Flow

- 今天卡「记一笔」在切到记账页后，直接以当天日期打开编辑器；
  不再丢失日期上下文，并用单次开启锁避免叠出两个弹层。
- 日期详情/编辑流同样加开启锁；等待异步弹窗后先校验 mounted 再写状态。
- 首次启动只读取一次本地文档，启动对账复用同一个 `LoadResult`。
- 数字输入最多两位小数，非法第三位/多个小数点会在输入层被拒绝。
- 「我的」页移除被 Dock 遮挡的版本脚注；版本仍在设置页展示。

---

# v3.3 — 欢迎页、Bento 与遮罩修订（2026-11-15）

## Onboarding

- 首帧加载页继续使用 TIMEPAGE 手写擦除记号，周期 1900ms；减少动效时
  冻结在 0.95 的静态字标。深色模式使用白色字标资源，不直接给原图
  整体着色。
- 欢迎页使用主题化径向环境光与 1+2 Bento：本周预览、本地离线、
  8h/10h 预设；底部主按钮 56px，按压 0.97，点击触发中等触觉。
- 欢迎页到首页使用 Shared Axis Z 轴：首页 30%–100% 淡入并从 1.03
  落位；欢迎页 50%–100% 淡出并向深处退到 0.96。`transitionBuilder`
  内不再二次包 Curve。

## Home

- 首页改为 1+2 Bento：今日大卡占 55%，右侧月工时/月工资各占一半高度。
  今日大卡提供 `+0.5h` / `+1h` / `8h` 快捷记工。
- 日历格统一三层：日期 + 结算点、工时胶囊、备注/日薪标识。未记录日期
  不再显示短横线，只保留 3px 淡点；工时 ≤8h 使用收入绿，>8h 或已结算
  使用琥珀色。
- 今天为 14px 超椭圆浅蓝渐变块，白色 1.5px 描边 + 内高光 + 蓝色轻投影。
- 日历行距 6px，图例前增加 1px 发丝分割线。

## Overlays

- 确认框与 Sheet 背景**只渐暗，不做高斯模糊**。遮罩为全屏
  `ColoredBox`，仅透明度随入场动画变化，不从下往上移动。
- 弹窗从最近一次点击坐标进入，关闭时沿同一路径反向返回；连续弹窗
  必须一次性消费坐标，避免复用旧起点。
- 关闭键、顶栏圆钮、顶栏月份胶囊共用 `HeaderGlassSurface`；浅色顶栏
  为纯白高光玻璃，深色为暗玻璃，不再出现灰底和材质不统一。

## Motion

- 隐藏 Tab 在淡出结束后才 Offstage，期间保留 `TickerMode` 以完成过渡；
  结束后同时退出布局、绘制与 ticker。
- 透明度、颜色插值禁止使用会过冲的弹簧曲线；位置/缩放可以使用轻微
  弹性。
- 数字使用 `AnimatedNumericText`（220ms `easeOutCubic`，
  `tabularFigures`）；保存、结算、快捷记工触发轻触觉。
