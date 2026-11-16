/// 动效令牌。
///
/// **唯一数值源**：`E:/alma/ui-motion-playbook/02-令牌.md`（对应 `tokens.css`）。
/// 五条曲线、八档时长，没有第六种、没有第九档——组件里不许出现裸曲线或
/// 裸毫秒（`Duration(milliseconds: 260)` 这种写法一律视为错误）。
///
/// 早期数值取自 `E:/蒸馏/FlClash_UI` 的测量表，现已并入本表；两套一致
/// 的部分（如面板曲线 0.32/0.72/0/1）保留原值。
library;

import 'package:flutter/animation.dart';

/// 动效纪律（改动画前先读这里）
///
/// 1. **从哪来，回哪去**（R21/R22）：任何「开」都必须是「关」的逆运算。
///    - 对话框：从触发它的按压坐标生长，反向缩回该坐标（`MotionOrigin`）。
///    - 二级页：从右侧推入，返回推回右侧，不做「淡出消失」。
///    - 底部弹层：从屏幕底部升起，返回底部。
///    - 月份切换：往左滑 → 新月份从右进、旧月份往左退；方向由
///      `_calendarDirection` 记住，点月份选择器跳转也按大小定方向。
///    判断标准：用户能说出「它从哪儿冒出来的」；说不出来就是错的。
/// 2. **进场一律 `ease-out`，永不 `ease-in`**（R11/R12）。出场走同一曲线的
///    反向，进度在后段自然加速，观感上比进场更快收走——这就是 R07
///    「出场永远比进场快」在 Flutter 里的实现方式，不需要单独的时长。
/// 3. **透明度不做过冲**（R16）：弹簧仅用于位置与缩放，且 bounce 基本为 0。
/// 4. **每个动效要能一句话回答「为什么动」**（R03）：反馈 / 空间连续 /
///    状态指示 / 防止突变 / 解释 / 惊喜。答不出就删。
/// 5. **系统级「移除动画」优先**（R35）：时长走 `motionDuration`，或在
///    `MediaQuery.maybeDisableAnimationsOf` 为真时直接给终态。
abstract final class Timings {
  /// 状态切换。
  static const Duration instant = Duration(milliseconds: 80);

  /// 按下反馈（R14：可点元素必须有）。
  static const Duration press = Duration(milliseconds: 140);

  /// tooltip、小 popover。
  static const Duration micro = Duration(milliseconds: 180);

  /// 出场（R07：出场取进场的前一档）。
  static const Duration fast = Duration(milliseconds: 200);

  /// 进场。
  static const Duration base = Duration(milliseconds: 250);

  /// 大块移动（整屏推入、日历切月）。
  static const Duration slow = Duration(milliseconds: 320);

  /// 弹层、对话框进场。
  static const Duration panel = Duration(milliseconds: 380);

  /// 抽屉、全屏 sheet。
  static const Duration sheet = Duration(milliseconds: 500);

  /// toast 专用。
  static const Duration toast = Duration(milliseconds: 400);
}

/// 曲线。
///
/// **没有 `ease-in`**，不是漏了，是禁止：元素离开时用减速曲线反向跑，
/// 进度在末段加速，才是「干脆地走」。
abstract final class Curves2 {
  /// 默认：进场、出场、位移。内置 `easeOut` 是 (0, 0, 0.58, 1)，太软，
  /// 动起来没有确定感。
  static const Curve out = Cubic(0.23, 1, 0.32, 1);

  /// 元素在屏幕内移动、变形。
  static const Curve inOut = Cubic(0.77, 0, 0.175, 1);

  /// 从边缘推入的抽屉 / 底部弹层。
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  /// hover、变色。
  static const Curve soft = Cubic(0.25, 0.1, 0.25, 1);

  /// 跑马灯、进度、循环。
  static const Curve linear = Curves.linear;
}

/// 统一入口：把时长折叠为 0（系统「移除动画」或应用内关闭动效）。
Duration motionDuration(Duration duration, {required bool disableAnimations}) =>
    disableAnimations ? Duration.zero : duration;
