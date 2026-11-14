import 'package:flutter/widgets.dart';

/// 把系统文本缩放与应用内“大字模式”相乘，并给整个应用一个安全上限。
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.appFactor);

  final TextScaler system;
  final double appFactor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * appFactor;

  @override
  double get textScaleFactor => system.scale(1) * appFactor;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.system == system &&
      other.appFactor == appFactor;

  @override
  int get hashCode => Object.hash(system, appFactor);
}
