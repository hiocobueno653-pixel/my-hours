/// 账目：校验、归一化、排序、月度汇总与分类管理。
///
/// 与旧版 React `src/data/ledger.ts` 等价。`csv`/`xlsx` 导出的金额都从这里取，
/// 任何舍入差异都会在导出文件里放大，所以 `roundMoney` 必须逐处使用。
library;

import 'constants.dart';
import 'dates.dart';
import 'models.dart';
import 'money.dart';

export 'money.dart' show roundMoney;

/// 金额输入校验结果。
sealed class AmountInputResult {
  const AmountInputResult();
}

class AmountInputOk extends AmountInputResult {
  const AmountInputOk(this.amount);
  final double amount;
}

class AmountInputError extends AmountInputResult {
  const AmountInputError(this.message);
  final String message;
}

AmountInputResult parseAmountInput(String raw) {
  final trimmed = normalizeNumericInput(raw);
  if (trimmed.isEmpty) return const AmountInputError('请填写金额');
  if (!amountPattern.hasMatch(trimmed)) {
    return const AmountInputError('金额最多两位小数');
  }
  final amount = double.tryParse(trimmed);
  if (amount == null ||
      amount.isNaN ||
      amount <= 0 ||
      amount > maxLedgerAmount) {
    return const AmountInputError('金额不能为 0 或过大');
  }
  return AmountInputOk(roundMoney(amount));
}

LedgerEntry? normalizeLedgerEntry(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  if (id is! String || id.trim().isEmpty) return null;
  final date = raw['date'];
  if (date is! String || !isValidDateISO(date)) return null;
  final type = parseLedgerType(raw['type']);
  if (type == null) return null;
  final category = raw['category'];
  if (category is! String || category.trim().isEmpty) return null;

  final amountRaw = raw['amount'];
  final amount = amountRaw is num
      ? amountRaw.toDouble()
      : double.tryParse('$amountRaw');
  if (amount == null ||
      amount.isNaN ||
      amount <= 0 ||
      amount > maxLedgerAmount ||
      (roundMoney(amount) - amount).abs() > decimalTolerance) {
    return null;
  }

  final remarkRaw = raw['remark'];
  final remark = remarkRaw is String
      ? (remarkRaw.length <= maxLedgerRemarkLength
            ? remarkRaw
            : remarkRaw.substring(0, maxLedgerRemarkLength))
      : '';

  final workDateRaw = raw['workDate'];
  final workDate = workDateRaw is String && isValidDateISO(workDateRaw)
      ? workDateRaw
      : null;

  return LedgerEntry(
    id: id,
    date: date,
    type: type,
    category: category,
    amount: roundMoney(amount),
    remark: remark,
    workDate: workDate,
  );
}

List<LedgerEntry> normalizeLedgerEntries(Object? raw) {
  if (raw is! List) return const [];
  final result = <LedgerEntry>[];
  for (final item in raw) {
    final entry = normalizeLedgerEntry(item);
    if (entry != null) result.add(entry);
  }
  return result;
}

List<LedgerEntry> sortLedgerEntries(List<LedgerEntry> entries) {
  final copy = [...entries];
  copy.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return a.id.compareTo(b.id);
  });
  return copy;
}

List<LedgerEntry> sortLedgerEntriesNewestFirst(List<LedgerEntry> entries) =>
    sortLedgerEntries(entries).reversed.toList();

/// 按 id 去重（后者覆盖前者），保持排序。
List<LedgerEntry> dedupeLedgerEntries(List<LedgerEntry> entries) {
  final byId = <String, LedgerEntry>{};
  for (final entry in entries) {
    byId[entry.id] = entry;
  }
  return sortLedgerEntries(byId.values.toList());
}

List<LedgerEntry> getLedgerMonthEntries(
  List<LedgerEntry> entries,
  String yearMonth,
) {
  final prefix = '$yearMonth-';
  return sortLedgerEntriesNewestFirst([
    for (final entry in entries)
      if (entry.date.startsWith(prefix)) entry,
  ]);
}

