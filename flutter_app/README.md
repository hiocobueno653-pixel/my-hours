# 时页 TIMEPAGE · Flutter 版

记录时间，记下生活。React + Capacitor 版的 Flutter 重做。数据契约、金额口径与旧版逐项对齐，见
`../docs/adr/`。

## 目录

```
lib/
  data/            纯逻辑层（与 React src/data 一一对应，无 UI 依赖）
  state/           Riverpod 状态与全部写操作（app_controller.dart）
  core/            主题令牌、动效常量、格式化、设置
  ui/              基础原语（卡片/按压面/撤销条/分段/弹层）
  features/
    work/          记工页、日编辑、日详情、月明细、工资面板、预算面板
    ledger/        记账页、账目编辑、分类管理
    mine/          我的页、年度统计、数据与备份、设置
    charts/        4 个 CustomPainter 图表（柱/环/进度/趋势）
  platform/        返回栈、导出与文件选择
test/
  data/            移植自 React 的纯函数用例
  golden/          工资 golden case（表驱动）
  migration/       v4 备份夹具与五项对账
```

## 本地构建

Flutter 3.47.9 在 `E:\tools\flutter`（未进 PATH）：

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
& 'E:\tools\flutter\bin\flutter.bat' pub get
& 'E:\tools\flutter\bin\flutter.bat' analyze      # 必须零 issue
& 'E:\tools\flutter\bin\flutter.bat' test         # 全量用例
& 'E:\tools\flutter\bin\flutter.bat' build apk --release --flavor full
```

产物：`build/app/outputs/flutter-apk/app-full-release.apk`。

> 真机不要安装带 `--target-platform android-x64` 的包：那只包含模拟器引擎，
> ARM 手机上会安装成功但启动即退。真机用上面的通用构建，或：
> `flutter build apk --release --flavor full --target-platform android-arm64`。
> 通用包与 arm64 包的 Gradle 输出同名，先复制/改名通用包，再构建 arm64，
> 否则后一次会覆盖前一次。
>
> 1.5.1 起 `android/app/build.gradle.kts` 会按 Flutter 传入的
> `-Ptarget-platform` 再裁剪插件自带的 jniLibs。单 ABI 包发布前用
> `aapt dump badging <apk>` 确认 `native-code` 只有目标 ABI，避免
> 32 位手机安装后因缺 `libflutter.so` 启动即退。

### 两个变体

| flavor | applicationId | 说明 |
| --- | --- | --- |
| `full` | `com.myhours.app` | 完整版（记工 + 记账 + 我的） |
| `hours` | `com.myhours.app.hours` | 只记工时，可与完整版共存 |

`hours` 变体必须同时传编译期开关，否则只是换了 applicationId、记账页仍在：

```powershell
& 'E:\tools\flutter\bin\flutter.bat' build apk --release --flavor hours --dart-define=HOURS_ONLY=true
```

`state/app_controller.dart` 读取 `kHoursOnly` 后隐藏记账入口与相关按钮。

### 签名

复用旧版 `android/keystore.properties` + `myhours-release.keystore`
（`rootProject.file("../../android/…")`）。同 applicationId + 同签名 +
versionCode 递增 = 可覆盖升级，用户不必换包迁移。

## 数据与迁移

- 存储：应用私有目录下的 `my-hours.json`，原子写 + `.bak`/`.bak.1` 三代轮转。
- 备份：JSON v4（与 React 版同一契约），严格导入——任一条目非法则整份拒绝。
- 迁移：旧版「我的 → 数据与设置 → 保存数据备份」导出 → 新版「数据与备份 → 加载备份数据」导入 →
  自动给出五项对账（记录数 / 账目数 / 本月工资 / 已结算 / 结余），不一致标红。

## 与 React 版的功能对齐

已补齐：月份选择弹层、月环比、回到本月、今天账目、周一起始月历、每日工时/收支/结算圆点、
未来日期禁用、左右滑切月、CSV 导出、记账分类筛选、超预算提示、今天账目行、关联工时、
我的页工资/预算摘要卡、日编辑未来日期拒绝与「休息」快捷档。

仍保留的差异（详见 `../docs/react-flutter-parity.md`）：Excel 导出、自动备份快照、
日编辑前后切日、图表点击选月、二级页右滑返回。

## 品牌与启动

- **品牌**：中文「时页」、英文 `TIMEPAGE`、Slogan「记录时间，记下生活。」
  品牌色 `#2563EB`，色板、素材来源与数据兼容性见
  `../docs/adr/0006-timepage-brand.md`。字体仍走平台系统字体，未新增字体族。
