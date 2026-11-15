/// 基础 UI 原语：卡片、按压面、按钮、列表行、分段控件、空态、数字输入。
///
/// 视觉语言取自 `E:/蒸馏/FlClash_UI` 的移动端令牌：表面层级用填充区分、
/// 所有容器走超椭圆、按压只做 10% 墨迹不缩放。只依赖本仓库令牌，
/// 不引入 prism_ui 或其它 GPL 组件。
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluid_glass/fluid_glass.dart';

import '../core/formatters.dart';
import '../core/motion.dart';
import '../core/motion_origin.dart';
import '../core/theme_tokens.dart';

/// 内容卡：卡片色填充 + 轻投影，不用描边区分层级。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
    this.radius = Radii.card,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final shape = Radii.shape(radius);
    final content = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: context.colors.card,
        shape: shape,
        shadows: context.shadows,
      ),
      child: child,
    );
    final wrapped = onTap == null
        ? content
        : Pressable(shape: shape, onTap: onTap!, child: content);
    return margin == null ? wrapped : Padding(padding: margin!, child: wrapped);
  }
}

/// 可按压面：按下覆盖 10% 内容色，200ms 淡入淡出；不缩放。
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = true,
    this.shape,
    this.radius = 12,
    this.pressedScale = 1,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  /// 墨迹裁剪形状；与父容器保持一致。
  final ShapeBorder? shape;

  /// 未传 `shape` 时使用的超椭圆半径。
  final double radius;

  /// 按下时的轻微收缩；默认不缩放。
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shape = widget.shape ?? Radii.shape(widget.radius);

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (details) {
          MotionOrigin.record(details.globalPosition);
          setState(() => _pressed = false);
        },
        onTap: widget.onTap == null
            ? null
            : () {
                // 触摸抬起后才算一次点击，滚动列表时不会误触发震动。
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _pressed && !disable ? widget.pressedScale : 1,
          duration: motionDuration(Timings.press, disableAnimations: disable),
          curve: Curves2.out,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              if (widget.onTap != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _pressed ? 1 : 0,
                      duration: motionDuration(
                        Timings.short,
                        disableAnimations: disable,
                      ),
                      curve: Curves2.standard,
                      child: ClipPath(
                        clipper: ShapeBorderClipper(shape: shape),
                        child: ColoredBox(
                          color: colors.text.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主按钮：品牌蓝实心，白字。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bg = danger ? colors.expense : colors.primary;
    final fg = danger ? scheme.onError : colors.onPrimary;
    final button = Opacity(
      opacity: onPressed == null ? 0.38 : 1,
      child: GlassQualityScope(
        quality: GlassQuality.plain,
        child: LiquidButton(
          onPressed: onPressed,
          backdrop: nativeBackdrop,
          isInteractive: !disable,
          surfaceColor: bg.withValues(alpha: 0.90),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: Gaps.sm),
              ],
              if (expand)
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// 次级按钮：块面填充，无描边。
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  /// 占满可用宽度（弹层、卡片里的次级操作常用）。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fg = danger ? colors.expense : colors.text;
    final bg = danger ? colors.expenseSoft : colors.block;
    final button = Opacity(
      opacity: onPressed == null ? 0.38 : 1,
      child: GlassQualityScope(
        quality: GlassQuality.plain,
        child: LiquidButton(
          onPressed: onPressed,
          backdrop: nativeBackdrop,
          isInteractive: !disable,
          surfaceColor: bg.withValues(alpha: colors.isDark ? 0.34 : 0.26),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              if (expand)
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// 顶栏/弹层共用的轻量玻璃面。
///
/// 它不再套第二层 `BackdropFilter`：父级顶栏已经负责模糊，按钮只画
/// 半透明填充、白色内高光和超椭圆边，避免多层水玻璃互相采样。
class HeaderGlassSurface extends StatelessWidget {
  const HeaderGlassSurface({
    super.key,
    required this.child,
    this.height = 40,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.bright = false,
  });

  final Widget child;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.isDark;
    final shape = Radii.shape(radius);
    final borderColor = bright
        ? Colors.white.withValues(alpha: isDark ? 0.16 : 0.95)
        : Colors.white.withValues(alpha: isDark ? 0.08 : 0.30);
    final fillColor = selected
        ? colors.primaryContainer.withValues(alpha: isDark ? 0.46 : 0.72)
        : bright
        ? null
        : colors.block.withValues(alpha: isDark ? 0.90 : 1);
    final fillGradient = bright && !selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colors.card.withValues(alpha: 0.90),
                    colors.block.withValues(alpha: 0.82),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.97),
                    const Color(0xFFF8F9FC).withValues(alpha: 0.92),
                  ],
          )
        : null;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.24 : (bright ? 0.05 : 0.045),
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: fillColor,
              gradient: fillGradient,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radius),
                side: BorderSide(
                  color: borderColor,
                  width: bright && !isDark ? 1.5 : 0.9,
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.62],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 独立玻璃图标按钮：统一 44×44 圆形材质，按压轻微回弹。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.selected = false,
    this.iconSize = 20,
    this.size = 44,
    this.radius = 22,
    this.bright = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool selected;
  final double iconSize;
  final double size;
  final double radius;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = HeaderGlassSurface(
      height: size,
      radius: radius,
      selected: selected,
      bright: bright,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: iconSize,
          color: selected ? colors.onPrimaryContainer : colors.text,
        ),
      ),
    );
    final button = Pressable(
      onTap: onTap,
      shape: Radii.shape(radius),
      pressedScale: 0.94,
      child: content,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 顶栏图标按钮的语义别名，保留既有调用点。
class BarActionButton extends StatelessWidget {
  const BarActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.selected = false,
    this.iconSize = 20,
    this.size = 44,
    this.radius = 22,
    this.bright = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool selected;
  final double iconSize;
  final double size;
  final double radius;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: icon,
      onTap: onTap,
      tooltip: tooltip,
      selected: selected,
      iconSize: iconSize,
      size: size,
      radius: radius,
      bright: bright,
    );
  }
}

/// 撤销条：浮在内容上方的短提示，6 秒后自动消失。
class UndoBar extends StatelessWidget {
  const UndoBar({
    super.key,
    required this.message,
    required this.onUndo,
    this.seconds = 6,
  });

  final String message;
  final VoidCallback onUndo;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gaps.lg),
      padding: const EdgeInsets.only(left: Gaps.lg, right: 6),
      height: 48,
      decoration: ShapeDecoration(
        color: colors.card,
        shape: Radii.shape(Radii.md),
        shadows: context.floatingShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: colors.text),
              ),
            ),
          ),
          Pressable(
            onTap: onUndo,
            shape: Radii.pillShape,
            child: SizedBox(
              width: 64,
              height: 48,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: ShapeDecoration(
                    color: colors.primaryContainer,
                    shape: Radii.pillShape,
                  ),
                  child: Text(
                    '撤销',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置/导航行。
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.showChevron = false,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Gaps.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.33,
                    fontWeight: FontWeight.w500,
                    color: danger ? colors.expense : colors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.38,
                      color: colors.text2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
          if (showChevron)
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.text3),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// 弹层标题栏的轻量文本动作，避免依赖 Material splash。
class TextActionButton extends StatelessWidget {
  const TextActionButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Pressable(
        onTap: onPressed,
        shape: Radii.pillShape,
        pressedScale: 0.94,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onPressed == null ? colors.text3 : colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 分段控件：inset 轨道 + 单块滑动选中指示器。
///
/// 选中背景只移动不重建，文字颜色随位置淡变，避免每个分段各自闪一下。
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: colors.inset, shape: Radii.shape(18)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / values.length;
          final selectedIndex = values
              .indexOf(selected)
              .clamp(0, values.length - 1);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: motionDuration(
                  Timings.short,
                  disableAnimations: disable,
                ),
                curve: Curves2.emphasizedDecelerate,
                left: selectedIndex * segmentWidth,
                top: 0,
                width: segmentWidth,
                height: 36,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.primary,
                    shape: Radii.shape(14),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == selected,
                        label: labelOf(value),
                        onTap: () => onChanged(value),
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: () => onChanged(value),
                          shape: Radii.shape(14),
                          child: SizedBox(
                            height: 36,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: motionDuration(
                                  Timings.short,
                                  disableAnimations: disable,
                                ),
                                curve: Curves2.standard,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: value == selected
                                      ? colors.onPrimary
                                      : colors.text,
                                ),
                                child: Text(labelOf(value)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 月份文本切换：旧月份淡出上移，新月份淡入落定。
class AnimatedMonthLabel extends StatelessWidget {
  const AnimatedMonthLabel({
    super.key,
    required this.label,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final TextStyle style;
  final Alignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedSwitcher(
      duration: motionDuration(Timings.short, disableAnimations: disable),
      switchInCurve: Curves2.out,
      switchOutCurve: Curves2.inCurve,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        label,
        key: ValueKey(label),
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

/// 空态。
/// 存档隔离态的常驻提示条。
///
/// 三代存档全坏时存储层会拒绝一切普通写入（只有导入备份能写）。
/// 不提示的话，用户只会看到「点了保存，重开就没了」，且不知道原因。
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textColor = colors.isDark
        ? const Color(0xFFFFDAD6)
        : const Color(0xFF991B1B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ShapeDecoration(
        color: colors.expenseSoft,
        shape: Radii.shape(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '存档损坏，当前为只读：改动不会写入磁盘。'
              '请到「我的 → 数据与备份」导入一份备份恢复。',
              style: TextStyle(fontSize: 12, height: 1.45, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 隔离态下用户仍可能点开写入口；统一给出可操作提示，而不是静默失败。
void showArchiveReadOnlyMessage(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('存档损坏，当前为只读。请先到「我的 → 数据与备份」导入备份。'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: ShapeDecoration(
                color: colors.primaryContainer.withValues(
                  alpha: colors.isDark ? 0.48 : 0.72,
                ),
                shape: Radii.shape(Radii.lg),
              ),
              child: Icon(Icons.inbox_rounded, size: 30, color: colors.primary),
            ),
            const SizedBox(height: Gaps.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.text2,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Gaps.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// 数字输入（工时/金额/时薪共用）。
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.hintText,
    this.suffixText,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
    this.allowDecimal = true,
    this.fontSize = 22,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? suffixText;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final bool allowDecimal;
  final double fontSize;
  final TextAlign textAlign;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = Radii.shape(Radii.md);
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: ShapeDecoration(color: colors.block, shape: shape),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    autofocus: widget.autofocus,
                    onSubmitted: widget.onSubmitted,
                    textAlign: widget.textAlign,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.allowDecimal,
                    ),
                    inputFormatters: [
                      if (widget.allowDecimal)
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final raw = newValue.text;
                          final text = raw.replaceAll(RegExp(r'[,\s，]'), '');
                          if (text.isEmpty) {
                            return newValue.copyWith(
                              text: '',
                              selection: const TextSelection.collapsed(
                                offset: 0,
                              ),
                            );
                          }
                          // 多个小数点仍然视为非法输入，保持原值；
                          // 逗号/空格则是粘贴格式，清洗后继续校验。
                          if ('.'.allMatches(text).length > 1) return oldValue;
                          final match = RegExp(r'^(\d*)(?:\.(\d*))?$')
                              .firstMatch(text);
                          if (match == null) return oldValue;
                          final integerPart = match.group(1) ?? '';
                          final decimalPart = match.group(2);
                          final cappedInteger = integerPart.length > 9
                              ? integerPart.substring(0, 9)
                              : integerPart;
                          final cappedDecimal = decimalPart == null
                              ? null
                              : (decimalPart.length > 2
                                    ? decimalPart.substring(0, 2)
                                    : decimalPart);
                          final cleaned = cappedDecimal == null
                              ? cappedInteger
                              : '$cappedInteger.$cappedDecimal';
                          if (cleaned == raw) return newValue;
                          return newValue.copyWith(
                            text: cleaned,
                            selection: TextSelection.collapsed(
                              offset: cleaned.length,
                            ),
                          );
                        })
                      else
                        FilteringTextInputFormatter.digitsOnly,
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                      letterSpacing: -0.02,
                      fontFeatures: tabularFigures,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: widget.fontSize,
                        color: colors.text3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (widget.suffixText != null)
                  Text(
                    widget.suffixText!,
                    style: TextStyle(fontSize: 13, color: colors.text2),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: motionDuration(
                  const Duration(milliseconds: 160),
                  disableAnimations: disable,
                ),
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    side: BorderSide(
                      color: _focused ? colors.primary : Colors.transparent,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 页头（无边框，保留给非吸顶场景）。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions,
    this.scrolled = false,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;
  final bool scrolled;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedContainer(
      duration: motionDuration(
        const Duration(milliseconds: 200),
        disableAnimations: disable,
      ),
      padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.sm, Gaps.md),
      color: scrolled ? colors.page : Colors.transparent,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Gaps.sm)],
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: colors.text,
            ),
          ),
          const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}

/// 浮动玻璃容器（底部 Dock / 浮动工具条）。
///
/// FlClash 的 dock 材质：真模糊 + 饱和提升 + 半透明表面 + 1px 白色内高光。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = Radii.xxl,
    this.blur = 22,
    this.opacity = 0.62,
    this.padding = const EdgeInsets.all(4),
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.isDark;
    final shape = Radii.shape(radius);
    final tint = isDark
        ? colors.card.withValues(alpha: 0.56)
        : Colors.white.withValues(alpha: opacity);
    final specular = isDark
        ? Colors.white.withValues(alpha: 0.26)
        : Colors.white.withValues(alpha: 0.92);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: context.floatingShadows,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: ColorFilter.matrix(_saturationMatrix(isDark ? 1.9 : 2.08)),
            inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: tint,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(radius),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.62),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // 内部斜向高光：让整块玻璃有厚度，而不是一张半透明纸。
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.04),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.06),
                            ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              // 顶部镜面高光：液态玻璃最关键的“厚度线”。
              Positioned(
                top: 0.7,
                left: radius * 0.18,
                right: radius * 0.18,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        specular,
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // 底部反光弱于顶部，避免上下对称的塑料感。
              Positioned(
                bottom: 0.6,
                left: radius * 0.24,
                right: radius * 0.24,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.36),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }

  static List<double> _saturationMatrix(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    return <double>[
      sr + s,
      sg,
      sb,
      0,
      0,
      sr,
      sg + s,
      sb,
      0,
      0,
      sr,
      sg,
      sb + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
