import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/text_scaling.dart';

void main() {
  test('系统缩放与应用大字模式相乘，并受 1.30 上限约束', () {
    const scaler = AppTextScaler(TextScaler.linear(1.2), 1.12);
    expect(scaler.scale(10), closeTo(13.44, 0.001));
    expect(scaler.clamp(maxScaleFactor: 1.30).scale(10), closeTo(13.0, 0.001));
  });

  test('系统 0 缩放不会产生负值或异常', () {
    const scaler = AppTextScaler(TextScaler.linear(0), 1.12);
    expect(scaler.scale(10), 0);
  });
}
