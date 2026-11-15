/// 金额舍入：全项目唯一实现。
///
/// 所有金额（工资、账目、预算、导出）都必须经过这里，禁止各文件各自实现，
/// 否则「两位小数」的口径会在聚合与导出时漂移。
library;

/// 将元/工时安全转换为百分位定点整数，消除 IEEE-754 半值边界误差。
int toScaledCents(double value) {
  final epsilon = value >= 0 ? 1e-9 : -1e-9;
  return ((value + epsilon) * 100).round();
}

/// 四舍五入到两位小数。
double roundMoney(double value) => toScaledCents(value) / 100.0;

/// 单日工资：固定日薪优先，否则用整型百分位计算 `工时 × 时薪`。
double computeRecordPay({
  required double hours,
  required double rate,
  double? fixedPay,
}) {
  if (fixedPay != null && fixedPay.isFinite && fixedPay > 0) {
    return roundMoney(fixedPay);
  }
  final scaledHours = toScaledCents(hours);
  final scaledRate = toScaledCents(rate);
  final totalCents = ((scaledHours * scaledRate) / 100.0 + 1e-9).round();
  return totalCents / 100.0;
}
