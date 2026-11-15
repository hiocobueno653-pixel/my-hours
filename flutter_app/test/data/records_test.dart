import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/records.dart';
import 'package:my_hours/data/wage_entries.dart';

/// 期望值全部取自旧版 React `src/data/records.test.ts` 与旧版 React `src/data/wageEntries.ts`，
/// 不重新推导——这是「两版金额逐位一致」的证据链。
void main() {
  const profiles = <WorkProfile>[
    WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 20),
    WorkProfile(id: 'work-b', name: '兼职', hourlyRate: 35),
  ];

  group('工时校验与汇总', () {
    test('接受两位小数，拒绝非法值', () {
      final ok = parseHoursInput('8.5');
      expect(ok, isA<HoursInputOk>());
      expect((ok as HoursInputOk).hours, 8.5);

      final zero = parseHoursInput('0');
      expect((zero as HoursInputOk).hours, 0);

      final empty = parseHoursInput('');
      expect((empty as HoursInputError).message, '请填写工时');

      final three = parseHoursInput('8.333');
      expect((three as HoursInputError).message, '工时最多两位小数');

      final over = parseHoursInput('25');
      expect((over as HoursInputError).message, '工时需在 0 到 24 之间');
    });

    test('归一化导入记录', () {
      final record = normalizeRecord({
        'date': '2026-08-01',
        'hours': 8.25,
        'remark': '上午',
      });
      expect(record, isNotNull);
      expect(record!.date, '2026-08-01');
      expect(record.hours, 8.25);
      expect(record.remark, '上午');
      expect(record.workId, isNull);
      expect(record.rate, isNull);
      expect(record.settled, isFalse);

      expect(normalizeRecord({'date': '2026-08-01', 'hours': 99}), isNull);
      expect(normalizeRecord({'date': 'bad', 'hours': 8}), isNull);
      expect(normalizeRecord({'date': '2026-02-30', 'hours': 8}), isNull);
    });

    test('月总计 / 工作天数 / 日均', () {
      final records = [
        const WorkDayRecord(date: '2026-08-01', hours: 8),
        const WorkDayRecord(date: '2026-08-02', hours: 8.5, remark: '加班'),
        const WorkDayRecord(date: '2026-08-03', hours: 0, remark: '休息'),
        const WorkDayRecord(date: '2026-07-31', hours: 4, remark: '上月'),
      ];
      final summary = getMonthSummary(records, '2026-08');
      expect(summary.totalHours, 16.5);
      expect(summary.workDays, 2);
      expect(summary.averageHours, 8.25);

      expect(formatHours(8), '8');
      expect(formatHours(8.5), '8.5');
    });
  });

  group('有效时薪与记录工资', () {
    test('快照为正时优先使用快照', () {
      expect(
        effectiveRate(
          const WorkDayRecord(
            date: '2026-08-01',
            hours: 8,
            rate: 25,
            workId: 'work-b',
          ),
          profiles,
        ),
        25,
      );
      expect(
        recordPay(
          const WorkDayRecord(date: '2026-08-01', hours: 8, rate: 25),
          profiles,
        ),
        200,
      );
    });

    test('快照为 0 或缺失时回退工作当前时薪', () {
      expect(
        effectiveRate(
          const WorkDayRecord(
            date: '2026-08-01',
            hours: 8,
            rate: 0,
            workId: 'work-default',
          ),
          profiles,
        ),
        20,
      );
      expect(
        effectiveRate(
          const WorkDayRecord(date: '2026-08-01', hours: 8, workId: 'work-b'),
          profiles,
        ),
        35,
      );
      // 无 workId 时按默认工作回退
      expect(
        effectiveRate(
          const WorkDayRecord(date: '2026-08-01', hours: 8),
          profiles,
        ),
        20,
      );
      expect(
        recordPay(
          const WorkDayRecord(date: '2026-08-02', hours: 6.5),
          profiles,
        ),
        130,
      );
    });

    test('任何地方都没有时薪时返回 0', () {
      expect(
        effectiveRate(
          const WorkDayRecord(date: '2026-08-01', hours: 8),
          const [],
        ),
        0,
      );
      expect(
        effectiveRate(
          const WorkDayRecord(
            date: '2026-08-01',
            hours: 8,
            rate: 0,
            workId: 'work-missing',
          ),
          profiles,
        ),
        0,
      );
      expect(
        recordPay(const WorkDayRecord(date: '2026-08-03', hours: 8), const []),
        0,
      );
    });

    test('自定义日薪优先，0 视为未设置', () {
      expect(
        recordPay(
          const WorkDayRecord(date: '2026-08-05', hours: 8, fixedPay: 350),
          profiles,
        ),
        350,
      );
      expect(
        recordPay(
          const WorkDayRecord(date: '2026-08-05', hours: 8, fixedPay: 0),
          profiles,
        ),
        160,
      );
    });
  });

  group('结算对账', () {
    const settledNoSnapshot = WorkDayRecord(
      date: '2026-08-15',
      hours: 8,
      settled: true,
    );
    const settledWithSnapshot = WorkDayRecord(
      date: '2026-08-16',
      hours: 4,
      rate: 30,
      settled: true,
    );

    test('为已结算记录补齐工资收入账目', () {
      final result = syncWageEntries(
        [settledNoSnapshot, settledWithSnapshot],
        const [],
        profiles,
      );
      expect(result.length, 2);
      expect(result[0].id, 'wage-2026-08-15');
      expect(result[0].type, LedgerType.income);
      expect(result[0].amount, 160);
      expect(result[0].category, '工资');
      expect(result[1].id, 'wage-2026-08-16');
      expect(result[1].amount, 120);
    });

    test('已存在的工资账目不被覆盖（保留用户手改）', () {
      const existing = <LedgerEntry>[
        LedgerEntry(
          id: 'wage-2026-08-15',
          date: '2026-08-15',
          type: LedgerType.income,
          amount: 999,
          category: '工资',
          remark: '手改过',
        ),
      ];
      final result = syncWageEntries([settledNoSnapshot], existing, profiles);
      expect(result.length, 1);
      expect(result[0].amount, 999);
    });

    test('无变化时返回原引用（供启动对账跳过回写）', () {
      const existing = <LedgerEntry>[
        LedgerEntry(
          id: 'wage-2026-08-15',
          date: '2026-08-15',
          type: LedgerType.income,
          amount: 999,
          category: '工资',
          remark: '手改过',
        ),
        LedgerEntry(
          id: 'entry-plain',
          date: '2026-08-15',
          type: LedgerType.expense,
          amount: 20,
          category: '餐饮',
        ),
      ];
      final result = syncWageEntries([settledNoSnapshot], existing, profiles);
      expect(identical(result, existing), isTrue);
    });

    test('旧式关联收入被工资账目替换（不双计）', () {
      const legacy = <LedgerEntry>[
        LedgerEntry(
          id: 'entry-old-1',
          date: '2026-08-15',
          type: LedgerType.income,
          amount: 400,
          category: '工资',
          remark: '结算工资',
          workDate: '2026-08-15',
        ),
      ];
      final result = syncWageEntries(
        [settledNoSnapshot.copyWith(rate: 50)],
        legacy,
        profiles,
      );
      expect(result.length, 1);
      expect(isWageEntryForDate(result[0], '2026-08-15'), isTrue);
      expect(result[0].amount, 400);
    });

    test('未结算日保留旧式关联收入', () {
      const legacy = <LedgerEntry>[
        LedgerEntry(
          id: 'entry-old-2',
          date: '2026-08-17',
          type: LedgerType.income,
          amount: 100,
          category: '工资',
          remark: '结算工资',
          workDate: '2026-08-17',
        ),
      ];
      final result = syncWageEntries(
        const [WorkDayRecord(date: '2026-08-17', hours: 8)],
        legacy,
        profiles,
      );
      expect(result.length, 1);
      expect(result[0].id, 'entry-old-2');
    });

    test('未结算记录会被跳过，残留工资账目被删除', () {
      const stale = <LedgerEntry>[
        LedgerEntry(
          id: 'wage-2026-08-17',
          date: '2026-08-17',
          type: LedgerType.income,
          amount: 160,
          category: '工资',
          remark: '结算工资',
          workDate: '2026-08-17',
        ),
      ];
      final result = syncWageEntries(
        const [WorkDayRecord(date: '2026-08-17', hours: 8)],
        stale,
        profiles,
      );
      expect(result, isEmpty);
    });

    test('工资为 0 的记录不生成账目', () {
      final result = syncWageEntries(
        const [WorkDayRecord(date: '2026-08-18', hours: 8, settled: true)],
        const [],
        const [],
      );
      expect(result, isEmpty);
    });
  });
}
