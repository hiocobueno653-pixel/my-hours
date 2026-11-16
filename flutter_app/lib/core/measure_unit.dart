import 'package:flutter/widgets.dart';

/// 计量单位。
///
/// 这个 App 记的是「一段时间投入在一件事上的量」。它的语义不该被写死成
/// 工时——同样是 8，可以是 8 小时、8 学时、8 节课、8 页。
///
/// 数据层不动：`WorkDayRecord.hours` 依旧是一个 `double`，单位只是**显示
/// 层**的标签。所以切换单位不会碰备份格式，也不会影响任何金额计算。
@immutable
class MeasureUnit {
  const MeasureUnit({
    required this.id,
    required this.name,
    required this.short,
    required this.quantity,
  }) : assert(id != '');

  /// 稳定 id，存进设置。
  final String id;

  /// 单位全称，跟在数字后面：「8 小时」「8 学时」「3 章」。
  final String name;

  /// 数字旁的短单位：「8.5 h」「8.5 节」。
  final String short;

  /// 数量本身的名词：「本月工时」「本月学时」「本月页数」。
  final String quantity;

  static const hours = MeasureUnit(
    id: 'hours',
    name: '小时',
    short: 'h',
    quantity: '工时',
  );
  static const schoolHours = MeasureUnit(
    id: 'school_hours',
    name: '学时',
    short: '节',
    quantity: '学时',
  );
  static const sessions = MeasureUnit(
    id: 'sessions',
    name: '次',
    short: '次',
    quantity: '次数',
  );
  static const chapters = MeasureUnit(
    id: 'chapters',
    name: '章',
    short: '章',
    quantity: '章数',
  );
  static const pages = MeasureUnit(
    id: 'pages',
    name: '页',
    short: '页',
    quantity: '页数',
  );
  static const kilometers = MeasureUnit(
    id: 'kilometers',
    name: '公里',
    short: 'km',
    quantity: '里程',
  );

  static const List<MeasureUnit> presets = [
    hours,
    schoolHours,
    sessions,
    chapters,
    pages,
    kilometers,
  ];

  static MeasureUnit byId(String? id) {
    for (final unit in presets) {
      if (unit.id == id) return unit;
    }
    return hours;
  }
}

/// 把当前单位送到整棵树。
///
/// 放在 `MaterialApp` 外层，所有页面用 `MeasureUnitScope.of(context)` 取。
class MeasureUnitScope extends InheritedWidget {
  const MeasureUnitScope({
    super.key,
    required this.unit,
    required super.child,
  });

  final MeasureUnit unit;

  static MeasureUnit of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MeasureUnitScope>();
    return scope?.unit ?? MeasureUnit.hours;
  }

  @override
  bool updateShouldNotify(MeasureUnitScope oldWidget) =>
      oldWidget.unit.id != unit.id;
}

/// 便捷读取。
extension MeasureUnitX on BuildContext {
  MeasureUnit get unit => MeasureUnitScope.of(this);
}
