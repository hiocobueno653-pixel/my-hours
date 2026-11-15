import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/dates.dart';

/// 期望值取自旧版 React `src/data/dates.test.ts`。
void main() {
  group('日期工具', () {
    test('返回一个月内所有日期与星期名', () {
      final dates = getMonthDates('2026-08');
      expect(dates.length, 31);
      expect(dates.first.date, '2026-08-01');
      expect(dates.first.day, 1);
      // 2026-08-01 是周六（JS 0=周日 … 6=周六）
      expect(dates.first.weekday, 6);
      expect(weekdayName(6), '六');
    });

    test('闰月天数', () {
      expect(getMonthDates('2026-02').length, 28);
      expect(getMonthDates('2028-02').length, 29);
    });

    test('跨月移动日期', () {
      expect(shiftDate('2026-08-01', -1), '2026-07-31');
      expect(shiftDate('2026-12-31', 1), '2027-01-01');
    });

    test('跨年移动月份', () {
      expect(shiftMonth('2026-01', -1), '2025-12');
      expect(shiftMonth('2026-12', 1), '2027-01');
    });

    test('月份标签与解析', () {
      expect(formatMonthLabel('2026-08'), '2026年8月');
      final parsed = parseMonthKey('2026-08');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 8);
      expect(parseMonthKey('bad'), isNull);
      expect(parseMonthKey('2026-13'), isNull);
    });

    test('界面支持的年份范围之外视为非法', () {
      expect(isValidDateISO('1999-12-31'), isFalse);
      expect(isValidDateISO('2101-01-01'), isFalse);
      expect(parseMonthKey('1999-12'), isNull);
      expect(parseMonthKey('2101-01'), isNull);
    });
  });
}
