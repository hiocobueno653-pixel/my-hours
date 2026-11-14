/// 结算 → 工资账目的幂等对账。
///
/// 与 `src/data/wageEntries.ts` 等价。这是「钱」进入账本的唯一路径，
/// 也是双计风险的唯一防线：
/// - 已结算且工资 > 0 → 生成/更新 `id = wage-<date>` 的收入账目；
/// - 未结算或工资 = 0 → 删除该日系统账目；
/// - 旧版「同时记收入」遗留的 `workDate` 关联收入 → 被工资账目替换，避免双计；
/// - **无任何变化时返回原 List 引用**，供启动对账跳过全量回写与备份轮转。
library;

import 'constants.dart';
import 'models.dart';
import 'records.dart';

String getWageEntryId(String date) => '$wageEntryIdPrefix$date';

bool isWageEntryForDate(LedgerEntry entry, String date) =>
    entry.id == getWageEntryId(date);

/// 旧版遗留：关联某天工时的非系统收入（id 非 `wage-*`）。
///
/// 这类账目由旧版「同时记收入」自动生成，只能由当天的工资账目替换；
/// 保存工时时必须无条件清理，否则会与工资账目并存造成双计。
bool isLegacyLinkedIncomeForDate(LedgerEntry entry, String date) =>
    entry.type == LedgerType.income &&
    entry.workDate == date &&
    !isWageEntryForDate(entry, date);

/// 删除某天全部旧版遗留关联收入（纯函数，不落盘）。
///
/// 与 `syncWageEntryForDate` 的区别：**不看结算态**。旧版只要记了工时
/// 就会写一条收入，因此保存工时时无论是否结算都该清掉。
List<LedgerEntry> dropLegacyLinkedIncomeForDate(
  List<LedgerEntry> entries,
  String date,
) => [
  for (final entry in entries)
    if (!isLegacyLinkedIncomeForDate(entry, date)) entry,
];

LedgerEntry _createWageEntry(String date, double amount) => LedgerEntry(
  id: getWageEntryId(date),
  date: date,
  type: LedgerType.income,
  amount: amount,
  category: wageEntryCategory,
  remark: wageEntryRemark,
  workDate: date,
);

/// 按一条工时记录的状态同步其系统工资账目。不触碰用户手动录入的其他账目。
List<LedgerEntry> syncWageEntryForDate(
  List<WorkDayRecord> records,
  List<LedgerEntry> entries,
  List<WorkProfile> workProfiles,
  String date,
) {
  final record = getRecordByDate(records, date);
  final pay = record == null ? 0.0 : recordPay(record, workProfiles);
  final shouldSync = record != null && record.settled && pay > 0;

  final next = [
    for (final entry in entries)
      if (!isWageEntryForDate(entry, date) &&
          !(shouldSync && isLegacyLinkedIncomeForDate(entry, date)))
        entry,
  ];
  if (!shouldSync) return next;
  return [...next, _createWageEntry(date, pay)];
}

/// 对整组工时记录执行一次结算对账。
///
/// 已存在账目的金额不动（用户手动编辑过的保持原样）。
List<LedgerEntry> syncWageEntries(
  List<WorkDayRecord> records,
  List<LedgerEntry> entries,
  List<WorkProfile> workProfiles,
) {
  final wanted = <String>{};
  for (final record in records) {
    final pay = recordPay(record, workProfiles);
    if (record.settled && pay > 0) wanted.add(record.date);
  }

  var changed = false;
  final retained = <LedgerEntry>[];
  for (final entry in entries) {
    if (isWageEntryForDate(entry, entry.date)) {
      final keep = wanted.contains(entry.date);
      if (!keep) changed = true;
      if (keep) retained.add(entry);
      continue;
    }
    final workDate = entry.workDate;
    if (entry.type == LedgerType.income &&
        workDate != null &&
        wanted.contains(workDate) &&
        !isWageEntryForDate(entry, workDate)) {
      changed = true;
      continue;
    }
    retained.add(entry);
  }

  for (final date in wanted) {
    if (retained.any((entry) => isWageEntryForDate(entry, date))) continue;
    final record = getRecordByDate(records, date);
    if (record == null) continue;
    final pay = recordPay(record, workProfiles);
    if (pay <= 0) continue;
    retained.add(_createWageEntry(date, pay));
    changed = true;
  }

  return changed ? retained : entries;
}

/// 某天是否存在系统工资账目。
bool hasWageEntryForDate(List<LedgerEntry> entries, String date) =>
    entries.any((entry) => isWageEntryForDate(entry, date));

/// 移除某天的系统工资账目（取消结算时使用）。
List<LedgerEntry> removeWageEntryForDate(
  List<LedgerEntry> entries,
  String date,
) => [
  for (final entry in entries)
    if (!isWageEntryForDate(entry, date)) entry,
];
