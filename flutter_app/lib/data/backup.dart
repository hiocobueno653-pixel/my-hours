/// 备份（v1–v4）与 CSV 导出。
///
/// 与旧版 React `src/data/backup.ts` 等价。两条不可妥协的规则：
/// 1. 导入对单条坏数据容错、对外层结构严格：外层标识/版本/JSON 语法损坏时
///    整份拒绝；列表中的坏条目跳过并计数。若整份备份没有任何有效条目，
///    仍然拒绝，避免用「全坏文件」覆盖现有数据。
/// 2. CSV 必须保留**公式注入防护**（OWASP）：以 `= + @ TAB CR` 或 `-` 开头的
///    单元格前置单引号，否则用户备注里的 `=cmd` 会在 Excel 里被当公式执行。
library;

import 'dart:convert';

import 'dates.dart';
import 'ledger.dart';
import 'models.dart';
import 'profiles.dart';
import 'records.dart';
import 'stats.dart';

class BackupParseException implements Exception {
  const BackupParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

BackupFile createBackupPayload({
  required List<WorkDayRecord> records,
  required List<LedgerEntry> entries,
  required List<CustomLedgerCategory> customCategories,
  required List<WorkProfile> workProfiles,
  required BudgetTargets budgetTargets,
  DateTime? now,
}) {
  return BackupFile(
    exportedAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
    records: dedupeRecords(records),
    entries: dedupeLedgerEntries(entries),
    customCategories: dedupeLedgerCategories(customCategories),
    workProfiles: dedupeWorkProfiles(workProfiles),
    budgetTargets: normalizeBudgetTargets(budgetTargets.toJson()),
  );
}

/// 备份文本上限（字节数与条目数）。
///
/// 导入是唯一接受外部输入的入口：一份 500 MB 的 JSON 或百万条记录的数组
/// 足以在解析阶段把进程撑死，而用户只会看到"闪退"。这里在 decode 之前就拒绝。
const int maxBackupBytes = 20 * 1024 * 1024;
const int maxBackupRecords = 50000;
const int maxBackupEntries = 200000;

/// 解析备份文本（v1–v4）。失败抛 [BackupParseException]，消息可直接展示给用户。
ParsedBackupData parseBackupText(String text, {int? byteLength}) {
  // byteLength 由文件层传入真实 UTF-8 字节数；只有拿不到时才退回 UTF-16 长度，
  // 那种情况会低估中文体积，仅作为兜底。
  if ((byteLength ?? text.length) > maxBackupBytes) {
    throw const BackupParseException('备份文件过大（超过 20 MB），请确认选对了文件');
  }
  Object? parsed;
  try {
    parsed = _decodeJson(text);
  } on FormatException {
    throw const BackupParseException('备份文件不是有效 JSON');
  }
  if (parsed is! Map) {
    throw const BackupParseException('备份文件格式不正确');
  }
  if (parsed['app'] != 'my-hours') {
    throw const BackupParseException('备份文件格式不正确');
  }
  final versionRaw = parsed['version'];
  final version = versionRaw is num ? versionRaw.toInt() : null;
  if (version == null || version < 1 || version > 4) {
    throw const BackupParseException('备份文件版本不支持');
  }

  final recordsRaw = parsed['records'];
  if (recordsRaw is! List) {
    throw const BackupParseException('备份文件缺少工时记录');
  }
  if (recordsRaw.length > maxBackupRecords) {
    throw const BackupParseException('备份包含的工时记录过多');
  }
  final entriesRawCheck = parsed['entries'];
  if (entriesRawCheck is List && entriesRawCheck.length > maxBackupEntries) {
    throw const BackupParseException('备份包含的账目过多');
  }
  final normalizedRecords = <WorkDayRecord>[];
  var droppedItems = 0;
  for (final item in recordsRaw) {
    final record = normalizeRecord(item);
    if (record == null) {
      droppedItems++;
      continue;
    }
    normalizedRecords.add(record);
  }

  // v2 起 entries 是必需字段。缺字段若按空数组放行，一份被截断的备份会
  // 「导入成功、跳过 0 条」地把整本账目清空。
  final entriesRaw = version == 1 ? const <Object?>[] : parsed['entries'];
  if (entriesRaw is! List) {
    throw BackupParseException(
      version == 1 ? '备份文件账目数据格式不正确' : '备份文件缺少账目数据',
    );
  }
  final normalizedEntries = normalizeLedgerEntries(entriesRaw);
  droppedItems += entriesRaw.length - normalizedEntries.length;

  var customCategories = <CustomLedgerCategory>[];
  if (version >= 3) {
    final categoriesRaw = parsed['customCategories'];
    if (categoriesRaw is! List) {
      throw const BackupParseException('备份文件缺少自定义分类');
    }
    final normalized = normalizeLedgerCategories(categoriesRaw);
    droppedItems += categoriesRaw.length - normalized.length;
    customCategories = dedupeLedgerCategories(normalized);
  }

  List<WorkProfile> workProfiles;
  if (version >= 4) {
    final profilesRaw = parsed['workProfiles'];
    if (profilesRaw is! List) {
      throw const BackupParseException('备份文件缺少工作设置');
    }
    final normalized = normalizeWorkProfiles(profilesRaw);
    droppedItems += profilesRaw.length - normalized.length;
    workProfiles = ensureDefaultWorkProfile(dedupeWorkProfiles(normalized));
  } else {
    // v1–v3 备份默认只有一份默认工作
    workProfiles = ensureDefaultWorkProfile(const []);
  }

  final result = ParsedBackupData(
    records: dedupeRecords(normalizedRecords),
    entries: dedupeLedgerEntries(normalizedEntries),
    customCategories: customCategories,
    workProfiles: workProfiles,
    budgetTargets: normalizeBudgetTargets(parsed['budgetTargets']),
    droppedItems: droppedItems,
  );
  final rawItemCount =
      recordsRaw.length +
      entriesRaw.length +
      (version >= 3 && parsed['customCategories'] is List
          ? (parsed['customCategories'] as List).length
          : 0) +
      (version >= 4 && parsed['workProfiles'] is List
          ? (parsed['workProfiles'] as List).length
          : 0);
  if (rawItemCount > 0 &&
      result.records.isEmpty &&
      result.entries.isEmpty &&
      result.customCategories.isEmpty &&
      result.workProfiles.length <= 1) {
    throw const BackupParseException('备份中没有可导入的有效数据');
  }
  return result;
}

Object? _decodeJson(String text) => jsonDecode(text);

/// CSV 单元格：公式注入防护 + 必要转义。
String csvCell(String value) {
  var text = value;
  // 纯数字（含负数）不是公式：月结余为负是常态，加前缀会让 Excel
  // 把整列读成文本，既不能计算也不能排序。
  final startsRisky =
      !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(text) &&
      text.isNotEmpty &&
      (text.startsWith('=') ||
          text.startsWith('+') ||
          text.startsWith('@') ||
          text.startsWith('\t') ||
          text.startsWith('\r') ||
          text.startsWith('-'));
  if (startsRisky) text = "'$text";
  if (text.contains('"') ||
      text.contains(',') ||
      text.contains('\r') ||
      text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String _row(List<String> cells) => cells.map(csvCell).join(',');

String _joinCsv(List<String> lines) => '\uFEFF${lines.join('\r\n')}';

/// 月工时表（CSV）。
String buildMonthCsv(String yearMonth, List<WorkDayRecord> records) {
  final lines = <String>[
    _row(['日期', '星期', '工时', '备注']),
  ];
  for (final day in getMonthDates(yearMonth)) {
    final record = getRecordByDate(records, day.date);
    lines.add(
      _row([
        day.date,
        '星期${weekdayName(day.weekday)}',
        record == null ? '' : formatHours(record.hours),
        record == null ? '' : record.remark,
      ]),
    );
  }
  final summary = getMonthSummary(records, yearMonth);
  lines.add(
    _row([
      '月总计',
      '工作${summary.workDays}天',
      formatHours(summary.totalHours),
      '',
    ]),
  );
  return _joinCsv(lines);
}

/// 月中概览（工时 + 收支 + 分类，CSV）。
String buildMonthOverviewCsv(
  String yearMonth,
  List<WorkDayRecord> records,
  List<LedgerEntry> entries,
) {
  final lines = <String>[
    _row(['日期', '星期', '工时', '备注', '收入', '支出']),
  ];
  for (final day in getMonthDates(yearMonth)) {
    final record = getRecordByDate(records, day.date);
    final dayEntries = [
      for (final entry in entries)
        if (entry.date == day.date) entry,
    ];
    var income = 0.0;
    var expense = 0.0;
    for (final entry in dayEntries) {
      if (entry.type == LedgerType.income) {
        income += entry.amount;
      } else {
        expense += entry.amount;
      }
    }
    lines.add(
      _row([
        day.date,
        '星期${weekdayName(day.weekday)}',
        record == null ? '' : formatHours(record.hours),
        record == null ? '' : record.remark,
        formatMoney(roundMoney(income)),
        formatMoney(roundMoney(expense)),
      ]),
    );
  }
  final hoursSummary = getMonthSummary(records, yearMonth);
  final ledgerSummary = getLedgerMonthSummary(entries, yearMonth);
  lines.add(
    _row([
      '月总计',
      '工作${hoursSummary.workDays}天',
      formatHours(hoursSummary.totalHours),
      '',
      formatMoney(ledgerSummary.income),
      formatMoney(ledgerSummary.expense),
    ]),
  );
  lines.add(_row(['月结余', '', '', '', formatMoney(ledgerSummary.balance), '']));
  final categories = getMonthCategoryTotals(entries, yearMonth);
  for (final row in categories) {
    if (row.type == LedgerType.income) {
      lines.add(_row(['收入分类', row.name, '', '', formatMoney(row.total), '']));
    }
  }
  for (final row in categories) {
    if (row.type == LedgerType.expense) {
      lines.add(_row(['支出分类', row.name, '', '', '', formatMoney(row.total)]));
    }
  }
  return _joinCsv(lines);
}

/// 月账本（CSV）。
String buildLedgerCsv(
  String yearMonth,
  List<LedgerEntry> entries, {
  List<WorkDayRecord> records = const [],
}) {
  final lines = <String>[
    _row(['日期', '类型', '分类', '金额', '关联工时', '备注']),
  ];
  final prefix = '$yearMonth-';
  final monthEntries = sortLedgerEntries([
    for (final entry in entries)
      if (entry.date.startsWith(prefix)) entry,
  ]);
  for (final entry in monthEntries) {
    final workDate = entry.workDate;
    final linked = workDate == null ? null : getRecordByDate(records, workDate);
    lines.add(
      _row([
        entry.date,
        entry.type == LedgerType.income ? '收入' : '支出',
        entry.category,
        formatMoney(entry.amount),
        linked == null ? '' : '${formatHours(linked.hours)}小时',
        entry.remark,
      ]),
    );
  }
  final summary = getLedgerMonthSummary(entries, yearMonth);
  lines.add(_row(['', '', '月收入', formatMoney(summary.income), '', '']));
  lines.add(_row(['', '', '月支出', formatMoney(summary.expense), '', '']));
  lines.add(_row(['', '', '月结余', formatMoney(summary.balance), '', '']));
  return _joinCsv(lines);
}

/// 月工时表（行数据，供 xlsx 导出复用）。
List<List<String>> buildMonthRows(
  String yearMonth,
  List<WorkDayRecord> records,
) {
  final rows = <List<String>>[
    ['日期', '星期', '工时', '备注'],
  ];
  for (final day in getMonthDates(yearMonth)) {
    final record = getRecordByDate(records, day.date);
    rows.add([
      day.date,
      '星期${weekdayName(day.weekday)}',
      record == null ? '' : formatHours(record.hours),
      record == null ? '' : record.remark,
    ]);
  }
  final summary = getMonthSummary(records, yearMonth);
  rows.add([
    '月总计',
    '工作${summary.workDays}天',
    formatHours(summary.totalHours),
    '',
  ]);
  return rows;
}

/// 月账本（行数据，供 xlsx 导出复用）。
List<List<String>> buildLedgerRows(
  String yearMonth,
  List<LedgerEntry> entries, {
  List<WorkDayRecord> records = const [],
}) {
  final rows = <List<String>>[
    ['日期', '类型', '分类', '金额', '关联工时', '备注'],
  ];
  final prefix = '$yearMonth-';
  final monthEntries = sortLedgerEntries([
    for (final entry in entries)
      if (entry.date.startsWith(prefix)) entry,
  ]);
  for (final entry in monthEntries) {
    final workDate = entry.workDate;
    final linked = workDate == null ? null : getRecordByDate(records, workDate);
    rows.add([
      entry.date,
      entry.type == LedgerType.income ? '收入' : '支出',
      entry.category,
      formatMoney(entry.amount),
      linked == null ? '' : '${formatHours(linked.hours)}小时',
      entry.remark,
    ]);
  }
  final summary = getLedgerMonthSummary(entries, yearMonth);
  rows.add(['', '', '月收入', formatMoney(summary.income), '', '']);
  rows.add(['', '', '月支出', formatMoney(summary.expense), '', '']);
  rows.add(['', '', '月结余', formatMoney(summary.balance), '', '']);
  return rows;
}

/// 月中概览（行数据，供 xlsx 导出复用）。
List<List<String>> buildMonthOverviewRows(
  String yearMonth,
  List<WorkDayRecord> records,
  List<LedgerEntry> entries,
) {
  final rows = <List<String>>[
    ['日期', '星期', '工时', '备注', '收入', '支出'],
  ];
  for (final day in getMonthDates(yearMonth)) {
    final record = getRecordByDate(records, day.date);
    var income = 0.0;
    var expense = 0.0;
    for (final entry in entries) {
      if (entry.date != day.date) continue;
      if (entry.type == LedgerType.income) {
        income += entry.amount;
      } else {
        expense += entry.amount;
      }
    }
    rows.add([
      day.date,
      '星期${weekdayName(day.weekday)}',
      record == null ? '' : formatHours(record.hours),
      record == null ? '' : record.remark,
      formatMoney(roundMoney(income)),
      formatMoney(roundMoney(expense)),
    ]);
  }
  final hoursSummary = getMonthSummary(records, yearMonth);
  final ledgerSummary = getLedgerMonthSummary(entries, yearMonth);
  rows.add([
    '月总计',
    '工作${hoursSummary.workDays}天',
    formatHours(hoursSummary.totalHours),
    '',
    formatMoney(ledgerSummary.income),
    formatMoney(ledgerSummary.expense),
  ]);
  rows.add(['月结余', '', '', '', formatMoney(ledgerSummary.balance), '']);
  final categories = getMonthCategoryTotals(entries, yearMonth);
  for (final row in categories) {
    if (row.type == LedgerType.income) {
      rows.add(['收入分类', row.name, '', '', formatMoney(row.total), '']);
    }
  }
  for (final row in categories) {
    if (row.type == LedgerType.expense) {
      rows.add(['支出分类', row.name, '', '', '', formatMoney(row.total)]);
    }
  }
  return rows;
}
