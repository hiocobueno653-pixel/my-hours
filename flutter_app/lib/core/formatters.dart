/// 展示层格式化：金额、工时、百分比。
///
/// 数字一律用 `tabular-nums` 等宽数字（Flutter 用 `FontFeature.tabularFigures`），
/// 避免列表刷新时数字跳动。
library;

import 'package:flutter/painting.dart';

/// 金额：千分位 + 最多两位小数，去掉无意义的 `.0`。
String formatAmount(double value, {bool withSymbol = false}) {
  if (!value.isFinite) return withSymbol ? '¥—' : '—';
  final rounded = (value * 100).round() / 100;
  final negative = rounded < 0;
  final abs = rounded.abs();
  final fixed = abs.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }
  var text = buffer.toString();
  if (decPart != '00') {
    text = '$text.${decPart.endsWith('0') ? decPart[0] : decPart}';
  }
  if (negative) text = '-$text';
  return withSymbol ? '¥$text' : text;
}

/// 编辑框预填：不带千分位，避免把 `1,200` 写进会被整段正则拒绝的输入框。
///
/// 展示层用 [formatAmount]，输入层用这个函数；两者职责不同。
String formatAmountInput(double value) {
  if (!value.isFinite) return '';
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toString();
}

/// 工时：最多两位小数，去掉尾零。
String formatHoursValue(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toString();
}

/// 百分比：保留一位小数。
String formatPercent(double value) {
  final rounded = (value * 10).round() / 10;
  final sign = rounded > 0 ? '+' : '';
  return '$sign${rounded.toString()}%';
}

/// 等宽数字（金额/工时对齐）。
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
