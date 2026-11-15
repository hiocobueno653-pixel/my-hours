/// 日期与月份工具。
///
/// 与 `src/data/dates.ts` 等价：本地时区、`YYYY-MM-DD` / `YYYY-MM` 字面量、
/// 周一至周日以 0（周日）… 6（周六）表达，对齐 JS `Date.getDay()`。
library;

import 'constants.dart';

/// 一个月里的一天。
class MonthDay {
  const MonthDay({
    required this.date,
    required this.day,
    required this.weekday,
    required this.isToday,
  });

  final String date;
  final int day;

  /// 0 = 周日 … 6 = 周六（与 JS 一致）。
  final int weekday;
  final bool isToday;
}

final RegExp _monthKeyPattern = RegExp(r'^(\d{4})-(\d{2})$');

String pad2(int value) => value.toString().padLeft(2, '0');

String toDateISO(DateTime date) =>
    '${date.year}-${pad2(date.month)}-${pad2(date.day)}';

String todayISO() => toDateISO(DateTime.now());

String monthKeyOf(DateTime date) => '${date.year}-${pad2(date.month)}';

String currentMonthKey() => monthKeyOf(DateTime.now());

class YearMonth {
  const YearMonth(this.year, this.month);

  final int year;
  final int month;
}

YearMonth? parseMonthKey(String key) {
  final match = _monthKeyPattern.firstMatch(key);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  if (year < minSupportedYear ||
      year > maxSupportedYear ||
      month < 1 ||
      month > 12) {
    return null;
  }
  return YearMonth(year, month);
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

List<MonthDay> getMonthDates(String yearMonth) {
  final parsed = parseMonthKey(yearMonth);
  if (parsed == null) return const [];
  final today = todayISO();
  final count = daysInMonth(parsed.year, parsed.month);
  return [
    for (var index = 0; index < count; index++)
      () {
        final day = index + 1;
        final date = DateTime(parsed.year, parsed.month, day);
        final iso = '${parsed.year}-${pad2(parsed.month)}-${pad2(day)}';
        return MonthDay(
          date: iso,
          day: day,
          // Dart: 1=周一 … 7=周日 → JS: 0=周日 … 6=周六
          weekday: date.weekday % 7,
          isToday: iso == today,
        );
      }(),
  ];
}

String shiftDate(String dateISO, int delta) {
  final parts = dateISO.split('-');
  if (parts.length != 3) return dateISO;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return dateISO;
  return toDateISO(DateTime(year, month, day + delta));
}

String shiftMonth(String yearMonth, int delta) {
  final parsed = parseMonthKey(yearMonth);
  if (parsed == null) return currentMonthKey();
  return monthKeyOf(DateTime(parsed.year, parsed.month + delta, 1));
}

String formatDateLabel(String dateISO) {
  final parts = dateISO.split('-');
  if (parts.length != 3) return dateISO;
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null) return dateISO;
  return '$month月$day日';
}

String formatMonthLabel(String yearMonth) {
  final parsed = parseMonthKey(yearMonth);
  if (parsed == null) return yearMonth;
  return '${parsed.year}年${parsed.month}月';
}

const List<String> _weekdayNames = ['日', '一', '二', '三', '四', '五', '六'];

String weekdayName(int weekday) =>
    (weekday >= 0 && weekday < _weekdayNames.length)
    ? _weekdayNames[weekday]
    : '';

/// 是否为合法日期字面量（同时校验日历有效性，如 2 月 30 日不合法）。
bool isValidDateISO(String value) {
  if (!datePattern.hasMatch(value)) return false;
  final parts = value.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  if (year < minSupportedYear || year > maxSupportedYear) return false;
  if (month < 1 || month > 12) return false;
  return day >= 1 && day <= daysInMonth(year, month);
}

/// 当月工作日数（周一至周五）。
///
/// 不能按固定 22 天算：2026 年 11 月是 21 天，2027 年 2 月是 20 天。
/// 用错会让「本月工时 / 工作日」的百分比偏离真实值。
int workdaysInMonth(int year, int month) {
  final total = daysInMonth(year, month);
  var count = 0;
  for (var day = 1; day <= total; day++) {
    final weekday = DateTime(year, month, day).weekday;
    if (weekday <= DateTime.friday) count++;
  }
  return count;
}
