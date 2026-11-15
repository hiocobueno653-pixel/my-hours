/// 动效常量。
///
/// 数值取自 `E:/蒸馏/FlClash_UI/docs/03-动效系统.md` 的**测量表**（时长、曲线、
/// 弹簧参数是观测事实，不是代码），并叠加 `interfaces.rauno.me` 的交互纪律：
/// - 交互反馈类动画 ≤ 200ms；
/// - 弹层从 0.8 缩放，不从 0；
/// - 主题切换不触发过渡（避免「整页在渐变」的廉价感）；
/// - 频繁、低新奇度的动作不加动画。
library;

import 'package:flutter/animation.dart';

/// 动效纪律（改动画前先读这里）
///
/// 1. **从哪来，回哪去**：任何「开」的动作都要能被「关」原路撤回。
///    - 对话框：从触发它的按压坐标生长，反向沿同一路径缩回该坐标
///      （`MotionOrigin` + `Curves2.standardAccelerate`）。
///    - 二级页：从右侧推入，返回时推回右侧，不做「淡出消失」。
///    - 底部弹层：从屏幕底部升起，返回底部。
///    - 月份切换：往左滑动 → 新月份从右进、旧月份往左退；方向由
///      `_calendarDirection` 记住，点月份选择器跳转也按大小定方向。
///    判断标准：用户能说出「它从哪儿冒出来的」；说不出来就是错的。
/// 2. **进场减速、退场加速**：`standardDecelerate` 落定，`standardAccelerate`
///    离开。退场用进场曲线会让元素「恋恋不舍」地慢慢消失。
/// 3. **透明度不做过冲**：只有位置与缩放可以用 `softSpring`。颜色、不透明度
///    一旦过冲就会闪。
/// 4. **系统级「移除动画」优先**：所有时长走 `motionDuration`，或在
///    `MediaQuery.maybeDisableAnimationsOf` 为真时直接给终态。
///
/// 时长档位。
abstract final class Timings {
  /// 按压反馈。
  static const Duration press = Duration(milliseconds: 140);

  /// 微交互（勾选、开关内部）。
  static const Duration micro = Duration(milliseconds: 120);

  /// 短过渡（tab 淡入、图标切换）。
  static const Duration short = Duration(milliseconds: 220);

  /// 中过渡（列表增删、折叠区）。
  static const Duration medium = Duration(milliseconds: 340);

  /// 退场。
  static const Duration exit = Duration(milliseconds: 280);

  /// 通用（内容增删、空态进入）。
  static const Duration common = Duration(milliseconds: 300);

  /// 页面转场。
  static const Duration page = Duration(milliseconds: 300);

  /// 主题交叉淡入。
  static const Duration theme = Duration(milliseconds: 200);

  /// Dock 镜头在目标间移动。
  static const Duration dockTravel = Duration(milliseconds: 400);

  /// Dock 抬升/落下。
  static const Duration dockLift = Duration(milliseconds: 250);

  /// Dock 松手落定。
  static const Duration dockSettle = Duration(milliseconds: 500);

  /// Dock 悬停。
  static const Duration dockHover = Duration(milliseconds: 260);

  /// 玻璃光晕亮起 / 熄灭。
  static const Duration glowIn = Duration(milliseconds: 100);
  static const Duration glowOut = Duration(milliseconds: 500);

  /// 骨架脉冲周期。
  static const Duration skeleton = Duration(milliseconds: 1600);
}

/// 曲线。
abstract final class Curves2 {
  static const Curve out = Curves.easeOutCubic;
  static const Curve inCurve = Curves.easeInCubic;
  static const Curve inOut = Curves.easeInOut;
  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve standardDecelerate = Cubic(0, 0, 0.2, 1);
  static const Curve standardAccelerate = Cubic(0.3, 0, 1, 1);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// 轻微过冲（~5%），用于「落定」而非「弹出」。
  static const Curve softSpring = Cubic(0.32, 1.3, 0.38, 1);
}

/// 弹簧。
abstract final class Springs {
  /// 页面推入 / 回退：300ms 临界阻尼。
  static const SpringDescription page = SpringDescription(
    mass: 1,
    stiffness: 170,
    damping: 26,
  );

  /// Dock 镜头移动：400ms bounce 0.15。
  static final SpringDescription dockTravel =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 0.85);

  /// Dock 果冻形变：stiffness 100 / ratio 0.4。
  static const SpringDescription dockJelly = SpringDescription(
    mass: 1,
    stiffness: 100,
    damping: 12.6,
  );

  /// Dock 弹性按压：stiffness 311 / ratio 0.593。
  static const SpringDescription dockPress = SpringDescription(
    mass: 1,
    stiffness: 311,
    damping: 20.9,
  );

  /// Dock 拖拽跟手：stiffness 1024 / ratio 0.9。
  static const SpringDescription dockFollow = SpringDescription(
    mass: 1,
    stiffness: 1024,
    damping: 57.6,
  );

  /// 底部弹层：stiffness 333.33 临界阻尼（约 0.5s）。
  static const SpringDescription sheet = SpringDescription(
    mass: 1,
    stiffness: 333.33,
    damping: 36.5,
  );

  /// 轻量「落定」（撤销条、toast）。
  static const SpringDescription settle = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 28,
  );
}

/// 缩放比例（避免 0→1 的廉价弹出）。
abstract final class Scales {
  static const double dialogFrom = 0.86;
  static const double sheetFrom = 0.94;
  static const double press = 0.97;
  static const double dockLens = 1.12;
}

/// 统一入口：把时长折叠为 0（系统「移除动画」或应用内关闭动效）。
Duration motionDuration(Duration duration, {required bool disableAnimations}) =>
    disableAnimations ? Duration.zero : duration;
