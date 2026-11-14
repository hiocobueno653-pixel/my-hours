import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/backup.dart';
import 'package:my_hours/data/ledger.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/records.dart';
import 'package:my_hours/data/wage_entries.dart';

/// 迁移夹具：一份「真实形态」的 v4 备份（多工作 / 自定义日薪 / 已结算且已生成
/// 工资账目 / 自定义分类 / 预算），导入后逐项对账。
///
/// 通过标准（计划 §7）：月总工时、月工资、待结算、已结算、账目结余 五项全等。
void main() {
  final fixture = <String, Object?>{
    'app': 'my-hours',
    'version': 4,
    'exportedAt': '2026-08-31T12:00:00.000Z',
    'records': [
      {
        'date': '2026-08-01',
        'hours': 8,
        'remark': '工地',
        'workId': 'work-a',
        'rate': 25,
        'settled': true,
      },
      {
        'date': '2026-08-02',
        'hours': 6.5,
        'remark': '加班',
        'workId': 'work-a',
        'rate': 25,
      },
      {
        'date': '2026-08-03',
        'hours': 4,
        'remark': '家教',
        'workId': 'work-b',
        'rate': 50,
        'settled': true,
      },
      {'date': '2026-08-04', 'hours': 0, 'remark': '休息'},
      {
        'date': '2026-08-05',
        'hours': 8,
        'remark': '固定日薪',
        'workId': 'work-a',
        'fixedPay': 300,
        'settled': true,
      },
      {'date': '2026-08-06', 'hours': 3, 'remark': '无快照回退', 'workId': 'work-b'},
      {
        'date': '2026-07-31',
        'hours': 5,
        'remark': '上月',
        'workId': 'work-a',
        'rate': 25,
      },
    ],
    'entries': [
      {
        'id': 'wage-2026-08-01',
        'date': '2026-08-01',
        'type': 'income',
        'amount': 200,
        'category': '工资',
        'remark': '结算工资',
        'workDate': '2026-08-01',
      },
      {
        'id': 'wage-2026-08-03',
        'date': '2026-08-03',
        'type': 'income',
        'amount': 200,
        'category': '工资',
        'remark': '结算工资',
        'workDate': '2026-08-03',
      },
      {
        'id': 'wage-2026-08-05',
        'date': '2026-08-05',
        'type': 'income',
        'amount': 300,
        'category': '工资',
        'remark': '结算工资',
        'workDate': '2026-08-05',
      },
      {
        'id': 'entry-food',
        'date': '2026-08-02',
        'type': 'expense',
        'amount': 45.5,
        'category': '餐饮',
        'remark': '午饭',
      },
      {
        'id': 'entry-rent',
        'date': '2026-08-01',
        'type': 'expense',
        'amount': 1200,
        'category': '房租',
        'remark': '月租',
      },
      {
        'id': 'entry-bonus',
        'date': '2026-08-10',
        'type': 'income',
        'amount': 500,
        'category': '奖金',
        'remark': '季度奖',
      },
    ],
    'customCategories': [
      {'id': 'c1', 'type': 'expense', 'name': '房租'},
    ],
    'workProfiles': [
      {'id': 'work-default', 'name': '默认工作', 'hourlyRate': 0},
      {'id': 'work-a', 'name': '工地', 'hourlyRate': 25},
      {'id': 'work-b', 'name': '家教', 'hourlyRate': 50},
    ],
    'budgetTargets': {'monthlyExpenseBudget': 4000, 'monthlyIncomeGoal': 9000},
  };

  test('v4 夹具导入：五项对账', () {
    final parsed = parseBackupText(jsonEncode(fixture));

    // 1) 记录数（去重后 7 条，含上月 1 条）
    expect(parsed.records.length, 7);

    // 2) 月总工时（8 月：8 + 6.5 + 4 + 0 + 8 + 3 = 29.5）
    final summary = getMonthSummary(parsed.records, '2026-08');
    expect(summary.totalHours, 29.5);
    expect(summary.workDays, 5);

    // 3) 月工资（逐条舍入后累加）
    // 8×25=200；6.5×25=162.5；4×50=200；0；fixedPay 300；3×50=150
    expect(getMonthPay(parsed.records, '2026-08', parsed.workProfiles), 1012.5);

    // 4) 待结算 / 已结算
    final settlement = getSettlementSummary(
      parsed.records,
      '2026-08',
      parsed.workProfiles,
    );
    expect(settlement.total, 1012.5);
    expect(settlement.settled, 700);
    expect(settlement.pending, 312.5);
    expect(settlement.settledCount, 3);
    expect(settlement.pendingCount, 2);

    // 5) 账目结余（导入后对账：工资账目应保持 700，不新增不重复）
    final synced = syncWageEntries(
      parsed.records,
      parsed.entries,
      parsed.workProfiles,
    );
    final ledger = getLedgerMonthSummary(synced, '2026-08');
    expect(ledger.income, 1200); // 200 + 200 + 300 + 500 奖金
    expect(ledger.expense, 1245.5); // 45.5 + 1200
    expect(ledger.balance, -45.5);

    // 工资账目数量：3 条（与已结算记录一一对应，无残留、无双计）
    expect(synced.where((e) => isWageEntryForDate(e, e.date)).length, 3);
  });

  test('夹具导入后再次对账不变（幂等）', () {
    final parsed = parseBackupText(jsonEncode(fixture));
    final first = syncWageEntries(
      parsed.records,
      parsed.entries,
      parsed.workProfiles,
    );
    final second = syncWageEntries(parsed.records, first, parsed.workProfiles);
    expect(identical(second, first), isTrue);
  });

  test('自定义分类与预算随导入保留', () {
    final parsed = parseBackupText(jsonEncode(fixture));
    expect(parsed.customCategories.single.name, '房租');
    expect(parsed.budgetTargets.monthlyExpenseBudget, 4000);
    expect(parsed.budgetTargets.monthlyIncomeGoal, 9000);
    expect(parsed.workProfiles.length, 3);
    expect(
      getAvailableLedgerCategories(LedgerType.expense, parsed.customCategories),
      contains('房租'),
    );
  });

  test('未知 workId 且无快照：工资为 0，不生成账目', () {
    final parsed = parseBackupText(
      jsonEncode({
        'app': 'my-hours',
        'version': 4,
        'exportedAt': '2026-08-31T12:00:00.000Z',
        'records': [
          {
            'date': '2026-08-07',
            'hours': 8,
            'remark': '',
            'workId': 'ghost',
            'settled': true,
          },
        ],
        'entries': <Object?>[],
        'customCategories': <Object?>[],
        'workProfiles': [
          {'id': 'work-default', 'name': '默认工作', 'hourlyRate': 0},
        ],
        'budgetTargets': {'monthlyExpenseBudget': 0, 'monthlyIncomeGoal': 0},
      }),
    );
    expect(getMonthPay(parsed.records, '2026-08', parsed.workProfiles), 0);
    expect(
      syncWageEntries(parsed.records, parsed.entries, parsed.workProfiles),
      isEmpty,
    );
  });
}
