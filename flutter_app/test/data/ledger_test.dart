import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/constants.dart';
import 'package:my_hours/data/ledger.dart';
import 'package:my_hours/data/models.dart';

/// 期望值取自旧版 React `src/data/ledger.test.ts`。
void main() {
  const entries = <LedgerEntry>[
    LedgerEntry(
      id: 'income-1',
      date: '2026-08-01',
      type: LedgerType.income,
      amount: 8000,
      category: '工资',
      remark: '8月工资',
    ),
    LedgerEntry(
      id: 'expense-1',
      date: '2026-08-02',
      type: LedgerType.expense,
      amount: 128.5,
      category: '餐饮',
      remark: '午饭',
    ),
    LedgerEntry(
      id: 'expense-2',
      date: '2026-07-30',
      type: LedgerType.expense,
      amount: 50,
      category: '交通',
      remark: '上月',
    ),
  ];

  group('账目助手', () {
    test('金额输入校验', () {
      final ok = parseAmountInput('128.50');
      expect((ok as AmountInputOk).amount, 128.5);

      final grouped = parseAmountInput('1,234.56');
      expect((grouped as AmountInputOk).amount, 1234.56);

      final fullWidthGrouped = parseAmountInput(' 1，200 ');
      expect((fullWidthGrouped as AmountInputOk).amount, 1200);

      expect((parseAmountInput('') as AmountInputError).message, '请填写金额');
      expect(
        (parseAmountInput('1.999') as AmountInputError).message,
        '金额最多两位小数',
      );
      expect(
        (parseAmountInput('0') as AmountInputError).message,
        '金额不能为 0 或过大',
      );
    });

    test('归一化与去重', () {
      final normalized = normalizeLedgerEntry(entries[0].toJson());
      expect(normalized, isNotNull);
      expect(normalized!.id, 'income-1');
      expect(normalized.amount, 8000);
      expect(normalized.remark, '8月工资');
      expect(normalized.workDate, isNull);

      expect(
        normalizeLedgerEntry({...entries[0].toJson(), 'amount': 'bad'}),
        isNull,
      );
      expect(
        normalizeLedgerEntry({...entries[0].toJson(), 'date': '2026-02-30'}),
        isNull,
      );

      final deduped = dedupeLedgerEntries([
        entries[0],
        entries[0].copyWith(amount: 999),
      ]);
      expect(deduped.length, 1);
      expect(deduped[0].amount, 999);
    });

    test('连续创建账目 id 不因同一微秒碰撞', () {
      final ids = {for (var i = 0; i < 1000; i++) createLedgerEntryId()};
      expect(ids, hasLength(1000));
    });

    test('按月过滤并倒序', () {
      final month = getLedgerMonthEntries(entries, '2026-08');
      expect(month.map((e) => e.id).toList(), ['expense-1', 'income-1']);
    });

    test('月度收入/支出/结余', () {
      final summary = getLedgerMonthSummary(entries, '2026-08');
      expect(summary.income, 8000);
      expect(summary.expense, 128.5);
      expect(summary.balance, 7871.5);
      expect(formatMoney(7871.5), '7871.5');
    });

    test('自定义分类与使用中保护', () {
      const custom = <CustomLedgerCategory>[
        CustomLedgerCategory(
          id: 'category-1',
          type: LedgerType.expense,
          name: '房租',
        ),
      ];
      final options = getAvailableLedgerCategories(
        LedgerType.expense,
        custom,
        extraCategory: '临时',
      );
      expect(options, contains('房租'));
      expect(options, contains('临时'));

      expect(getAvailableLedgerCategories(LedgerType.expense, custom), [
        ...defaultExpenseCategories,
        '房租',
      ]);

      expect(
        isLedgerCategoryNameAvailable(LedgerType.expense, '餐饮', custom),
        isFalse,
      );
      expect(
        isLedgerCategoryNameAvailable(LedgerType.expense, '房租', custom),
        isFalse,
      );
      expect(
        isLedgerCategoryNameAvailable(LedgerType.expense, '加班餐', custom),
        isTrue,
      );

      expect(
        dedupeLedgerCategories([
          ...custom,
          const CustomLedgerCategory(
            id: 'category-2',
            type: LedgerType.expense,
            name: '房租',
          ),
        ]).length,
        1,
      );

      expect(isLedgerCategoryInUse(entries, LedgerType.expense, '餐饮'), isTrue);
      expect(isLedgerCategoryInUse(entries, LedgerType.expense, '房租'), isFalse);
    });
  });
}
