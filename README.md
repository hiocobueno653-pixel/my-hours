# 我的工时（My Hours）

一款离线优先的工时 + 收支记账应用，数据全部保存在本机，无账号、无后端。支持 Web PWA（可安装、可离线、自动更新）与 Android（Capacitor）两种运行方式。

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
- 数据全部存于本机 `localStorage`（多层备份写入，损坏自动回退）；并开启自动备份与自动恢复
- JSON 备份导出 / 导入（版本 v4，兼容 v1–v3 旧备份）
- CSV / **Excel（.xlsx）** 导出：月工时表、月账本、月中概览

## 技术栈

- **React 19 + TypeScript**（严格类型，`erasableSyntaxOnly`）
- **Vite 8** 构建 / 开发，Oxlint 检查
- **PWA**：vite-plugin-pwa + Workbox 离线缓存、清单安装、自动更新
- **Zustand** 单一数据源状态管理
- **Capacitor 8**：Android 原生打包（minSdk 24 / target 36）
- **write-excel-file**（按需动态加载）：Excel 导出
- **Vitest + Testing Library**：17 个测试文件、100 个用例覆盖数据层、资金口径与核心交互

## 开发

```bash
npm install        # 安装依赖
npm run dev        # 本地开发（Vite dev server）
npm test           # 运行全部测试
npm run lint       # Oxlint 静态检查
npm run build      # 生产构建（输出 dist/）
npx cap sync android   # 同步 Android 工程
npx cap open android   # 打开 Android Studio 打包
```

### 构建变体：「只记工时」

同一代码库可产出第二个变体（无记账页、不生成工资账本条目，结算仅为标记，
appId 后缀 `.hours` 可与完整版共存安装）：

```powershell
$env:VITE_HOURS_ONLY='1'; npm run build            # 产出 dist-hours/
node scripts/sync-hours-assets.mjs                 # 分发到 android hours flavor
cd android; .\gradlew.bat assembleHoursRelease     # 产出 app-hours-release.apk
```

## 项目结构

```
src/
  data/        # 纯数据逻辑：记录、账目、工作、统计、备份、持久化
  store/       # Zustand 全局状态与全部写操作
  components/  # 视图与面板、图表（无第三方图表库，纯 SVG）
  services/    # 导出服务（CSV / Excel / JSON 备份）
  navigation/  # Android 返回键 / 模态层导航
```

## 说明

- 时薪按「记录当日快照」计算，之后修改工作时薪不会回溯影响历史工资；编辑某天记录且未切换工作时会保留原快照。
- 备份文件格式版本为 v4，历史 v1–v3 备份导入时自动补齐默认工作与预算设置。
