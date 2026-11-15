# 时页 TIMEPAGE

记录时间，记下生活。

一款离线优先的工时 + 收支记账应用，数据全部保存在本机，无账号、无后端。

客户端为 `flutter_app/` 下的 Flutter 实现（包名 `com.myhours.app`），
Android 优先。设计规范、决策记录与历史变更见 `docs/`。

## 功能

### 记工
- 按日记录工时（0–24 小时，两位小数）与备注，快捷工时一键点选
- **多份工作**：可创建多个工作（工地、家教、兼职…）并分别设置时薪
- **工资自动计算**：输入工时后实时显示「工时 × 时薪 = 本日工资」；每份工作独立统计
- **自定义当日工资**：任意一天可单独填写固定日薪，填写后优先于「工时 × 时薪」，清空即可恢复自动计算
- **结算标记**：单条或整月批量标记“已结算”，已结算工资自动计入账本收入；启动与导入备份时自动对账，金额永不错漏
- 月度汇总：月总工时、工作天数、日均、本月工资
- 今天的独立卡片：当天工时、收入、账目一览
- 未设时薪时可手动填写本日工资，系统反算并保存时薪
- 删除可撤销（6 秒内恢复）

### 记账
- 收入 / 支出明细，支持常用金额快捷输入
- 默认分类 + 自定义分类（删除前有使用中保护）
- 账目可关联某天工时；删除可撤销
- **搜索**：按分类、备注、日期数字即时过滤
- 月度收支汇总：收入、支出、结余

### 我的
- 整月日历总览：工时 / 收入 / 支出三色圆点 + 当天详情
- **工资面板**：本月应得工资、已结算金额、按工作分组统计、批量结算
- **预算与目标**：设置每月支出预算与收入目标，进度条实时显示，超预算 / 达成目标有提示
- **年度统计**：全年工时/工资趋势、每月收支双柱图、当月分类占比环形图
- **深色模式**：跟随系统 / 浅色 / 深色三档切换，夜间护眼
- 大字模式、清空数据

### 数据
- 数据存于应用私有目录的 `my-hours.json`（三代备份，损坏自动回退）
- 每日自动留一份本机快照（保留 7 天），可在「数据与备份」页手动恢复
- JSON 备份导出 / 导入（版本 v4，兼容 v1–v3 旧备份）
- CSV 导出：月工时表、月账本、月中概览

## 技术栈

- **Flutter 3.47** + Dart 3.13，Android 优先（minSdk 24 / target 36）
- **flutter_riverpod** 状态管理，单一 `AppController` 承担全部写操作
- **FluidGlass**（Apache-2.0）实现液态玻璃 Dock；不用 GPL 的 prism_ui，见 `docs/adr/0002-licensing-prism-ui.md`
- 图表为自绘 `CustomPainter`，无第三方图表库
- **flutter_test**：38 个测试文件，覆盖数据层、迁移对账、golden 工资用例与核心交互

## 开发

Flutter 3.47.9 在 `E:\tools\flutter`（未进 PATH）：

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
cd flutter_app
& 'E:\tools\flutter\bin\flutter.bat' pub get
& 'E:\tools\flutter\bin\flutter.bat' analyze      # 必须零 issue
& 'E:\tools\flutter\bin\flutter.bat' test         # 全量用例
& 'E:\tools\flutter\bin\flutter.bat' build apk --release --flavor full
```

出包与签名见 `flutter_app/README.md`；CI 见 `.github/workflows/flutter.yml`
（分支上只跑分析和测试，出包只在打 tag 或手动触发时进行）。

### 两个变体

| flavor | applicationId | 说明 |
| --- | --- | --- |
| `full` | `com.myhours.app` | 完整版（记工 + 记账 + 我的） |
| `hours` | `com.myhours.app.hours` | 只记工时，可与完整版共存 |

`hours` 必须同时传编译期开关，否则只是换了 applicationId、记账页仍在：

```powershell
& 'E:\tools\flutter\bin\flutter.bat' build apk --release --flavor hours --dart-define=HOURS_ONLY=true
```

## 项目结构

```
flutter_app/
  lib/
    data/       纯数据逻辑：记录、账目、工作、统计、备份、持久化
    state/      Riverpod 全局状态与全部写操作
    core/       主题令牌、动效常量、格式化、设置
    ui/         基础原语（卡片 / 按压面 / 撤销条 / 弹层 / 日期滚轮）
    features/   记工、记账、我的、图表
    platform/   返回导航、导出服务
  test/         数据、迁移、golden、交互用例
  tool/         品牌素材与发布脚本
docs/
  adr/          架构决策记录
  release-*.md  各版本变更
design.md       视觉与交互规范（分版本演进，当前 v4）
```

## 说明

- 时薪按「记录当日快照」计算，之后修改工作时薪不会回溯影响历史工资；编辑某天记录且未切换工作时会保留原快照。
- 金额口径：`fixedPay > 记录当日时薪快照 > 工作当前时薪`，逐条百分位定点舍入后累加。
- 备份文件格式版本为 v4，历史 v1–v3 备份导入时自动补齐默认工作与预算设置。
- release 签名清单与密钥不入库，置于 `flutter_app/android/`（`keystore.properties` + `myhours-release.keystore`），本机或 CI 在构建前写入。丢失即无法覆盖升级。
