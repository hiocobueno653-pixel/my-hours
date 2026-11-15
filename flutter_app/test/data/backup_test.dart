import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/backup.dart';
import 'package:my_hours/data/constants.dart';
import 'package:my_hours/data/models.dart';

/// 期望值取自 `src/data/backup.test.ts`。
void main() {
  const records = <WorkDayRecord>[
    WorkDayRecord(date: '2026-08-01', hours: 8, remark: '普通班'),
    WorkDayRecord(date: '2026-08-02', hours: 8.5, remark: '含,逗号'),
  ];

  const entries = <LedgerEntry>[
    LedgerEntry(
      id: 'entry-1',
      date: '2026-08-01',
      type: LedgerType.income,
      amount: 5000,
      category: '工资',
      remark: '8月工资',
    ),
    LedgerEntry(
      id: 'entry-2',
      date: '2026-08-02',
      type: LedgerType.expense,
      amount: 35.5,
      category: '餐饮',
      remark: '午饭,饮料',
      workDate: '2026-08-02',
    ),
  ];

  const customCategories = <CustomLedgerCategory>[
    CustomLedgerCategory(id: 'category-1', type: LedgerType.income, name: '提成'),
    CustomLedgerCategory(
      id: 'category-2',
      type: LedgerType.expense,
      name: '房租',
    ),
  ];

  const workProfiles = <WorkProfile>[
    WorkProfile(id: 'work-default', name: '工地A', hourlyRate: 25),
    WorkProfile(id: 'work-tutor', name: '家教', hourlyRate: 50),
  ];

  const budgetTargets = BudgetTargets(
    monthlyExpenseBudget: 3000,
    monthlyIncomeGoal: 8000,
  );

  group('备份', () {
    test('生成 v4 文档并保留五块数据', () {
      final payload = createBackupPayload(
        records: records,
        entries: entries,
        customCategories: customCategories,
        workProfiles: workProfiles,
        budgetTargets: budgetTargets,
        now: DateTime.utc(2026, 8, 16),
      );
      final json = payload.toJson();
      expect(json['app'], 'my-hours');
      expect(json['version'], 4);
      expect((json['records'] as List).length, 2);
      expect((json['entries'] as List).length, 2);
      expect((json['customCategories'] as List).length, 2);
      expect((json['workProfiles'] as List).length, 2);
      expect((json['budgetTargets'] as Map)['monthlyExpenseBudget'], 3000);
    });

    test('解析合法 v4 备份', () {
      final payload = createBackupPayload(
        records: records,
        entries: entries,
        customCategories: customCategories,
        workProfiles: workProfiles,
        budgetTargets: budgetTargets,
        now: DateTime.utc(2026, 8, 16),
      );
      final parsed = parseBackupText(jsonEncode(payload.toJson()));
      expect(parsed.records.length, 2);
      expect(parsed.records.first.remark, '普通班');
      expect(parsed.entries.length, 2);
      expect(parsed.customCategories.length, 2);
      expect(parsed.workProfiles.length, 2);
      expect(parsed.budgetTargets.monthlyIncomeGoal, 8000);
    });

    test('解析 v2（无自定义分类、无工作设置）', () {
      final payload = {
        'app': 'my-hours',
        'version': 2,
        'exportedAt': '2026-08-16T00:00:00.000Z',
        'records': [for (final r in records) r.toJson()],
        'entries': [for (final e in entries) e.toJson()],
      };
      final parsed = parseBackupText(jsonEncode(payload));
      expect(parsed.records.length, 2);
      expect(parsed.entries.length, 2);
      expect(parsed.customCategories, isEmpty);
      expect(parsed.workProfiles.length, 1);
      expect(parsed.workProfiles.first.id, defaultWorkId);
      expect(parsed.workProfiles.first.name, '默认工作');
      expect(parsed.workProfiles.first.hourlyRate, 0);
      expect(parsed.budgetTargets.monthlyExpenseBudget, 0);
    });

    test('解析 v1（无账目）', () {
      final payload = {
        'app': 'my-hours',
        'version': 1,
        'exportedAt': '2026-08-16T00:00:00.000Z',
        'records': [for (final r in records) r.toJson()],
      };
      final parsed = parseBackupText(jsonEncode(payload));
      expect(parsed.records.length, 2);
      expect(parsed.entries, isEmpty);
      expect(parsed.customCategories, isEmpty);
      expect(parsed.workProfiles.length, 1);
    });

    test('拒绝非法备份', () {
      expect(
        () => parseBackupText('not json'),
        throwsA(
          isA<BackupParseException>().having(
            (e) => e.message,
            'message',
            contains('不是有效 JSON'),
          ),
        ),
      );
      expect(
        () => parseBackupText('{"app":"other"}'),
        throwsA(
          isA<BackupParseException>().having(
            (e) => e.message,
            'message',
            contains('格式不正确'),
          ),
        ),
      );
      expect(
        () => parseBackupText(
          jsonEncode({
            'app': 'my-hours',
            'version': 2,
            'records': [
              {'date': 'bad', 'hours': 8, 'remark': ''},
            ],
            'entries': <Object?>[],
          }),
        ),
        throwsA(
          isA<BackupParseException>().having(
            (e) => e.message,
            'message',
            contains('没有可导入的有效数据'),
          ),
        ),
      );
    });

    test('单条坏记录被跳过，其余有效数据继续导入', () {
      final parsed = parseBackupText(
        jsonEncode({
          'app': 'my-hours',
          'version': 3,
          'records': [
            records.first.toJson(),
            {'date': 'bad', 'hours': 8, 'remark': ''},
          ],
          'entries': <Object?>[],
          'customCategories': <Object?>[
            {'id': '', 'type': 'expense', 'name': '房租'},
          ],
        }),
      );
      expect(parsed.records, hasLength(1));
      expect(parsed.customCategories, isEmpty);
      expect(parsed.droppedItems, 2);
    });
  });

  group('CSV 导出', () {
    test('月中概览含收支与分类', () {
      final csv = buildMonthOverviewCsv('2026-08', records, entries);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('日期,星期,工时,备注,收入,支出'));
      expect(csv, contains('2026-08-01,星期六,8,普通班,5000,0'));
      expect(csv, contains('2026-08-02,星期日,8.5,"含,逗号",0,35.5'));
      expect(csv, contains('月总计,工作2天,16.5,,5000,35.5'));
      expect(csv, contains('月结余,,,,4964.5,'));
      expect(csv, contains('收入分类,工资,,,5000,'));
      expect(csv, contains('支出分类,餐饮,,,,35.5'));
    });

    test('工时表与账本表带 BOM', () {
      final hoursCsv = buildMonthCsv('2026-08', records);
      expect(hoursCsv.startsWith('\uFEFF'), isTrue);
      expect(hoursCsv, contains('2026-08-01,星期六,8,普通班'));
      expect(hoursCsv, contains('月总计,工作2天,16.5,'));

      final ledgerCsv = buildLedgerCsv('2026-08', entries, records: records);
      expect(ledgerCsv.startsWith('\uFEFF'), isTrue);
      expect(ledgerCsv, contains('日期,类型,分类,金额,关联工时,备注'));
      expect(ledgerCsv, contains('2026-08-02,支出,餐饮,35.5,8.5小时,"午饭,饮料"'));
      expect(ledgerCsv, contains('月收入,5000'));
      expect(ledgerCsv, contains('月结余,4964.5'));
    });

    test('中和电子表格公式注入', () {
      const hostile = <WorkDayRecord>[
        WorkDayRecord(
          date: '2026-08-03',
          hours: 8,
          remark: '=HYPERLINK("http://evil","点我")',
        ),
        WorkDayRecord(date: '2026-08-04', hours: 8, remark: '+SUM(1,2)'),
        WorkDayRecord(date: '2026-08-05', hours: 8, remark: '@cmd'),
        WorkDayRecord(date: '2026-08-06', hours: 8, remark: '-1+1'),
        WorkDayRecord(date: '2026-08-07', hours: 8, remark: '\tTAB开头'),
        WorkDayRecord(date: '2026-08-08', hours: 8, remark: '正常备注不受影响'),
      ];
      final csv = buildMonthCsv('2026-08', hostile);
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, contains("'+SUM(1,2)"));
      expect(csv, contains("'@cmd"));
      expect(csv, contains("'-1+1"));
      expect(csv, contains("'\tTAB开头"));
      expect(csv, contains('正常备注不受影响'));
    });
  });
  group('导入体积上限（D2）', () {
    test('中文的 String.length 只是 UTF-16 code unit，远小于 UTF-8 字节数', () {
      const text = '时账';
      expect(text.length, 2);
      expect(utf8.encode(text).length, 6);
    });

    test('byteLength 超限时拒绝，即使 String.length 没超', () {
      final payload = jsonEncode({
        'app': 'my-hours',
        'version': 4,
        'records': <Object>[],
        'entries': <Object>[],
      });
      expect(payload.length, lessThan(maxBackupBytes));
      expect(
        () => parseBackupText(payload, byteLength: maxBackupBytes + 1),
        throwsA(isA<BackupParseException>()),
      );
    });
  });
}
