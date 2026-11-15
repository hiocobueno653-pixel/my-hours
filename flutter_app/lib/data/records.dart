/// 工时记录：校验、归一化、排序与工资口径。
///
/// 与 `src/data/records.ts` 等价。**这是全部金额的唯一出口**：
/// - 工资 = `fixedPay > 0 ? fixedPay : round(hours × 有效时薪)`
/// - 有效时薪 = 记录 `rate` 快照优先，缺省回退该工作当前时薪
///
/// 聚合顺序不可「顺手统一」：
/// - `monthPay`：逐条 `recordPay`（各自两位小数）再累加，最后再 round；
/// - `settlementSummary`：同样逐条 `recordPay` 后累加。
/// 任何先累加原始值再 round 的写法都会与旧版产生分位差。
library;

import 'constants.dart';
import 'dates.dart';
import 'models.dart';
import 'money.dart';

export 'money.dart' show roundMoney, toScaledCents;

/// 工时输入校验结果。
sealed class HoursInputResult {
  const HoursInputResult();
}

class HoursInputOk extends HoursInputResult {
  const HoursInputOk(this.hours);
  final double hours;
}

class HoursInputError extends HoursInputResult {
  const HoursInputError(this.message);
  final String message;
}

HoursInputResult parseHoursInput(String raw) {
  final trimmed = normalizeNumericInput(raw);
  if (trimmed.isEmpty) return const HoursInputError('请填写工时');
  if (!hoursPattern.hasMatch(trimmed)) {
    return const HoursInputError('工时最多两位小数');
  }
  final hours = double.tryParse(trimmed);
  if (hours == null || hours.isNaN || hours < 0 || hours > maxDailyHours) {
    return const HoursInputError('工时需在 0 到 24 之间');
  }
  return HoursInputOk(roundMoney(hours));
}

String formatHours(double hours) => _numberText(roundMoney(hours));

/// 去掉无意义的小数尾零（与 JS `String(number)` 一致）。
String _numberText(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// 归一化一条工时记录；非法返回 null（导入时由调用方阻断或丢弃）。
WorkDayRecord? normalizeRecord(Object? raw) {
  if (raw is! Map) return null;
  final date = raw['date'];
  if (date is! String || !isValidDateISO(date)) return null;

  final hoursRaw = raw['hours'];
  final hours = hoursRaw is num
      ? hoursRaw.toDouble()
      : double.tryParse('$hoursRaw');
  if (hours == null || hours.isNaN || hours < 0 || hours > maxDailyHours) {
    return null;
  }
  if ((roundMoney(hours) - hours).abs() > decimalTolerance) return null;

  final remarkRaw = raw['remark'];
  final remark = remarkRaw is String
      ? (remarkRaw.length <= maxRemarkLength
            ? remarkRaw
            : remarkRaw.substring(0, maxRemarkLength))
      : '';

  final workIdRaw = raw['workId'];
  final workId = workIdRaw is String && workIdRaw.trim().isNotEmpty
      ? workIdRaw.trim()
      : null;

  final rate = _optionalDecimal(raw['rate'], max: maxHourlyRate, min: 0);
  final fixedPay = _optionalDecimal(raw['fixedPay'], max: maxFixedPay, min: 0);
  final settled = raw['settled'] == true;

  return WorkDayRecord(
    date: date,
    hours: roundMoney(hours),
    remark: remark,
    workId: workId,
    rate: rate,
    fixedPay: fixedPay,
    settled: settled,
  );
}

/// 解析一个可选金额字段：非有限值、越界或超过两位小数都视为「未设置」。
double? _optionalDecimal(
  Object? raw, {
  required double max,
  required double min,
}) {
  if (raw == null) return null;
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || value.isNaN || value.isInfinite) return null;
  if (value < min || value > max) return null;
  if ((roundMoney(value) - value).abs() > decimalTolerance) return null;
  return roundMoney(value);
}

List<WorkDayRecord> normalizeRecords(Object? raw) {
  if (raw is! List) return const [];
  final result = <WorkDayRecord>[];
  for (final item in raw) {
    final record = normalizeRecord(item);
    if (record != null) result.add(record);
  }
  return result;
}

List<WorkDayRecord> sortRecords(List<WorkDayRecord> records) {
  final copy = [...records];
  copy.sort((a, b) => a.date.compareTo(b.date));
  return copy;
}

