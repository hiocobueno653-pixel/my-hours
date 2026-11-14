/// 与 `src/data/types.ts` 一一对应。
///
/// 字段顺序、可空性与 JSON 键名必须保持一致：JSON 备份 v4 同时是
/// 存储格式与迁移通道（见 docs/adr/0001-storage-format.md）。
library;

/// 账目类型。
enum LedgerType { income, expense }

/// 解析持久化的账目类型；非法值返回 null（由调用方丢弃该条目）。
LedgerType? parseLedgerType(Object? raw) {
  if (raw == 'income') return LedgerType.income;
  if (raw == 'expense') return LedgerType.expense;
  return null;
}

/// 账目类型的持久化字面量。
String ledgerTypeValue(LedgerType type) =>
    type == LedgerType.income ? 'income' : 'expense';

/// 一天的工时记录。
class WorkDayRecord {
  const WorkDayRecord({
    required this.date,
    required this.hours,
    this.remark = '',
    this.workId,
    this.rate,
    this.fixedPay,
    this.settled = false,
  });

  /// `YYYY-MM-DD`
  final String date;
  final double hours;
  final String remark;

  /// 关联的工作 id；缺省表示默认工作。
  final String? workId;

  /// 记录时的时薪快照（元/小时）。改工作时薪不影响历史记录。
  final double? rate;

  /// 自定义当日工资（元）；填了之后优先于「工时 × 时薪」。
  final double? fixedPay;

  /// 结算标记：工资已结算/未结算。
  final bool settled;

  WorkDayRecord copyWith({
    String? date,
    double? hours,
    String? remark,
    String? workId,
    double? rate,
    double? fixedPay,
    bool? settled,
    bool clearWorkId = false,
    bool clearRate = false,
    bool clearFixedPay = false,
  }) {
    return WorkDayRecord(
      date: date ?? this.date,
      hours: hours ?? this.hours,
      remark: remark ?? this.remark,
      workId: clearWorkId ? null : (workId ?? this.workId),
      rate: clearRate ? null : (rate ?? this.rate),
      fixedPay: clearFixedPay ? null : (fixedPay ?? this.fixedPay),
      settled: settled ?? this.settled,
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'date': date,
      'hours': hours,
      'remark': remark,
    };
    final workId = this.workId;
    if (workId != null) map['workId'] = workId;
    final rate = this.rate;
    if (rate != null) map['rate'] = rate;
    final fixedPay = this.fixedPay;
    if (fixedPay != null) map['fixedPay'] = fixedPay;
    if (settled) map['settled'] = true;
    return map;
  }
}

/// 一条账目。
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    this.remark = '',
    this.workDate,
  });

  final String id;
  final String date;
  final LedgerType type;
  final double amount;
  final String category;
  final String remark;

  /// 关联的工时日期（`YYYY-MM-DD`）。
  final String? workDate;

  LedgerEntry copyWith({
    String? id,
    String? date,
    LedgerType? type,
    double? amount,
    String? category,
    String? remark,
    String? workDate,
    bool clearWorkDate = false,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      remark: remark ?? this.remark,
      workDate: clearWorkDate ? null : (workDate ?? this.workDate),
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'id': id,
      'date': date,
      'type': ledgerTypeValue(type),
      'amount': amount,
      'category': category,
      'remark': remark,
    };
    final workDate = this.workDate;
    if (workDate != null) map['workDate'] = workDate;
    return map;
  }
}

/// 自定义账目分类。
class CustomLedgerCategory {
  const CustomLedgerCategory({
    required this.id,
    required this.type,
    required this.name,
  });

  final String id;
  final LedgerType type;
  final String name;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': ledgerTypeValue(type),
    'name': name,
  };
}

/// 一份工作：独立时薪，用于工资自动计算与按工作统计。
class WorkProfile {
  const WorkProfile({
    required this.id,
    required this.name,
    required this.hourlyRate,
  });

  final String id;
  final String name;

  /// 时薪（元/小时），0 表示未设置。
  final double hourlyRate;

  WorkProfile copyWith({String? id, String? name, double? hourlyRate}) {
    return WorkProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      hourlyRate: hourlyRate ?? this.hourlyRate,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'hourlyRate': hourlyRate,
  };
}

/// 每月预算与收入目标；0 表示未设置。
class BudgetTargets {
  const BudgetTargets({
    this.monthlyExpenseBudget = 0,
    this.monthlyIncomeGoal = 0,
  });

  final double monthlyExpenseBudget;
  final double monthlyIncomeGoal;

  BudgetTargets copyWith({
    double? monthlyExpenseBudget,
    double? monthlyIncomeGoal,
  }) {
    return BudgetTargets(
      monthlyExpenseBudget: monthlyExpenseBudget ?? this.monthlyExpenseBudget,
      monthlyIncomeGoal: monthlyIncomeGoal ?? this.monthlyIncomeGoal,
    );
  }

  Map<String, Object?> toJson() => {
    'monthlyExpenseBudget': monthlyExpenseBudget,
    'monthlyIncomeGoal': monthlyIncomeGoal,
  };
}

/// 月度工时汇总。
class MonthSummary {
  const MonthSummary({
    required this.totalHours,
    required this.workDays,
    required this.averageHours,
  });

  final double totalHours;
  final int workDays;
  final double averageHours;
}

/// 月度收支汇总。
class LedgerMonthSummary {
  const LedgerMonthSummary({
    required this.income,
    required this.expense,
    required this.balance,
  });

  final double income;
  final double expense;
  final double balance;
}

/// 结算汇总（待结算 / 已结算）。
class SettlementSummary {
  const SettlementSummary({
    required this.total,
    required this.settled,
    required this.pending,
    required this.settledCount,
    required this.pendingCount,
  });

  final double total;
  final double settled;
  final double pending;
  final int settledCount;
  final int pendingCount;
}

/// 备份文件（v4）。`app` 与 `version` 是格式校验的锚点。
class BackupFile {
  const BackupFile({
    required this.exportedAt,
    required this.records,
    required this.entries,
    required this.customCategories,
    required this.workProfiles,
    required this.budgetTargets,
  });

  static const String appId = 'my-hours';
  static const int formatVersion = 4;

  final String exportedAt;
  final List<WorkDayRecord> records;
  final List<LedgerEntry> entries;
  final List<CustomLedgerCategory> customCategories;
  final List<WorkProfile> workProfiles;
  final BudgetTargets budgetTargets;

  Map<String, Object?> toJson() => {
    'app': appId,
    'version': formatVersion,
    'exportedAt': exportedAt,
    'records': [for (final r in records) r.toJson()],
    'entries': [for (final e in entries) e.toJson()],
    'customCategories': [for (final c in customCategories) c.toJson()],
    'workProfiles': [for (final p in workProfiles) p.toJson()],
    'budgetTargets': budgetTargets.toJson(),
  };
}

/// 解析后的备份数据（不含 `app`/`version` 元信息）。
class ParsedBackupData {
  const ParsedBackupData({
    required this.records,
    required this.entries,
    required this.customCategories,
    required this.workProfiles,
    required this.budgetTargets,
  });

  final List<WorkDayRecord> records;
  final List<LedgerEntry> entries;
  final List<CustomLedgerCategory> customCategories;
  final List<WorkProfile> workProfiles;
  final BudgetTargets budgetTargets;
}
