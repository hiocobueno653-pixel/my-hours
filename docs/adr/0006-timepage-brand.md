# ADR-0006：时页 TIMEPAGE 品牌与启动动效

- 状态：已采纳
- 日期：2026-11-14
- 相关：ADR-0003、ADR-0004、ADR-0005

## 背景

产品需要从「时账」升级为「时页 / TIMEPAGE」，并统一应用图标、启动页、
加载动效与首启欢迎页。原图标和启动素材已经不再代表新的产品定位；同时
不能为了改品牌破坏既有数据、升级链路或字体约定。

## 决策

- 中文名：`时页`；英文名：`TIMEPAGE`；品牌 Slogan：`记录时间，记下生活。`
- 应用图标使用用户提供的日历 `TP` 3D 图标；保留现有 Material 图标体系，
  不引入新的图标库。Android 自适应图标移除 monochrome 引用，避免系统
  主题图标把彩色图标强制成单色。
- 原生开屏：Android 12+ 使用新应用图标作为
  `windowSplashScreenAnimatedIcon`，并在底部显示 TIMEPAGE 字标
  （`windowSplashScreenBrandingImage`）；旧版 Android 使用同一套字体标
  drawable。深色系统使用深蓝底与浅色字标，禁止白底白字。
- Flutter 首帧继续显示品牌加载页：字标从左向右被蓝色笔锋擦除，末尾留下
  一个笔点，再平滑聚合并循环；完整周期 1900ms，启动页最低停留 2000ms，
  至少播放一次完整动画。系统「减少动效」时改为静态字标。
- 首启欢迎页使用第二张图的中英文字标、三条能力卡片和底部高光主按钮；
  卡片按 70ms 左右错峰从下往上进入。首次进入写入
  `brandWelcomeSeen`，老用户升级也会看到一次新欢迎页。
- 字体族不因品牌更换而改变：Flutter 继续使用平台系统字体，React 冻结
  基线继续使用既有字体；只更新字号、字重、间距与颜色令牌。
- 数据契约保持兼容：包名仍为 `com.myhours.app`，存储文件仍为
  `my-hours.json`，备份 `app` 字段仍为 `my-hours`。品牌名变化不得改变

## 后续修订（v3.6）

- 删除 Flutter 内 TIMEPAGE 擦除加载页、最低停留与淡出动画。原生 splash
  直接交给欢迎页或主页，避免同一品牌在启动时连续出现两段动画。
  任何持久化标识，否则用户升级会丢数据。

## 品牌色

| 角色 | 亮色 | 暗色 |
| --- | --- | --- |
| brand primary | `#2563EB` | `#6D9EFF` |
| page | `#F3F5F9` | `#0B1120` |
| card | `#FFFFFF` | `#151D2E` |
| block | `#EDF1F7` | `#1E293B` |
| inset | `#E2E8F2` | `#273449` |
| text / text2 / text3 | `#111827` / `#4B5563` / `#667085` | `#F8FAFC` / `#C7D2E5` / `#8FA0B9` |
| income / expense / warning | `#047857` / `#DC2626` / `#B45309` | `#34D399` / `#F87171` / `#FBBF24` |

## 资源来源

- 用户提供的 `app_icon.png`、`welcome_wordmark.png`、
  `loading_wordmark.png` 存放在 `flutter_app/tool/brand_sources/`。
- `flutter_app/tool/generate_brand_assets.ps1` 生成应用内资产、Android
  自适应/传统图标、原生 splash 和 Android 12+ branding image。字标在
  生成时清理低透明度边缘，避免浅色背景出现灰色竖线。
- 用户确认保留现有字体；未新增字体文件。

## 后果

- 启动链路变为：原生图标/字标 splash → Flutter TIMEPAGE 擦除加载 →
  首次欢迎页或主页。加载页不再阻塞首帧，数据在后台读取。
- 品牌名与视觉更新不会改变历史备份、导出数据和包名；旧版可覆盖升级。
- 图标、splash 与 Flutter 资源由同一脚本生成；未来改素材必须同时更新
  脚本、Flutter assets 和 Android drawable/mipmap。
