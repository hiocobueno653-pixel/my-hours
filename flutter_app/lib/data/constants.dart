/// 全局阈值与字面量。
///
/// 每一个值都必须与 React 版源码逐字相同：这些数字同时出现在校验、
/// 归一化与导入阻断逻辑里，任何偏差都会让两版对同一份备份给出不同结果。
library;

/// 备注长度上限（工时与账目共用 200）。
const int maxRemarkLength = 200;
const int maxLedgerRemarkLength = 200;

/// 自定义日薪上限。
const double maxFixedPay = 999999999.99;

/// 时薪上限。
const double maxHourlyRate = 99999.99;

/// 账目金额上限。
const double maxLedgerAmount = 999999999.99;

/// 预算/目标金额上限。
const double maxBudgetAmount = 999999999.99;

/// 工作名与分类名长度上限。
const int maxWorkNameLength = 20;
const int maxCategoryNameLength = 20;

/// 默认工作的固定 id 与名称。
const String defaultWorkId = 'work-default';
const String defaultWorkName = '默认工作';

/// 系统工资账目的 id 前缀。
const String wageEntryIdPrefix = 'wage-';

/// 工资账目的分类与备注文案（出现在账本里，必须与旧版一致）。
const String wageEntryCategory = '工资';
const String wageEntryRemark = '结算工资';

/// 工时输入上限。
const double maxDailyHours = 24;

/// 数值比较容差（用于「是否已是两位小数」的判定）。
const double decimalTolerance = 1e-8;

/// 默认分类。
const List<String> defaultIncomeCategories = ['工资', '奖金', '兼职', '报销', '其他收入'];

const List<String> defaultExpenseCategories = [
  '餐饮',
  '交通',
  '购物',
  '居住',
  '医疗',
  '学习',
  '娱乐',
  '其他支出',
];

/// 日期格式：`YYYY-MM-DD`。
final RegExp datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 界面与导入共同支持的年份范围。
///
/// 日期轮盘、月份选择器、年度统计都只能到达这段范围；导入若接受范围外
/// 的数据，会得到一批「入库了但界面永远看不到」的记录。
const int minSupportedYear = 2000;
const int maxSupportedYear = 2100;

/// 工时输入：最多两位小数，允许 `.5` 形式。
final RegExp hoursPattern = RegExp(r'^(?:\d{1,2}(?:\.\d{1,2})?|\.\d{1,2})$');

/// 时薪输入：整数位最多 5 位。
final RegExp ratePattern = RegExp(r'^(?:\d{1,5}(?:\.\d{1,2})?|\.\d{1,2})$');

/// 金额输入：整数位最多 9 位。
final RegExp amountPattern = RegExp(r'^(?:\d{1,9}(?:\.\d{1,2})?|\.\d{1,2})$');

/// 数字输入的宽松清洗：只用于解析阶段，兼容中文逗号、英文逗号与空格。
///
/// 输入框自身会尽量把粘贴文本清洗成无分隔符格式；解析层再兜一层，
/// 防止旧备份、第三方键盘或直接调用解析函数时把 `1,200` 拒掉。
String normalizeNumericInput(String raw) =>
    raw.trim().replaceAll(RegExp(r'[,\s，]'), '');

/// 生成进程内不会因同一微秒重复调用而碰撞的实体 id。
///
/// 旧实现两次取 `DateTime.now().microsecondsSinceEpoch`，同一微秒内
/// 连续创建两条记录会得到完全相同的 id，随后被去重逻辑静默覆盖。
int _entityIdSerial = 0;

String createEntityId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  _entityIdSerial = (_entityIdSerial + 1) & 0xFFFFFF;
  return '$prefix-$now-${_entityIdSerial.toRadixString(36)}';
}
