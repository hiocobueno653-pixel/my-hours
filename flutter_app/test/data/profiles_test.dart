import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/constants.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/profiles.dart';
import 'package:my_hours/data/records.dart';

/// 期望值取自 `src/data/profiles.test.ts`。
/// 注意：`profiles.ts` 里那份只读快照的 `getRecordPay` 未移植，
/// 工资统一走 `records.recordPay`（无 workProfiles 时行为等价）。
void main() {
  group('时薪输入', () {
    test('空串视为未设置（0）', () {
      expect((parseRateInput('') as RateInputOk).rate, 0);
    });

    test('接受两位小数', () {
      expect((parseRateInput('18.5') as RateInputOk).rate, 18.5);
      expect((parseRateInput('1,200') as RateInputOk).rate, 1200);
    });

    test('拒绝非法与越界', () {
      expect(parseRateInput('abc'), isA<RateInputError>());
      expect(parseRateInput('-1'), isA<RateInputError>());
      expect(parseRateInput('100000'), isA<RateInputError>());
    });
  });

  group('工作归一化', () {
    test('保留默认工作', () {
      final parsed = normalizeWorkProfile({
        'id': defaultWorkId,
        'name': '默认工作',
        'hourlyRate': 20,
      });
      expect(parsed, isNotNull);
      expect(parsed!.id, defaultWorkId);
      expect(parsed.name, '默认工作');
      expect(parsed.hourlyRate, 20);
    });

    test('拒绝非法工作', () {
      expect(normalizeWorkProfile(null), isNull);
      expect(
        normalizeWorkProfile({'id': '', 'name': 'x', 'hourlyRate': 1}),
        isNull,
      );
      expect(
        normalizeWorkProfile({'id': 'w1', 'name': '', 'hourlyRate': 1}),
        isNull,
      );
      expect(
        normalizeWorkProfile({'id': 'w1', 'name': 'x', 'hourlyRate': -2}),
        isNull,
      );
    });
  });

  group('默认工作注入', () {
    test('缺失时补齐', () {
      final result = ensureDefaultWorkProfile(const [
        WorkProfile(id: 'w1', name: '工地', hourlyRate: 30),
      ]);
      expect(result.first.id, defaultWorkId);
      expect(result.length, 2);
    });

    test('按 id 去重', () {
      final result = ensureDefaultWorkProfile(const [
        WorkProfile(id: 'w1', name: 'a', hourlyRate: 1),
        WorkProfile(id: 'w1', name: 'b', hourlyRate: 2),
      ]);
      expect(result.where((p) => p.id == 'w1').length, 1);
    });
  });

  group('工资计算（快照口径）', () {
    test('按快照计算', () {
      expect(
        recordPay(
          const WorkDayRecord(date: '2026-08-01', hours: 8, rate: 20),
          null,
        ),
        160,
      );
      expect(
        recordPay(
          const WorkDayRecord(date: '2026-08-01', hours: 8.5, rate: 12.5),
          null,
        ),
        106.25,
      );
    });

    test('无时薪返回 0', () {
      expect(
        recordPay(const WorkDayRecord(date: '2026-08-01', hours: 8), null),
        0,
      );
    });
  });

  group('预算目标', () {
    test('归一化预算值', () {
      final normalized = normalizeBudgetTargets({
        'monthlyExpenseBudget': 3000,
        'monthlyIncomeGoal': '9000',
      });
      expect(normalized.monthlyExpenseBudget, 3000);
      expect(normalized.monthlyIncomeGoal, 9000);

      final fallback = normalizeBudgetTargets({
        'monthlyExpenseBudget': -5,
        'monthlyIncomeGoal': 'x',
      });
      expect(fallback.monthlyExpenseBudget, 0);
      expect(fallback.monthlyIncomeGoal, 0);
    });

    test('预算输入空串为 0', () {
      expect((parseBudgetInput('') as BudgetInputOk).amount, 0);
      expect((parseBudgetInput('3500.5') as BudgetInputOk).amount, 3500.5);
      expect(parseBudgetInput('0.00'), isA<BudgetInputError>());
      expect(parseBudgetInput('abc'), isA<BudgetInputError>());
    });
  });
}
