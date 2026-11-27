import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/state/app_controller.dart';

void main() {
  late Directory directory;
  late ProviderContainer container;
  late AppController controller;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('my_hours_derived_');
    container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(LocalStore(directory))],
    );
    controller = container.read(appControllerProvider.notifier);
    controller.replaceAll(
      const ParsedBackupData(
        records: [
          WorkDayRecord(date: '2025-12-31', hours: 8, rate: 10),
          WorkDayRecord(date: '2026-01-03', hours: 2, rate: 12.5),
          WorkDayRecord(date: '2026-02-04', hours: 3, fixedPay: 50),
        ],
        entries: [
          LedgerEntry(
            id: 'previous-year',
            date: '2025-12-31',
            type: LedgerType.expense,
            amount: 100,
            category: '其他',
          ),
          LedgerEntry(
            id: 'expense',
            date: '2026-01-03',
            type: LedgerType.expense,
            amount: 12.34,
            category: '餐饮',
          ),
        ],
        customCategories: [],
        workProfiles: [
          WorkProfile(id: 'work-default', name: '家教', hourlyRate: 20),
        ],
        budgetTargets: BudgetTargets(),
      ),
    );
  });

  tearDown(() {
    container.dispose();
    directory.deleteSync(recursive: true);
  });

  test('年度缓存过滤跨年记录并保留时薪快照与固定日薪', () {
    final stats = container.read(yearStatsProvider(2026));

    expect(stats.summary.totalHours, 5);
    expect(stats.summary.totalPay, 75);
    expect(stats.summary.totalExpense, 12.34);
    expect(stats.totalWorkDays, 2);
    expect(stats.hoursTrend[0].pay, 25);
    expect(stats.hoursTrend[1].pay, 50);
    expect(stats.workBreakdown.single.name, '家教');
    expect(stats.workBreakdown.single.hours, 5);
    expect(stats.workBreakdown.single.pay, 75);
  });

  test('切换月份和修改预算复用年度汇总与日期索引', () {
    final stats = container.read(yearStatsProvider(2026));
    final recordsByDate = container.read(recordsByDateProvider);

    container.read(selectedMonthProvider.notifier).setMonth('2026-02');
    controller.saveBudgetTargets(
      const BudgetTargets(monthlyExpenseBudget: 1000),
    );

    expect(container.read(yearStatsProvider(2026)), same(stats));
    expect(container.read(recordsByDateProvider), same(recordsByDate));
  });

  test('保存账目刷新年度汇总但复用工时日期索引', () {
    final stats = container.read(yearStatsProvider(2026));
    final recordsByDate = container.read(recordsByDateProvider);

    controller.saveLedgerEntry(
      const LedgerEntry(
        id: 'expense',
        date: '2026-01-03',
        type: LedgerType.expense,
        amount: 30,
        category: '餐饮',
      ),
    );

    final updated = container.read(yearStatsProvider(2026));
    expect(updated, isNot(same(stats)));
    expect(updated.summary.totalExpense, 30);
    expect(updated.ledgerTrend[0].expense, 30);
    expect(container.read(recordsByDateProvider), same(recordsByDate));
  });

  test('编辑工时同步刷新日期索引、年度趋势和工作构成', () {
    final stats = container.read(yearStatsProvider(2026));
    final recordsByDate = container.read(recordsByDateProvider);

    controller.saveDay('2026-01-03', 4, '更新', rate: 12.5);

    final updated = container.read(yearStatsProvider(2026));
    final updatedIndex = container.read(recordsByDateProvider);
    expect(updated, isNot(same(stats)));
    expect(updatedIndex, isNot(same(recordsByDate)));
    expect(updatedIndex['2026-01-03']!.hours, 4);
    expect(updated.summary.totalHours, 7);
    expect(updated.summary.totalPay, 100);
    expect(updated.hoursTrend[0].hours, 4);
    expect(updated.workBreakdown.single.pay, 100);
  });
}
