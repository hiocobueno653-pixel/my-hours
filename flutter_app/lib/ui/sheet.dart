/// 底部弹层：圆角 28 顶部、拖拽条、标题栏。
///
/// 关闭语义（修复点）：
/// - 无未保存内容：`canPop = true`，下滑、点遮罩、系统返回键都能直接关闭。
/// - 有未保存内容：`canPop = false`，任何关闭动作都会先弹确认框；确认后才放行。
/// - 不再用「canPop 恒为 false + 手动 maybePop」的写法——那会让 `Navigator.pop()`
///   反过来触发 `onPopInvokedWithResult`，形成永远关不掉的递归。
library;

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import '../core/theme_tokens.dart';
import '../platform/back_navigation.dart';
import 'dialog.dart';
import 'widgets.dart';

final ImageFilter _sheetBlurFilter = ImageFilter.blur(sigmaX: 26, sigmaY: 26);

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '关闭弹层',
    barrierColor: Colors.transparent,
    transitionDuration: motionDuration(
      Timings.panel,
      disableAnimations: disable,
    ),
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      final scrimOpacity = animation.drive(
        CurveTween(curve: const Interval(0, 0.42, curve: Curves2.out)),
      );
      // drive(CurveTween) 而不是 CurvedAnimation：后者构造时会给 parent
      // 注册 statusListener，在 pageBuilder 里每次重建都留下一个，
      // 直到路由销毁才回收。
      final curved = animation.drive(
        CurveTween(curve: LiquidSprings.smoothCurve),
      );
      final panelFade = animation.drive(
        CurveTween(curve: const Interval(0, 0.55, curve: Curves2.out)),
      );
      final panelScale = Tween<double>(
        begin: 0.98,
        end: 1.0,
      ).animate(animation.drive(CurveTween(curve: LiquidSprings.smoothCurve)));
      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: scrimOpacity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismissible
                    ? () {
                        if (BackNavigation.dispatch()) return;
                        Navigator.of(sheetContext).pop();
                      }
                    : null,
                child: ColoredBox(
                  key: const ValueKey('sheet-scrim'),
                  color: Colors.black.withValues(
                    alpha: dismissible ? 0.22 : 0.30,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: panelFade,
              child: ScaleTransition(
                scale: disable
                    ? const AlwaysStoppedAnimation<double>(1.0)
                    : panelScale,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.24),
                    end: Offset.zero,
                  ).animate(curved),
                  // MaterialApp 的 fallback text style 会在缺少 Material 祖先时
                  // 给文字加黄色双下划线；弹层必须自己提供一层透明 Material。
                  child: RepaintBoundary(
                    child: Material(
                      type: MaterialType.transparency,
                      // 键盘弹出时弹层会接近满屏；必须保留顶部系统栏安全区，
                      // 否则标题和关闭键会钻到状态栏下面。
                      child: SafeArea(
                        top: true,
                        bottom: false,
                        child: builder(sheetContext),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

/// 弹层外壳。`guard` 返回 true 表示「有未保存修改」，关闭前需确认。
class SheetScaffold extends StatefulWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.footer,
    this.titleWidget,
    this.guard,
    this.maxHeightFactor = 0.92,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? footer;

  /// 需要把日期导航等控件嵌进标题时使用；为空时显示 [title]。
  final Widget? titleWidget;

  /// 返回 true 表示「有未保存修改」，此时不关闭并给出提示。
  final bool Function()? guard;
  final double maxHeightFactor;

  @override
  State<SheetScaffold> createState() => _SheetScaffoldState();
}

class _SheetScaffoldState extends State<SheetScaffold>
    with SingleTickerProviderStateMixin {
  final Object _backToken = Object();
  final ValueNotifier<double> _dragOffset = ValueNotifier<double>(0.0);
  AnimationController? _resetController;
  double _rawDragOffset = 0.0;

  /// 用户已确认放弃修改，允许本次 pop 通过。
  bool _allowPop = false;
  bool _confirming = false;
  bool _dragging = false;
  bool _crossedDismissDetent = false;

  bool get _dirty => widget.guard?.call() ?? false;

  @override
  void initState() {
    super.initState();
    // 物理返回键：与下滑/遮罩走同一套确认逻辑
    BackNavigation.register(_backToken, () {
      _requestClose();
      return true;
    });
  }

  @override
  void dispose() {
    BackNavigation.unregister(_backToken);
    _resetController?.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (_confirming) return false;
    _confirming = true;
    final confirmed = await showConfirmDialog(
      context,
      title: '放弃未保存的修改？',
      description: '关闭后本次输入不会保留。',
      confirmLabel: '放弃',
      danger: true,
    );
    _confirming = false;
    return confirmed == true;
  }

  Future<void> _requestClose() async {
    if (!mounted) return;
    if (_dirty) {
      final ok = await _confirmDiscard();
      if (!ok || !mounted) return;
    }
    setState(() => _allowPop = true);
    // 等 PopScope 收到新的 canPop 再 pop，避免同一帧被旧值拦截
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _startDrag(DragStartDetails details) {
    if (_dirty) return;
    _resetController?.stop();
    _rawDragOffset = _dragOffset.value;
    _crossedDismissDetent = _dragOffset.value > 84;
    setState(() => _dragging = true);
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!_dragging) return;
    _rawDragOffset = (_rawDragOffset + details.delta.dy).clamp(-120.0, 260.0);
    if (_rawDragOffset < 0) {
      _dragOffset.value = LiquidSprings.rubberBandOffset(_rawDragOffset, 180.0);
    } else {
      _dragOffset.value = _rawDragOffset;
    }
    final crossed = _dragOffset.value > 84;
    if (crossed != _crossedDismissDetent) {
      _crossedDismissDetent = crossed;
      if (crossed) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _animateOffsetToZero({double velocity = 0.0}) {
    if (_dragOffset.value.abs() <= 0.05) {
      _dragOffset.value = 0.0;
      _rawDragOffset = 0.0;
      return;
    }
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _dragOffset.value = 0.0;
      _rawDragOffset = 0.0;
      return;
    }
    final controller = _resetController ??= AnimationController.unbounded(
      vsync: this,
      value: _dragOffset.value,
    )..addListener(_onResetTick);
    controller.value = _dragOffset.value;
    unawaited(
      controller.animateWith(
        SpringSimulation(
          LiquidSprings.fluid,
          _dragOffset.value,
          0.0,
          velocity.clamp(-1600.0, 1600.0),
        ),
      ),
    );
  }

  void _onResetTick() {
    final controller = _resetController;
    if (controller == null) return;
    _dragOffset.value = controller.value;
    _rawDragOffset = controller.value;
  }

  void _endDrag(DragEndDetails details) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    final vy = details.velocity.pixelsPerSecond.dy;
    final projected = _dragOffset.value + LiquidSprings.projectMomentum(vy);
    final shouldClose =
        _dragOffset.value > 84 ||
        vy > 620 ||
        (_dragOffset.value > 18 && projected > 110);
    if (shouldClose) {
      _requestClose();
    } else {
      _animateOffsetToZero(velocity: vy);
    }
  }

  void _cancelDrag() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _animateOffsetToZero();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final highContrast = media.highContrast;
    final disable = media.disableAnimations;
    final actions = widget.actions ?? const <Widget>[];
    final centeredTitle = widget.titleWidget != null && actions.isEmpty;
    final closeButton = Semantics(
      key: const ValueKey('sheet-close-button'),
      button: true,
      label: '关闭',
      onTap: _requestClose,
      excludeSemantics: true,
      child: Pressable(
        onTap: _requestClose,
        shape: Radii.pillShape,
        pressedScale: 0.94,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: ShapeDecoration(
                color: colors.isDark
                    ? Colors.white.withValues(alpha: 0.11)
                    : colors.block,
                shape: Radii.pillShape,
              ),
              child: Icon(Icons.close_rounded, size: 17, color: colors.text2),
            ),
          ),
        ),
      ),
    );
    final sheetShape = RoundedSuperellipseBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
    );
    final surfaceColor = highContrast
        ? colors.card
        : (colors.isDark
              ? const Color(0xFF1A1C24).withValues(alpha: 0.84)
              : Colors.white.withValues(alpha: 0.84));
    final sheetBody = DecoratedBox(
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              surfaceColor,
              Colors.white,
              colors.isDark ? 0.04 : 0.14,
            )!,
            surfaceColor,
          ],
        ),
        shape: sheetShape,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _startDrag,
            onVerticalDragUpdate: _updateDrag,
            onVerticalDragEnd: _endDrag,
            onVerticalDragCancel: _cancelDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Gaps.sm),
                AnimatedContainer(
                  duration: motionDuration(
                    Timings.press,
                    disableAnimations: disable,
                  ),
                  curve: LiquidSprings.snappyCurve,
                  width: _dragging ? 46 : 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(
                      alpha: _dragging ? 0.62 : 0.38,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    centeredTitle ? Gaps.md : Gaps.xl,
                    Gaps.md,
                    Gaps.md,
                    Gaps.sm,
                  ),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (centeredTitle) const SizedBox(width: 44),
                        if (centeredTitle)
                          Expanded(child: Center(child: widget.titleWidget))
                        else
                          Expanded(
                            child:
                                widget.titleWidget ??
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    color: colors.text,
                                  ),
                                ),
                          ),
                        ...actions,
                        closeButton,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.footer == null)
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  Gaps.xl,
                  0,
                  Gaps.xl,
                  Gaps.xl + media.padding.bottom,
                ),
                child: widget.child,
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  Gaps.xl,
                  0,
                  Gaps.xl,
                  Gaps.lg,
                ),
                child: widget.child,
              ),
            ),
          if (widget.footer != null)
            DecoratedBox(
              key: const ValueKey('sheet-footer'),
              decoration: BoxDecoration(
                color: colors.card.withValues(
                  alpha: colors.isDark ? 0.34 : 0.42,
                ),
                border: Border(
                  top: BorderSide(
                    color: colors.divider.withValues(alpha: 0.52),
                    width: 0.7,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Gaps.xl,
                  Gaps.sm,
                  Gaps.xl,
                  Gaps.md + media.padding.bottom,
                ),
                child: widget.footer,
              ),
            ),
        ],
      ),
    );
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (!ok || !mounted) return;
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) => Transform.translate(
            offset: offset.abs() <= 0.01 ? Offset.zero : Offset(0, offset),
            child: child,
          ),
          child: RepaintBoundary(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: media.size.height * widget.maxHeightFactor,
              ),
              decoration: ShapeDecoration(
                shape: sheetShape.copyWith(
                  side: BorderSide(
                    color: colors.isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 0.9,
                  ),
                ),
                shadows: context.floatingShadows,
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: sheetShape),
                child: CustomPaint(
                  foregroundPainter: highContrast
                      ? null
                      : LiquidSpecularRimPainter(
                          shape: sheetShape,
                          isDark: colors.isDark,
                          strokeWidth: 1.05,
                        ),
                  child: (highContrast || disable)
                      ? sheetBody
                      : BackdropFilter(
                          filter: _sheetBlurFilter,
                          child: sheetBody,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表单行（标签 + 控件）。
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gaps.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.text2,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Text(
                  hint!,
                  style: TextStyle(fontSize: 11.5, color: colors.text3),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// 快捷档位（工时/金额）。
class QuickChips extends StatelessWidget {
  const QuickChips({
    super.key,
    required this.values,
    required this.onSelect,
    this.suffix,
    this.selected,
    this.labelOf,
  });

  final List<double> values;
  final ValueChanged<double> onSelect;
  final String? suffix;
  final double? selected;
  final String Function(double value)? labelOf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: Gaps.sm,
      runSpacing: Gaps.sm,
      children: [
        for (final value in values)
          Builder(
            builder: (context) {
              final active =
                  selected != null && (selected! - value).abs() < 0.001;
              return Pressable(
                onTap: () => onSelect(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: ShapeDecoration(
                    color: active ? colors.primaryContainer : colors.block,
                    shape: Radii.pillShape,
                  ),
                  child: Text(
                    labelOf?.call(value) ?? '${_trim(value)}${suffix ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active ? colors.onPrimaryContainer : colors.text2,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  String _trim(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
