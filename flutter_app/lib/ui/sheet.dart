/// 底部弹层：圆角 28 顶部、拖拽条、标题栏。
///
/// 关闭语义（修复点）：
/// - 无未保存内容：`canPop = true`，下滑、点遮罩、系统返回键都能直接关闭。
/// - 有未保存内容：`canPop = false`，任何关闭动作都会先弹确认框；确认后才放行。
/// - 不再用「canPop 恒为 false + 手动 maybePop」的写法——那会让 `Navigator.pop()`
///   反过来触发 `onPopInvokedWithResult`，形成永远关不掉的递归。
library;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme_tokens.dart';
import '../platform/back_navigation.dart';
import 'dialog.dart';
import 'widgets.dart';

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
        CurveTween(
          curve: const Interval(0, 0.42, curve: Curves2.out),
        ),
      );
      // drive(CurveTween) 而不是 CurvedAnimation：后者构造时会给 parent
      // 注册 statusListener，在 pageBuilder 里每次重建都留下一个，
      // 直到路由销毁才回收。
      final curved = animation.drive(CurveTween(curve: Curves2.drawer));
      final panelFade = animation.drive(
        CurveTween(curve: const Interval(0, 0.72, curve: Curves2.out)),
      );
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
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(curved),
                // MaterialApp 的 fallback text style 会在缺少 Material 祖先时
                // 给文字加黄色双下划线；弹层必须自己提供一层透明 Material。
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
    this.titleWidget,
    this.guard,
    this.maxHeightFactor = 0.92,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  /// 需要把日期导航等控件嵌进标题时使用；为空时显示 [title]。
  final Widget? titleWidget;

  /// 返回 true 表示「有未保存修改」，此时不关闭并给出提示。
  final bool Function()? guard;
  final double maxHeightFactor;

  @override
  State<SheetScaffold> createState() => _SheetScaffoldState();
}

class _SheetScaffoldState extends State<SheetScaffold> {
  final Object _backToken = Object();

  /// 用户已确认放弃修改，允许本次 pop 通过。
  bool _allowPop = false;
  bool _confirming = false;
  bool _dragging = false;
  double _dragOffset = 0;

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
    setState(() => _dragging = true);
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 220.0);
    });
  }

  void _endDrag(DragEndDetails details) {
    if (!_dragging) return;
    final shouldClose =
        _dragOffset > 84 || details.velocity.pixelsPerSecond.dy > 650;
    setState(() {
      _dragging = false;
      if (!shouldClose) _dragOffset = 0;
    });
    if (shouldClose) _requestClose();
  }

  void _cancelDrag() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final resetDuration = motionDuration(
      const Duration(milliseconds: 180),
      disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
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
        child: AnimatedContainer(
          duration: _dragging ? Duration.zero : resetDuration,
          curve: Curves2.out,
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: media.size.height * widget.maxHeightFactor,
            ),
            decoration: ShapeDecoration(
              color: colors.card,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Radii.alert),
                ),
              ),
              shadows: context.floatingShadows,
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
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.divider,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Gaps.xl,
                          Gaps.md,
                          Gaps.md,
                          Gaps.sm,
                        ),
                        child: Row(
                          children: [
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
                            ...?widget.actions,
                            GlassIconButton(
                              icon: Icons.close_rounded,
                              onTap: _requestClose,
                              tooltip: '关闭',
                              iconSize: 19,
                              size: 44,
                              radius: 22,
                              bright: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      Gaps.xl,
                      0,
                      Gaps.xl,
                      Gaps.xl + media.padding.bottom,
                    ),
                    child: widget.child,
                  ),
                ),
              ],
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
