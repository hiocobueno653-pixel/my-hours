import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/stats.dart';

/// 期望值取自旧版 React `src/data/stats.test.ts`。
void main() {
  const records = <WorkDayRecord>[
    WorkDayRecord(date: '2026-08-01', hours: 8, rate: 20),
    WorkDayRecord(date: '2026-08-02', hours: 8.5, rate: 25),
    WorkDayRecord(date: '2026-09-01', hours: 6, rate: 20),
    WorkDayRecord(date: '2026-08-03', hours: 4, workId: 'w2'),
  ];

  const workProfiles = <WorkProfile>[
    WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 20),
    WorkProfile(id: 'w2', name: '家教', hourlyRate: 0),
  ];

  const entries = <LedgerEntry>[
    LedgerEntry(
      id: 'e1',
      date: '2026-08-01',
      type: LedgerType.income,
      amount: 5000,
      category: '工资',
    ),
    LedgerEntry(
      id: 'e2',
      date: '2026-08-02',
      type: LedgerType.expense,
      amount: 35.5,
      category: '餐饮',
    ),
    LedgerEntry(
      id: 'e3',
      date: '2026-09-01',
      type: LedgerType.expense,
      amount: 120,
      category: '购物',
    ),
  ];

  test('年度工时与工资趋势', () {
    final trend = getYearHoursTrend(records, 2026, null);
    expect(trend[7].yearMonth, '2026-08');
    expect(trend[7].hours, 20.5);
    expect(trend[7].pay, 372.5);
    expect(trend[7].workDays, 3);
    expect(trend[8].hours, 6);
    expect(trend[8].pay, 120);
    expect(trend[8].workDays, 1);
    expect(trend[0].hours, 0);
  });

  test('年度收支趋势', () {
    final trend = getYearLedgerTrend(entries, 2026);
    expect(trend[7].income, 5000);
    expect(trend[7].expense, 35.5);
    expect(trend[8].income, 0);
    expect(trend[8].expense, 120);
  });

  test('月度分类汇总按金额降序', () {
    final totals = getMonthCategoryTotals(entries, '2026-08');
    expect(totals.length, 2);
    expect(totals[0].name, '工资');
    expect(totals[0].type, LedgerType.income);
    expect(totals[0].total, 5000);
    expect(totals[1].name, '餐饮');
    expect(totals[1].total, 35.5);
  });

  test('按工作分组的工时与工资', () {
    final rows = getMonthWorkBreakdown(records, workProfiles, '2026-08');
    expect(rows.length, 2);
    expect(rows[0].workId, 'work-default');
    expect(rows[0].name, '默认工作');
    expect(rows[0].hours, 16.5);
    expect(rows[0].pay, 372.5);
    expect(rows[1].workId, 'w2');
    expect(rows[1].name, '家教');
    expect(rows[1].hours, 4);
    expect(rows[1].pay, 0);
  });

  test('年度汇总', () {
    final summary = getYearSummary(records, entries, 2026, null);
    expect(summary.totalHours, 26.5);
    expect(summary.totalPay, 492.5);
    expect(summary.totalIncome, 5000);
    expect(summary.totalExpense, 155.5);
  });

  test('自定义日薪会进入年度工资', () {
    const fixedRecords = <WorkDayRecord>[
      WorkDayRecord(date: '2026-08-01', hours: 8, fixedPay: 320),
    ];
    expect(getYearSummary(fixedRecords, const [], 2026, null).totalPay, 320);
  });

  test('零工时的自定义日薪仍进入工资分组', () {
    const fixedRecords = <WorkDayRecord>[
      WorkDayRecord(date: '2026-08-04', hours: 0, fixedPay: 200),
    ];
    final rows = getMonthWorkBreakdown(fixedRecords, workProfiles, '2026-08');
    expect(rows, hasLength(1));
    expect(rows.single.hours, 0);
    expect(rows.single.pay, 200);
  });
}
