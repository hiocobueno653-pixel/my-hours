/// 统计聚合：年度趋势、分类占比、按工作分组、年度汇总。
///
/// 与 `src/data/stats.ts` 等价。所有金额都经过 `recordPay`（逐条两位小数）
/// 后再累加，与 `records.dart` 的聚合顺序保持一致。
library;

import 'constants.dart';
import 'dates.dart' show pad2;
import 'models.dart';
import 'records.dart' show getMonthRecords, recordPay, roundMoney;

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
  final pay = <String, double>{for (final k in monthKeys) k: 0};
  final workDays = <String, int>{for (final k in monthKeys) k: 0};

  final yearPrefix = '$year-';
  for (final record in records) {
    if (!record.date.startsWith(yearPrefix)) continue;
    final key = record.date.substring(0, 7);
    if (!hours.containsKey(key)) continue;
    hours[key] = hours[key]! + record.hours;
    pay[key] = pay[key]! + recordPay(record, workProfiles);
    if (record.hours > 0) workDays[key] = workDays[key]! + 1;
  }

  return [
    for (final key in monthKeys)
      MonthHoursPoint(
        yearMonth: key,
        hours: roundMoney(hours[key]!),
        pay: roundMoney(pay[key]!),
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
  final income = <String, double>{for (final k in monthKeys) k: 0};
  final expense = <String, double>{for (final k in monthKeys) k: 0};

  final yearPrefix = '$year-';
  for (final entry in entries) {
    if (!entry.date.startsWith(yearPrefix)) continue;
    final key = entry.date.substring(0, 7);
    if (!income.containsKey(key)) continue;
    if (entry.type == LedgerType.income) {
      income[key] = income[key]! + entry.amount;
    } else {
      expense[key] = expense[key]! + entry.amount;
    }
  }

  return [
    for (final key in monthKeys)
      MonthLedgerPoint(
        yearMonth: key,
        income: roundMoney(income[key]!),
        expense: roundMoney(expense[key]!),
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
  var totalPay = 0.0;
  var totalIncome = 0.0;
  var totalExpense = 0.0;
  for (final record in records) {
    if (!record.date.startsWith(prefix)) continue;
    totalHours += record.hours;
    totalPay += recordPay(record, workProfiles);
  }
  for (final entry in entries) {
    if (!entry.date.startsWith(prefix)) continue;
    if (entry.type == LedgerType.income) {
      totalIncome += entry.amount;
    } else {
      totalExpense += entry.amount;
    }
  }
  return YearSummary(
    totalHours: roundMoney(totalHours),
    totalPay: roundMoney(totalPay),
    totalIncome: roundMoney(totalIncome),
    totalExpense: roundMoney(totalExpense),
  );
}