/// 按日期去重（后者覆盖前者），并升序排列。
List<WorkDayRecord> dedupeRecords(List<WorkDayRecord> records) {
  final byDate = <String, WorkDayRecord>{};
  for (final record in records) {
    byDate[record.date] = record;
  }
  return sortRecords(byDate.values.toList());
}

WorkDayRecord? getRecordByDate(List<WorkDayRecord> records, String date) {
  for (final record in records) {
    if (record.date == date) return record;
  }
  return null;
}

List<WorkDayRecord> getMonthRecords(
  List<WorkDayRecord> records,
  String yearMonth,
) {
  final prefix = '$yearMonth-';
  return [
    for (final record in records)
      if (record.date.startsWith(prefix)) record,
  ];
}

/// 记录的有效时薪：快照优先 → 回退该工作当前时薪 → 0。
double effectiveRate(WorkDayRecord record, List<WorkProfile>? workProfiles) {
  final rate = record.rate;
  if (rate != null && rate.isFinite && rate > 0) return rate;
  if (workProfiles != null) {
    final workId = record.workId ?? defaultWorkId;
    for (final profile in workProfiles) {
      if (profile.id == workId && profile.hourlyRate > 0) {
        return profile.hourlyRate;
      }
    }
  }
  return 0;
}

/// 记录的实际工资：固定日薪优先，其次工时 × 有效时薪。
double recordPay(WorkDayRecord record, List<WorkProfile>? workProfiles) {
  return computeRecordPay(
    hours: record.hours,
    rate: effectiveRate(record, workProfiles),
    fixedPay: record.fixedPay,
  );
}

/// 是否使用了自定义固定日薪。
bool hasFixedPay(WorkDayRecord record) {
  final fixedPay = record.fixedPay;
  return fixedPay != null && fixedPay.isFinite && fixedPay > 0;
}

/// 每月工资汇总。
double getMonthPay(
  List<WorkDayRecord> records,
  String yearMonth,
  List<WorkProfile>? workProfiles,
) {
  var totalCents = 0;
  for (final record in getMonthRecords(records, yearMonth)) {
    totalCents += toScaledCents(recordPay(record, workProfiles));
  }
  return totalCents / 100.0;
}

/// 待结算 / 已结算金额与笔数。
SettlementSummary getSettlementSummary(
  List<WorkDayRecord> records,
  String yearMonth,
  List<WorkProfile>? workProfiles,
) {
  var totalCents = 0;
  var settledCents = 0;
  var settledCount = 0;
  var pendingCount = 0;
  for (final record in getMonthRecords(records, yearMonth)) {
    final pay = recordPay(record, workProfiles);
    if (pay <= 0) continue;
    final cents = toScaledCents(pay);
    totalCents += cents;
    if (record.settled) {
      settledCents += cents;
      settledCount += 1;
    } else {
      pendingCount += 1;
    }
  }
  return SettlementSummary(
    total: totalCents / 100.0,
    settled: settledCents / 100.0,
    pending: (totalCents - settledCents) / 100.0,
    settledCount: settledCount,
    pendingCount: pendingCount,
  );
}

MonthSummary getMonthSummary(List<WorkDayRecord> records, String yearMonth) {
  final monthRecords = getMonthRecords(records, yearMonth);
  var totalHours = 0.0;
  var workDays = 0;
  for (final record in monthRecords) {
    totalHours += record.hours;
    if (record.hours > 0) workDays += 1;
  }
  final roundedHours = roundMoney(totalHours);
  return MonthSummary(
    totalHours: roundedHours,
    workDays: workDays,
    averageHours: workDays > 0 ? roundMoney(roundedHours / workDays) : 0,
  );
}

/// 环比上月：上月无记录时返回 null。
({double delta, double percent})? getMonthDelta(
  List<WorkDayRecord> records,
  String yearMonth,
) {
  final lastMonth = shiftMonth(yearMonth, -1);
  final current = getMonthSummary(records, yearMonth).totalHours;
  final previous = getMonthSummary(records, lastMonth).totalHours;
  if (previous == 0) return null;
  final delta = roundMoney(current - previous);
  return (delta: delta, percent: (delta / previous * 1000).round() / 10);
}
