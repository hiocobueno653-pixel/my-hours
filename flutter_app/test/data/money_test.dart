import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/money.dart';

void main() {
  test('半值边界按远离零方向进位', () {
    expect(roundMoney(1.005), 1.01);
    expect(roundMoney(-1.005), -1.01);
    expect(roundMoney(2.675), 2.68);
    expect(roundMoney(-2.675), -2.68);
  });

  test('工资使用百分位定点计算，避免工时乘时薪的二进制尾差', () {
    expect(computeRecordPay(hours: 1.5, rate: 10.25), 15.38);
    expect(computeRecordPay(hours: 0.25, rate: 33.33), 8.33);
    expect(computeRecordPay(hours: 8, rate: 12.5), 100);
    expect(computeRecordPay(hours: 2, rate: 10, fixedPay: 20.005), 20.01);
  });
}