- **启动链路**：Android 原生图标/字标 splash → Flutter TIMEPAGE 擦除加载页
  （1900ms 一个周期，最低停留 2000ms）→ 首次欢迎页或主页。原生启动
  在 Android 12+ 同时显示 `windowSplashScreenBrandingImage`；深色系统
  会自动切换深蓝底浅色字标。
- **首启欢迎页**：使用 `assets/brand/wordmark.png` 的三段式字标、三张能力
  卡和底部高光「开始使用」；老用户升级也会显示一次，标记为
  `my-hours.brandWelcomeSeen`。
- **图标生成**：品牌源图在 `tool/brand_sources/`，运行
  `tool/generate_brand_assets.ps1` 会同时生成 Flutter 资产、Android
  mipmap/自适应图标、splash 与 branding image。字标生成时会清理低透明度
  边缘，避免浅色背景出现灰色竖线。

## 视觉与系统栏规范

- **视觉基线**：FlClash_UI 蒸馏的版式与层叠关系，加上时页品牌色板（page/card/block/inset、`#2563EB`、28–34 超椭圆、72px bar、68px Dock）；只取数值，不引入 GPL 代码，见 `docs/adr/0004-flclash-visual-language.md` 与 `docs/adr/0006-timepage-brand.md`。
- **液态玻璃**：Dock 使用 FluidGlass（Apache-2.0）的 `LayerBackdrop` + `LiquidBottomTabs`，支持长按膨胀、跟手拖动、弹簧回位、放大副本、边缘折射与色散；arm64 真机启用液态层，x86_64 模拟器与不支持 runtime shader 的设备自动退化为高斯模糊玻璃。顶层 Tab 保持中性色，蓝色只由移动镜片里的放大副本显示，拖动后不会在原位置留下蓝色残影。Dock 高 68、最大宽 356、左右 20，底部为 `max(20, safeBottom + 8)`；图标 24.5、标签 10.5。见 `docs/adr/0005-fluid-glass.md` 与 `THIRD_PARTY_NOTICES.md`。
- **沉浸式**：`SystemUiMode.edgeToEdge` + 透明状态栏/导航栏，图标亮度随主题切换（`lib/main.dart` 的 `AnnotatedRegion`）。不做这一步，Android 会给窗口加不透明 scrim，顶部出现一条与页面断开的色带。
- **吸顶顶栏（视频参考版）**：`lib/ui/pinned_header.dart`。单一 sigma 16 高斯模糊 + 白/页面色 98%→0 的纵向渐隐，从物理顶部覆盖完整标题区；标题 26/32.5 w700，内容从白色雾层下穿过。空白遮罩用 `AbsorbPointer`，不会误触背后内容；高对比度模式退回实色。
- **顶栏材质**：`HeaderGlassSurface` 统一所有顶栏按钮——浅色用 block 面色、深色用更亮 block 面色，加轻投影、白色内高光与超椭圆边，不再给按钮套第二层 `BackdropFilter`。月份翻页合并为一颗 44px 玻璃胶囊，仍保留在标题行原位置；下载/新增/分类/导出与二级页返回均为 44px 圆钮，sheet 关闭为 36px 紧凑档。
- **内容按钮**：`PrimaryButton`、`GhostButton`（FluidGlass `LiquidButton`，质量钉为 `plain` 以免每颗按钮编译折射 shader）、`_DialogButton` 都是独立按压面，分别处理 0.94/0.97 缩放、10% 墨迹和 140–220ms 动效。
- **分段控件**：单块品牌色指示器按 `AnimatedPositioned` 滑到选中段，文字颜色用 `AnimatedDefaultTextStyle` 同步淡变；分类筛选、月份格与年份快捷块同样使用 180–220ms 颜色过渡。
- **页面/月份切换**：Tab 内容保活，220ms 按左右方向轻微横移 + 淡入淡出；月份标签使用 `AnimatedSwitcher` 淡出上移、淡入落定；底部 Dock 的镜片移动交给 FluidGlass 弹簧。
- **日编辑**：标题行保留日期两侧箭头，可切前一天/后一天；跨月时同步月份上下文，切到今天后禁用后一天，有未保存输入时先确认。
- **年度统计**：点击每月收支柱状图的月份槽位，会切换下方分类占比月份；选中月份有浅色底带、加粗标签和 `selectionClick` 触觉。
- **导航复用**：再次点击当前 Tab 会滚动该页回顶部（340ms），Tab 切换与回顶带 `selectionClick` 轻触觉；每页用独立 `ScrollController`，切换后保留原滚动位置。
- **弹窗**：确认框全屏 `BackdropFilter` 高斯模糊（sigma 18），180ms 淡入 + 0.92→1 缩放；底部 sheet 高斯模糊 sigma 20，300ms 淡入 + 8% 上滑。sheet 根节点提供透明 `Material`，防止 `MaterialApp` 的 fallback 错误样式给正文加黄色双下划线（已有 widget 测试）。
- **弹层关闭**：`SheetScaffold` 的 `canPop` 绑定 `_allowPop || !_dirty`；无未保存内容时下滑/遮罩/返回键直接关闭，有未保存内容时先弹「放弃未保存的修改？」确认。禁止再用「`canPop: false` + 手动 `maybePop()`」写法——那会让 `Navigator.pop()` 反过来触发 `onPopInvokedWithResult`，形成关不掉的递归。
- **本机自动快照**：每次打开/保存自动留每日一份 v4 快照（保留 7 天）；「数据与备份」可查看并恢复，恢复前会再保留当前现场。清空全部数据会同时删除自动快照和导入前现场副本。
- **弹层手势**：标题/拖拽条支持跟手向下拖动；超过 84px 或快速下滑关闭，未保存内容不会走这条捷径。
- **无障碍**：系统字号 × 应用大字模式，统一上限 1.30；柱图/环图/趋势图/进度条都有可朗读摘要；主页面月份箭头也有「上个月/下个月」语义。
- **二级页**：`PinnedSubHeader` 与主页面同一套模糊吸顶；三个二级页统一 `Stack + Positioned.fill(ListView) + 顶部浮层`。
- **日期选择**：`lib/ui/date_wheel.dart` 自绘年月日三列滚轮（`CupertinoPicker`），替代 Material 日历对话框，避免与整体设计语言割裂；月份变化时天数自动 clamp（闰年 2 月 29 天有测试覆盖）。

