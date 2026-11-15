import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/motion_origin.dart';

void main() {
  test('弹窗起点读取一次后即清空，连续弹窗不会复用旧坐标', () {
    MotionOrigin.record(const Offset(12, 34));
    expect(MotionOrigin.consumeRecent(), const Offset(12, 34));
    expect(MotionOrigin.consumeRecent(), isNull);
  });

  test('最近起点可重复读取，供非弹窗场景使用', () {
    MotionOrigin.record(const Offset(56, 78));
    expect(MotionOrigin.recent, const Offset(56, 78));
    expect(MotionOrigin.recent, const Offset(56, 78));
  });
}