LedgerMonthSummary getLedgerMonthSummary(
  List<LedgerEntry> entries,
  String yearMonth,
) {
  final prefix = '$yearMonth-';
  var income = 0.0;
  var expense = 0.0;
  for (final entry in entries) {
    if (!entry.date.startsWith(prefix)) continue;
    if (entry.type == LedgerType.income) {
      income += entry.amount;
    } else {
      expense += entry.amount;
    }
  }
  final roundedIncome = roundMoney(income);
  final roundedExpense = roundMoney(expense);
  return LedgerMonthSummary(
    income: roundedIncome,
    expense: roundedExpense,
    balance: roundMoney(roundedIncome - roundedExpense),
  );
}

String formatMoney(double amount) {
  final rounded = roundMoney(amount);
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toString();
}

String createLedgerEntryId() => createId('entry');

String createId(String prefix) => createEntityId(prefix);

CustomLedgerCategory? normalizeLedgerCategory(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  if (id is! String || id.trim().isEmpty) return null;
  final type = parseLedgerType(raw['type']);
  if (type == null) return null;
  final nameRaw = raw['name'];
  if (nameRaw is! String || nameRaw.trim().isEmpty) return null;
  final name = nameRaw.trim();
  return CustomLedgerCategory(
    id: id,
    type: type,
    name: name.length <= maxCategoryNameLength
        ? name
        : name.substring(0, maxCategoryNameLength),
  );
}

List<CustomLedgerCategory> normalizeLedgerCategories(Object? raw) {
  if (raw is! List) return const [];
  final result = <CustomLedgerCategory>[];
  for (final item in raw) {
    final category = normalizeLedgerCategory(item);
    if (category != null) result.add(category);
  }
  return result;
}

/// 按 `type:name` 去重（先到先得）。
List<CustomLedgerCategory> dedupeLedgerCategories(
  List<CustomLedgerCategory> categories,
) {
  final seen = <String>{};
  final result = <CustomLedgerCategory>[];
  for (final category in categories) {
    final key = '${ledgerTypeValue(category.type)}:${category.name}';
    if (seen.contains(key)) continue;
    seen.add(key);
    result.add(category);
  }
  return result;
}

List<String> defaultCategoriesOf(LedgerType type) => type == LedgerType.income
    ? defaultIncomeCategories
    : defaultExpenseCategories;

List<String> getAvailableLedgerCategories(
  LedgerType type,
  List<CustomLedgerCategory> customCategories, {
  String? extraCategory,
}) {
  final names = <String>[
    ...defaultCategoriesOf(type),
    for (final category in customCategories)
      if (category.type == type) category.name,
  ];
  final extra = extraCategory;
  if (extra != null && !names.contains(extra)) names.add(extra);
  return names;
}

bool isLedgerCategoryNameAvailable(
  LedgerType type,
  String name,
  List<CustomLedgerCategory> customCategories,
) {
  final normalized = name.trim();
  if (normalized.isEmpty) return false;
  final existing = <String>[
    ...defaultCategoriesOf(type),
    for (final category in customCategories)
      if (category.type == type) category.name,
  ];
  return !existing.contains(normalized);
}

bool isLedgerCategoryInUse(
  List<LedgerEntry> entries,
  LedgerType type,
  String name,
) => entries.any((entry) => entry.type == type && entry.category == name);

/// 月内某天的账目（升序）。
List<LedgerEntry> getEntriesForDate(List<LedgerEntry> entries, String date) {
  return sortLedgerEntries([
    for (final entry in entries)
      if (entry.date == date) entry,
  ]);
}

/// 某天关联工时账目的合计（用于详情页展示）。
double sumAmounts(Iterable<LedgerEntry> entries) {
  var total = 0.0;
  for (final entry in entries) {
    total += entry.amount;
  }
  return roundMoney(total);
}

/// 校验日期字符串可用作账目日期。
bool isValidLedgerDate(String value) => isValidDateISO(value);
