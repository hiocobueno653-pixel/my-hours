import 'dart:ui' show Offset;

/// 最近一次按压的屏幕坐标，用于让弹窗从触发点附近生长并原路收回。
///
/// 只保留很短的时效：自动弹出的提示不应借用几秒前的一次无关点击。
class MotionOrigin {
  MotionOrigin._();

  static Offset? _point;
  static DateTime? _at;

  static void record(Offset point) {
    _point = point;
    _at = DateTime.now();
  }

  static Offset? get recent {
    final point = _point;
    final at = _at;
    if (point == null || at == null) return null;
    return DateTime.now().difference(at) < const Duration(seconds: 3)
        ? point
        : null;
  }
}
