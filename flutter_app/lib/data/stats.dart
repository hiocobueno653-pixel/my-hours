/// 统计聚合：年度趋势、分类占比、按工作分组、年度汇总。
///
/// 与旧版 React `src/data/stats.ts` 等价。所有金额都经过 `recordPay`（逐条两位小数）
/// 后再累加，与 `records.dart` 的聚合顺序保持一致。
library;

import 'constants.dart';
import 'dates.dart' show pad2;
import 'models.dart';
import 'records.dart'
    show getMonthRecords, recordPay, roundMoney, toScaledCents;

String yearMonthKey(int year, int month) => '$year-${pad2(month)}';

List<String> getYearMonthKeys(int year) => [
  for (var month = 1; month <= 12; month++) yearMonthKey(year, month),
];

class MonthHoursPoint {
  const MonthHoursPoint({
    required this.yearMonth,
    required this.hours,
    required this.pay,
    required this.workDays,
  });

  final String yearMonth;
  final double hours;
  final double pay;
  final int workDays;
}

/// 全年每月工时与工资。
List<MonthHoursPoint> getYearHoursTrend(
  List<WorkDayRecord> records,
  int year,
  List<WorkProfile>? workProfiles,
) {
  final monthKeys = getYearMonthKeys(year);
  final hours = <String, double>{for (final k in monthKeys) k: 0};
  final payCents = <String, int>{for (final k in monthKeys) k: 0};
  final workDays = <String, int>{for (final k in monthKeys) k: 0};

  final yearPrefix = '$year-';
  for (final record in records) {
    if (!record.date.startsWith(yearPrefix)) continue;
    final key = record.date.substring(0, 7);
    if (!hours.containsKey(key)) continue;
    hours[key] = hours[key]! + record.hours;
    payCents[key] =
        payCents[key]! + toScaledCents(recordPay(record, workProfiles));
    if (record.hours > 0) workDays[key] = workDays[key]! + 1;
  }

  return [
    for (final key in monthKeys)
      MonthHoursPoint(
        yearMonth: key,
        hours: roundMoney(hours[key]!),
        pay: payCents[key]! / 100.0,
        workDays: workDays[key]!,
      ),
  ];
}

class MonthLedgerPoint {
  const MonthLedgerPoint({
    required this.yearMonth,
    required this.income,
    required this.expense,
  });

  final String yearMonth;
  final double income;
  final double expense;
}

List<MonthLedgerPoint> getYearLedgerTrend(List<LedgerEntry> entries, int year) {
  final monthKeys = getYearMonthKeys(year);
  final incomeCents = <String, int>{for (final k in monthKeys) k: 0};
  final expenseCents = <String, int>{for (final k in monthKeys) k: 0};

  final yearPrefix = '$year-';
  for (final entry in entries) {
    if (!entry.date.startsWith(yearPrefix)) continue;
    final key = entry.date.substring(0, 7);
    if (!incomeCents.containsKey(key)) continue;
    if (entry.type == LedgerType.income) {
      incomeCents[key] = incomeCents[key]! + toScaledCents(entry.amount);
    } else {
      expenseCents[key] = expenseCents[key]! + toScaledCents(entry.amount);
    }
  }

  return [
    for (final key in monthKeys)
      MonthLedgerPoint(
        yearMonth: key,
        income: incomeCents[key]! / 100.0,
        expense: expenseCents[key]! / 100.0,
      ),
  ];
}

class CategoryTotal {
  const CategoryTotal({
    required this.name,
    required this.type,
    required this.total,
  });

  final String name;
  final LedgerType type;
  final double total;
}

/// 某月收支分类汇总（按金额降序）。
List<CategoryTotal> getMonthCategoryTotals(
  List<LedgerEntry> entries,
  String yearMonth,
) {
  final prefix = '$yearMonth-';
  final totals = <String, CategoryTotal>{};
  for (final entry in entries) {
    if (!entry.date.startsWith(prefix)) continue;
    final key = '${ledgerTypeValue(entry.type)}:${entry.category}';
    final current = totals[key];
    totals[key] = CategoryTotal(
      name: entry.category,
      type: entry.type,
      total: roundMoney((current?.total ?? 0) + entry.amount),
    );
  }
  final result = totals.values.toList();
  result.sort((a, b) => b.total.compareTo(a.total));
  return result;
}

class WorkBreakdownRow {
  const WorkBreakdownRow({
    required this.workId,
    required this.name,
    required this.hours,
    required this.pay,
  });

  final String workId;
  final String name;
  final double hours;
  final double pay;
}

/// 某月按工作分组的工时与工资（含默认工作）。
List<WorkBreakdownRow> getMonthWorkBreakdown(
  List<WorkDayRecord> records,
  List<WorkProfile> workProfiles,
  String yearMonth,
) {
  final rows = <String, WorkBreakdownRow>{};
  for (final record in getMonthRecords(records, yearMonth)) {
    final pay = recordPay(record, workProfiles);
    if (record.hours <= 0 && pay <= 0) continue;
    final workId = record.workId ?? defaultWorkId;
    WorkProfile? profile;
    for (final item in workProfiles) {
      if (item.id == workId) {
        profile = item;
        break;
      }
    }
    final name =
        profile?.name ?? (workId == defaultWorkId ? defaultWorkName : '未知工作');
    final existing = rows[workId];
    rows[workId] = WorkBreakdownRow(
      workId: workId,
      name: name,
      hours: roundMoney((existing?.hours ?? 0) + record.hours),
      pay: roundMoney((existing?.pay ?? 0) + pay),
    );
  }

  final order = [for (final profile in workProfiles) profile.id];
  final result = rows.values.toList();
  result.sort((a, b) {
    final ai = order.indexOf(a.workId);
    final bi = order.indexOf(b.workId);
    if (ai == -1 && bi == -1) return b.pay.compareTo(a.pay);
    if (ai == -1) return 1;
    if (bi == -1) return -1;
    return ai.compareTo(bi);
  });
  return result;
}

class YearSummary {
  const YearSummary({
    required this.totalHours,
    required this.totalPay,
    required this.totalIncome,
    required this.totalExpense,
  });

  final double totalHours;
  final double totalPay;
  final double totalIncome;
  final double totalExpense;
}

YearSummary getYearSummary(
  List<WorkDayRecord> records,
  List<LedgerEntry> entries,
  int year,
  List<WorkProfile>? workProfiles,
) {
  final prefix = '$year-';
  var totalHours = 0.0;
  var totalPayCents = 0;
  var totalIncomeCents = 0;
  var totalExpenseCents = 0;
  for (final record in records) {
    if (!record.date.startsWith(prefix)) continue;
    totalHours += record.hours;
    totalPayCents += toScaledCents(recordPay(record, workProfiles));
  }
  for (final entry in entries) {
    if (!entry.date.startsWith(prefix)) continue;
    if (entry.type == LedgerType.income) {
      totalIncomeCents += toScaledCents(entry.amount);
    } else {
      totalExpenseCents += toScaledCents(entry.amount);
    }
  }
  return YearSummary(
    totalHours: roundMoney(totalHours),
    totalPay: totalPayCents / 100.0,
    totalIncome: totalIncomeCents / 100.0,
    totalExpense: totalExpenseCents / 100.0,
  );
}