### 代码审查后修的 7 个缺陷

| ID | 问题 | 修法 |
|---|---|---|
| D1 | 下滑关闭绕过 `guard`（拖拽走 `Navigator.pop`，`PopScope` 拦不住） | 编辑类弹层统一 `dismissible: false`，只能按钮/返回键关闭 |
| D2 | 备份上限用 `String.length`（UTF-16 code unit），中文实际可放到约 3 倍体积 | `parseBackupText` 新增 `byteLength` 参数，按真实 UTF-8 字节判断 |
| D3 | 大小检查在整文件读取+解码之后，读取阶段就可能 OOM | `pickFiles(withData: false)` → `picked.size` 预检 → 读字节 → 再解码 |
| D4 | `utf8.decode(allowMalformed: true)` 把损坏字节替换成 U+FFFD 后继续导入 | 改严格解码，`FormatException` 转成明确错误 |
| D5 | `_dirty` 只监听金额/备注；编辑已有账目时 `guard` 恒 false | 类型/分类/日期变更都置 dirty，去掉 `entry == null` 条件 |
| D6 | `UndoBar` 的 top 落在顶栏区域内，被 `PinnedHeader` 盖住 | top 改为 `PinnedHeader.totalHeight(context) + 8` |
| D7 | 二级页外层 `SafeArea` 把 `padding.top` 置零，顶栏从状态栏下方开始 | 改 `SafeArea(top: false)`，让 `PinnedSubHeader` 自己消费 |

## 已知限制

- **APK 体积**：1.7.1 全 ABI release 约 60 MB；arm64 单 ABI 约 25 MB。
  Flutter 引擎本身占大头，无法回到旧版 WebView 的 4 MB。可用
  `--split-per-abi` + `--obfuscate --split-debug-info` 进一步压缩。
- **首帧**：液态折射 shader 在 x86_64 模拟器上曾把冷启动拉到约 15 秒；1.3.6 起自动在 x86_64/非 ARM 使用 `GlassQuality.plain`，模拟器热身后约 2.6–3.4 秒（受负载波动影响）。arm64 真机的液态层未实测；低核数 ARM 由 FluidGlass 的设备分级自动降级。
- **Flutter Web**：v1 不发布 Web，React PWA 冻结维护。
- **导出**：CSV 已接入系统分享；Excel 行数据构建器已在 `lib/data/backup.dart`，但尚未接入表格库。
- **自动备份**：当前只有单文档三代本地备份，没有 React 版的自动快照副本。
- UI 字体走平台系统字体（Android Roboto + 系统中文字体）；未打包额外字体，旧 Outfit 资源已清理。
