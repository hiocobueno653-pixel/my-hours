/// 工作（时薪）与预算目标。
///
/// 与 `src/data/profiles.ts` 等价。注意：`profiles.ts` 里那份
/// `getRecordPay`（只用 rate 快照、不回退）是历史残留，**不要**移植；
/// 工资口径以 `records.dart` 的 `recordPay` 为准。
library;

import 'constants.dart';
import 'models.dart';

/// 时薪输入校验结果。
sealed class RateInputResult {
  const RateInputResult();
}

class RateInputOk extends RateInputResult {
  const RateInputOk(this.rate);
  final double rate;
}

class RateInputError extends RateInputResult {
  const RateInputError(this.message);
  final String message;
}

double _round2(double value) => (value * 100).round() / 100;

RateInputResult parseRateInput(String raw) {
  final trimmed = normalizeNumericInput(raw);
  if (trimmed.isEmpty) return const RateInputOk(0);
  if (!ratePattern.hasMatch(trimmed)) {
    return const RateInputError('时薪最多两位小数');
  }
  final rate = double.tryParse(trimmed);
  if (rate == null || rate.isNaN || rate < 0 || rate > maxHourlyRate) {
    return const RateInputError('时薪需在 0 到 99999.99 之间');
  }
  return RateInputOk(_round2(rate));
}

String formatRate(double rate) {
  final rounded = _round2(rate);
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toString();
}

String createWorkProfileId() {
  return createEntityId('work');
}

WorkProfile createDefaultWorkProfile({double rate = 0}) => WorkProfile(
  id: defaultWorkId,
  name: defaultWorkName,
  hourlyRate: _round2(rate),
);

WorkProfile? normalizeWorkProfile(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  if (id is! String || id.trim().isEmpty) return null;
  final nameRaw = raw['name'];
  if (nameRaw is! String || nameRaw.trim().isEmpty) return null;
  final trimmedName = nameRaw.trim();
  final name = trimmedName.length <= maxWorkNameLength
      ? trimmedName
      : trimmedName.substring(0, maxWorkNameLength);

  final rateRaw = raw['hourlyRate'];
  final rate = rateRaw is num
      ? rateRaw.toDouble()
      : double.tryParse('$rateRaw');
  if (rate == null ||
      rate.isNaN ||
      rate < 0 ||
      rate > maxHourlyRate ||
      (_round2(rate) - rate).abs() > decimalTolerance) {
    return null;
  }
  return WorkProfile(id: id, name: name, hourlyRate: _round2(rate));
}

List<WorkProfile> normalizeWorkProfiles(Object? raw) {
  if (raw is! List) return const [];
  final result = <WorkProfile>[];
  for (final item in raw) {
    final profile = normalizeWorkProfile(item);
    if (profile != null) result.add(profile);
  }
  return result;
}

List<WorkProfile> dedupeWorkProfiles(List<WorkProfile> profiles) {
  final seen = <String>{};
  final result = <WorkProfile>[];
  for (final profile in profiles) {
    if (seen.contains(profile.id)) continue;
    seen.add(profile.id);
    result.add(profile);
  }
  return result;
}

/// 确保默认工作存在且位于首位。
List<WorkProfile> ensureDefaultWorkProfile(
  List<WorkProfile> profiles, {
  double rate = 0,
}) {
  final deduped = dedupeWorkProfiles(profiles);
  final existingIndex = deduped.indexWhere((p) => p.id == defaultWorkId);
  if (existingIndex >= 0) {
    final existing = deduped.removeAt(existingIndex);
    return [existing, ...deduped];
  }
  return [createDefaultWorkProfile(rate: rate), ...deduped];
}

WorkProfile? getWorkById(List<WorkProfile> profiles, String? workId) {
  if (workId == null) return null;
  for (final profile in profiles) {
    if (profile.id == workId) return profile;
  }
  return null;
}

/// 某条记录使用的工作名（用于按工作分组统计）。
String workNameOf(WorkDayRecord record, List<WorkProfile> profiles) {
  final profile = getWorkById(profiles, record.workId ?? defaultWorkId);
  return profile?.name ?? defaultWorkName;
}

/// 预算输入校验结果。
sealed class BudgetInputResult {
  const BudgetInputResult();
}

class BudgetInputOk extends BudgetInputResult {
  const BudgetInputOk(this.amount);
  final double amount;
}

class BudgetInputError extends BudgetInputResult {
  const BudgetInputError(this.message);
  final String message;
}

BudgetTargets normalizeBudgetTargets(Object? raw) {
  if (raw is! Map) return const BudgetTargets();
  double clean(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null ||
        parsed.isNaN ||
        parsed < 0 ||
        parsed > maxBudgetAmount) {
      return 0;
    }
    return _round2(parsed);
  }

  return BudgetTargets(
    monthlyExpenseBudget: clean(raw['monthlyExpenseBudget']),
    monthlyIncomeGoal: clean(raw['monthlyIncomeGoal']),
  );
}

BudgetInputResult parseBudgetInput(String raw) {
  final trimmed = normalizeNumericInput(raw);
  if (trimmed.isEmpty) return const BudgetInputOk(0);
  if (!amountPattern.hasMatch(trimmed)) {
    return const BudgetInputError('金额最多两位小数');
  }
  final amount = double.tryParse(trimmed);
  if (amount == null ||
      amount.isNaN ||
      amount <= 0 ||
      amount > maxBudgetAmount) {
    return const BudgetInputError('金额不能为 0 或过大');
  }
  return BudgetInputOk(_round2(amount));
}
