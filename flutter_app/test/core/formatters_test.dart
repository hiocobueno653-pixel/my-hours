import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/formatters.dart';

void main() {
  test('编辑框金额不带千分位，展示金额仍带千分位', () {
    expect(formatAmount(1200), '1,200');
    expect(formatAmountInput(1200), '1200');
    expect(formatAmount(1234.56), '1,234.56');
    expect(formatAmountInput(1234.56), '1234.56');
  });

  test('非有限金额不会让格式化抛异常', () {
    expect(formatAmount(double.nan), '—');
    expect(formatAmount(double.infinity, withSymbol: true), '¥—');
    expect(formatAmountInput(double.nan), '');
  });
}
