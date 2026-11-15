import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/records.dart';
import 'package:my_hours/data/wage_entries.dart';

/// Golden case：每条都是「输入 → 期望金额」，期望值由 React 版口径推导，
/// 与旧版 React `src/data/records.ts` 的 `recordRate` / `recordPay` 逐行对应。
///
/// 覆盖：整数/小数工时 × 整数/小数时薪、fixedPay 优先、快照 0 回退、
/// 无 workId 回退默认工作、无时薪为 0、跨月汇总、结算账目金额、聚合顺序。
void main() {
  const defaultProfile = WorkProfile(
    id: 'work-default',
    name: '默认工作',
    hourlyRate: 22,
  );
  const secondProfile = WorkProfile(id: 'w2', name: '兼职', hourlyRate: 37.5);
  const profiles = <WorkProfile>[defaultProfile, secondProfile];

  /// (说明, 工时, 快照, 日薪, workId, 期望工资)
  final cases = <(String, double, double?, double?, String?, double)>[
    ('整数工时 × 整数时薪（回退默认）', 8, null, null, null, 176),
    ('小数工时 × 整数时薪', 8.5, null, null, null, 187),
    ('整数工时 × 小数时薪', 4, null, null, 'w2', 150),
    ('小数工时 × 小数时薪', 7.5, null, null, 'w2', 281.25),
    ('零点五小时', 0.5, null, null, null, 11),
    ('零点二五小时（两位小数下限）', 0.25, null, null, null, 5.5),
    ('零工时（休息日）', 0, null, null, null, 0),
    ('快照优先于当前时薪', 8, 30, null, 'w2', 240),
    ('快照为 0 时回退当前时薪', 8, 0, null, 'w2', 300),
    ('快照缺失时回退当前时薪', 2, null, null, 'w2', 75),
    ('自定义日薪优先于工时', 8, 30, 500, null, 500),
    ('自定义日薪为 0 视为未设置', 8, 30, 0, null, 240),
    ('自定义日薪含小数', 3, null, 123.45, null, 123.45),
    ('未知 workId 且无快照 → 0', 8, null, null, 'work-missing', 0),
    ('零工时但有自定义日薪', 0, null, 200, null, 200),
    ('工时 24 小时上限', 24, null, null, null, 528),
    ('时薪含两位小数', 3, null, null, 'w2', 112.5),
    ('快照含两位小数', 1.5, 18.75, null, null, 28.13),
    ('四舍五入到分（进位）', 1.11, 9.99, null, null, 11.09),
    ('四舍五入到分（舍去）', 1.11, 9.9, null, null, 10.99),
  ];

  group('golden · 单条工资', () {
    for (final (label, hours, rate, fixedPay, workId, expected) in cases) {
      test(label, () {
        final record = WorkDayRecord(
          date: '2026-08-01',
          hours: hours,
          rate: rate,
          fixedPay: fixedPay,
          workId: workId,
        );
        expect(recordPay(record, profiles), expected);
      });
    }
  });

  group('golden · 聚合顺序', () {
    test('月工资逐条舍入后再累加', () {
      // 8×18.75=150；1.5×18.75=28.125→28.13；0.1×18.75=1.875→1.88
      final records = <WorkDayRecord>[
        const WorkDayRecord(date: '2026-08-01', hours: 8, rate: 18.75),
        const WorkDayRecord(date: '2026-08-02', hours: 1.5, rate: 18.75),
        const WorkDayRecord(date: '2026-08-03', hours: 0.1, rate: 18.75),
      ];
      expect(getMonthPay(records, '2026-08', null), 180.01);
    });

    test('跨月只统计当月', () {
      final records = <WorkDayRecord>[
        const WorkDayRecord(date: '2026-07-31', hours: 8, rate: 20),
        const WorkDayRecord(date: '2026-08-01', hours: 8, rate: 20),
        const WorkDayRecord(date: '2026-09-01', hours: 8, rate: 20),
      ];
      expect(getMonthPay(records, '2026-08', null), 160);
      expect(getMonthSummary(records, '2026-08').workDays, 1);
    });

    test('结算汇总：总额/已结算/待结算/笔数', () {
      final records = <WorkDayRecord>[
        const WorkDayRecord(
          date: '2026-08-01',
          hours: 8,
          rate: 20,
          settled: true,
        ),
        const WorkDayRecord(date: '2026-08-02', hours: 4, rate: 20),
        const WorkDayRecord(date: '2026-08-03', hours: 0, rate: 20),
      ];
      final summary = getSettlementSummary(records, '2026-08', null);
      expect(summary.total, 240);
      expect(summary.settled, 160);
      expect(summary.pending, 80);
      expect(summary.settledCount, 1);
      expect(summary.pendingCount, 1);
    });
  });

  group('golden · 结算账目金额', () {
    test('工资账目金额与记录工资一致', () {
      const record = WorkDayRecord(
        date: '2026-08-09',
        hours: 6.5,
        rate: 21.5,
        settled: true,
      );
      final entries = syncWageEntries([record], const [], profiles);
      expect(entries.length, 1);
      expect(entries.first.amount, 139.75);
      expect(entries.first.id, 'wage-2026-08-09');
      expect(entries.first.category, '工资');
      expect(entries.first.remark, '结算工资');
      expect(entries.first.workDate, '2026-08-09');
    });

    test('日薪结算进入账目', () {
      const record = WorkDayRecord(
        date: '2026-08-10',
        hours: 8,
        fixedPay: 480,
        settled: true,
      );
      final entries = syncWageEntries([record], const [], profiles);
      expect(entries.single.amount, 480);
    });

    test('取消结算后账目被移除', () {
      const record = WorkDayRecord(
        date: '2026-08-11',
        hours: 8,
        rate: 20,
        settled: true,
      );
      final settledEntries = syncWageEntries([record], const [], profiles);
      final unsettledEntries = syncWageEntries(
        [record.copyWith(settled: false)],
        settledEntries,
        profiles,
      );
      expect(unsettledEntries, isEmpty);
    });
  });
}
