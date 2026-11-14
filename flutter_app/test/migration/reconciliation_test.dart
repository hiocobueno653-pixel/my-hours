import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/features/mine/backup_page.dart';
import 'package:my_hours/state/app_controller.dart';

/// 导入对账：跨源校验 + 逐月覆盖。
AppState sample({required double wageAmount}) => AppState(
  records: [
    WorkDayRecord(date: '2026-08-10', hours: 8, settled: true, rate: 20),
    const WorkDayRecord(date: '2026-07-05', hours: 4, rate: 20),
  ],
  entries: [
    LedgerEntry(
      id: 'wage-2026-08-10',
      date: '2026-08-10',
      type: LedgerType.income,
      amount: wageAmount,
      category: '工资',
      workDate: '2026-08-10',
    ),
  ],
  customCategories: const [],
  workProfiles: const [
    WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 20),
  ],
  budgetTargets: const BudgetTargets(),
);

void main() {
  test('账本工资与已结算工资不一致时报告不一致', () {
    final report = MigrationReport.compare(
      expected: sample(wageAmount: 160),
      actual: sample(wageAmount: 120),
    );

    expect(report.ok, isFalse);
    final row = report.rows.firstWhere((item) => item.label == '工资账目 vs 已结算');
    expect(row.ok, isFalse);
    expect(MigrationReport.summaryOf(report), contains('不一致'));
  });

  test('一致时逐月覆盖所有出现的月份，而不是只比一个月', () {
    final report = MigrationReport.compare(
      expected: sample(wageAmount: 160),
      actual: sample(wageAmount: 160),
    );

    expect(report.ok, isTrue);
    expect(report.monthsChecked, 2);
    expect(report.monthDiffs, isEmpty);
    expect(MigrationReport.summaryOf(report), contains('2 个月份'));
  });

  test('某个月的工时被改丢时能在差异里定位到那个月', () {
    final broken = AppState(
      records: const [
        WorkDayRecord(date: '2026-08-10', hours: 6, settled: true, rate: 20),
        WorkDayRecord(date: '2026-07-05', hours: 4, rate: 20),
      ],
      entries: sample(wageAmount: 160).entries,
      customCategories: const [],
      workProfiles: const [
        WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 20),
      ],
      budgetTargets: const BudgetTargets(),
    );

    final report = MigrationReport.compare(
      expected: sample(wageAmount: 160),
      actual: broken,
    );

    expect(report.monthDiffs, hasLength(1));
    expect(report.monthDiffs.single.month, '2026-08');
    expect(
      report.monthDiffs.single.rows.where((row) => !row.ok).map((r) => r.label),
      contains('工时'),
    );
  });
}
