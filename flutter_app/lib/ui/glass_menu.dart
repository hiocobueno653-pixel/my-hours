/// FlClash 风格液态水滴形变玻璃菜单：
/// - 从点击锚点或长按指尖位置以水滴形态弹性展开，带瞬时模糊过渡与超椭圆高光玻璃描边；
/// - 支持分组小标题、勾选态、破坏性红项；
/// - 支持二级折叠子菜单（展开时主菜单轻缩退后，子菜单以独立液态玻璃卡片叠加展开）。
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import '../core/theme_tokens.dart';
import 'widgets.dart';

/// 液态玻璃菜单项：既兼容扁平动作，也支持分组标题与二级折叠子菜单。
class GlassMenuAction {
  const GlassMenuAction({
    required this.label,
    this.onSelected,
    this.icon,
    this.subtitle,
    this.danger = false,
    this.selected = false,
    this.dividerBefore = false,
    this.sectionTitle,
    this.children,
  });

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;
  final String? subtitle;
  final bool danger;
  final bool selected;
  final bool dividerBefore;
  final String? sectionTitle;
  final List<GlassMenuAction>? children;

  bool get isSubmenu => children != null && children!.isNotEmpty;
}

/// 从指定锚点矩形或触控坐标，以 FlClash 液态水滴形变动画展开玻璃菜单。
Future<void> showDropletGlassMenu(
  BuildContext context, {
  required List<GlassMenuAction> items,
  Rect? anchorRect,
  Offset? anchorOffset,
  double panelWidth = 228,
  bool preferRightAlign = true,
}) {
  if (items.isEmpty) return Future<void>.value();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final media = MediaQuery.of(context);
  final screenSize = overlay != null
      ? (overlay.context.findRenderObject() as RenderBox?)?.size ?? media.size
      : media.size;
  final resolvedAnchor = anchorRect ??
      (anchorOffset != null
          ? Rect.fromCenter(center: anchorOffset, width: 32, height: 32)
          : Rect.fromCenter(
              center: Offset(screenSize.width - 40, media.padding.top + 48),
              width: 42,
              height: 42,
            ));
  final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  return Navigator.of(context, rootNavigator: true).push<void>(
    _DropletGlassMenuRoute(
      items: items,
      anchorRect: resolvedAnchor,
      panelWidth: panelWidth,
      preferRightAlign: preferRightAlign,
      disableAnimations: disable,
    ),
  );
}

class _DropletGlassMenuRoute extends PopupRoute<void> {
  _DropletGlassMenuRoute({
    required this.items,
    required this.anchorRect,
    required this.panelWidth,
    required this.preferRightAlign,
    required this.disableAnimations,
  });

  final List<GlassMenuAction> items;
  final Rect anchorRect;
  final double panelWidth;
  final bool preferRightAlign;
  final bool disableAnimations;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '关闭菜单';

  @override
  Duration get transitionDuration =>
      motionDuration(Timings.panel, disableAnimations: disableAnimations);

  @override
  Duration get reverseTransitionDuration =>
      motionDuration(Timings.fast, disableAnimations: disableAnimations);

  @override
  AnimationController createAnimationController() {
    if (disableAnimations) {
      return AnimationController(
        vsync: navigator!,
        duration: Duration.zero,
        reverseDuration: Duration.zero,
      );
    }
    return AnimationController.unbounded(
      vsync: navigator!,
      value: 0.0,
    );
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    if (disableAnimations) return null;
    if (forward) {
      final spring = SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: 410.0,
        ratio: 0.78,
      );
      return SpringSimulation(spring, 0.0, 1.0, 0.4);
    }
    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 620.0,
      ratio: 1.0,
    );
    return SpringSimulation(spring, controller!.value, 0.0, 0.0);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _DropletGlassMenuOverlay(
      animation: animation,
      items: items,
      anchorRect: anchorRect,
      panelWidth: panelWidth,
      preferRightAlign: preferRightAlign,
      disableAnimations: disableAnimations,
    );
  }
}

class _DropletGlassMenuOverlay extends StatefulWidget {
  const _DropletGlassMenuOverlay({
    required this.animation,
    required this.items,
    required this.anchorRect,
    required this.panelWidth,
    required this.preferRightAlign,
    required this.disableAnimations,
  });

  final Animation<double> animation;
  final List<GlassMenuAction> items;
  final Rect anchorRect;
  final double panelWidth;
  final bool preferRightAlign;
  final bool disableAnimations;

  @override
  State<_DropletGlassMenuOverlay> createState() =>
      _DropletGlassMenuOverlayState();
}

class _DropletGlassMenuOverlayState extends State<_DropletGlassMenuOverlay> {
  int? _expandedSubmenuIndex;

  void _selectAction(GlassMenuAction action) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    action.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safeTop = media.padding.top + 12;
    final safeBottom = screen.height - media.padding.bottom - 20;
    final width = math.min(widget.panelWidth, screen.width - 28);
    final estimatedHeight = _estimateMenuHeight(widget.items).clamp(80.0, screen.height * 0.68);

    final openBelow =
        widget.anchorRect.bottom + 8 + estimatedHeight <= safeBottom ||
        widget.anchorRect.top - 8 - estimatedHeight < safeTop;

    double left = widget.preferRightAlign
        ? widget.anchorRect.right - width
        : widget.anchorRect.left;
    left = left.clamp(14.0, math.max(14.0, screen.width - width - 14.0));

    double top = openBelow
        ? widget.anchorRect.bottom + 8
        : widget.anchorRect.top - 8 - estimatedHeight;
    top = top.clamp(safeTop, math.max(safeTop, safeBottom - estimatedHeight));

    // 生长支点对准锚点在菜单局部坐标系里的相对位置，形成液滴从按钮/指尖流出的效果。
    final alignX = (((widget.anchorRect.center.dx - left) / width) * 2 - 1)
        .clamp(-0.92, 0.92);
    final alignY = openBelow ? -0.92 : 0.92;
    final scaleAlignment = Alignment(alignX, alignY);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) {
                final raw = widget.animation.value;
                final t = raw.clamp(0.0, 1.0);
                final scale = widget.disableAnimations
                    ? 1.0
                    : (0.28 + 0.72 * raw).clamp(0.24, 1.045);
                final opacity = widget.disableAnimations
                    ? 1.0
                    : (t / 0.45).clamp(0.0, 1.0);
                final morphRadius = widget.disableAnimations
                    ? 28.0
                    : lerpDouble(width * 0.46, 28.0, Curves2.out.transform(t))!;
                final contentBlur = widget.disableAnimations
                    ? 0.0
                    : (1.0 - (t / 0.72).clamp(0.0, 1.0)) * 5.5;

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    alignment: scaleAlignment,
                    child: _DropletMenuSurface(
                      radius: morphRadius,
                      contentBlur: contentBlur,
                      child: child!,
                    ),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screen.height * 0.68),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildMenuBody(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBody(BuildContext context) {
    final colors = context.colors;
    final hasExpanded = _expandedSubmenuIndex != null;
    final disable = widget.disableAnimations;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.items.length; i++) ...[
          if (widget.items[i].dividerBefore && i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Divider(
                height: 1,
                thickness: 0.7,
                color: colors.text.withValues(alpha: colors.isDark ? 0.12 : 0.08),
              ),
            ),
          if (widget.items[i].sectionTitle != null)
            AnimatedOpacity(
              duration: motionDuration(
                Timings.micro,
                disableAnimations: disable,
              ),
              opacity: hasExpanded && _expandedSubmenuIndex != i ? 0.42 : 1.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                child: Text(
                  widget.items[i].sectionTitle!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text3,
                  ),
                ),
              ),
            ),
          if (widget.items[i].isSubmenu)
            _AccordionSubmenuItem(
              action: widget.items[i],
              expanded: _expandedSubmenuIndex == i,
              dimmed: hasExpanded && _expandedSubmenuIndex != i,
              disableAnimations: disable,
              onToggle: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _expandedSubmenuIndex =
                      _expandedSubmenuIndex == i ? null : i;
                });
              },
              onSelectChild: _selectAction,
            )
          else
            AnimatedOpacity(
              duration: motionDuration(
                Timings.micro,
                disableAnimations: disable,
              ),
              opacity: hasExpanded ? 0.42 : 1.0,
              child: AnimatedScale(
                duration: motionDuration(
                  Timings.fast,
                  disableAnimations: disable,
                ),
                curve: Curves2.out,
                scale: hasExpanded ? 0.96 : 1.0,
                child: _GlassMenuRow(
                  action: widget.items[i],
                  onTap: () => _selectAction(widget.items[i]),
                ),
              ),
            ),
        ],
      ],
    );
  }

  double _estimateMenuHeight(List<GlassMenuAction> items) {
    var total = 16.0;
    for (final item in items) {
      if (item.dividerBefore) total += 13;
      if (item.sectionTitle != null) total += 24;
      total += item.subtitle != null ? 56 : 46;
    }
    return total;
  }
}

class _DropletMenuSurface extends StatelessWidget {
  const _DropletMenuSurface({
    required this.radius,
    required this.contentBlur,
    required this.child,
  });

  final double radius;
  final double contentBlur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.isDark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final shape = Radii.shape(radius);
    final bgTop = isDark
        ? const Color(0xFF2B2D36).withValues(alpha: highContrast ? 1.0 : 0.80)
        : Colors.white.withValues(alpha: highContrast ? 1.0 : 0.84);
    final bgBottom = isDark
        ? const Color(0xFF1E2028).withValues(alpha: highContrast ? 1.0 : 0.76)
        : const Color(0xFFF6F7FC).withValues(alpha: highContrast ? 1.0 : 0.78);
    final rim = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.94);
    final outer = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    final innerContent = contentBlur > 0.25
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: contentBlur,
              sigmaY: contentBlur,
            ),
            child: child,
          )
        : child;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape.copyWith(side: BorderSide(color: outer, width: 0.8)),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.46 : 0.14),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: highContrast ? 0 : 24,
            sigmaY: highContrast ? 0 : 24,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgTop, bgBottom],
              ),
              shape: shape.copyWith(side: BorderSide(color: rim, width: 1.2)),
            ),
            child: innerContent,
          ),
        ),
      ),
    );
  }
}

class _GlassMenuRow extends StatelessWidget {
  const _GlassMenuRow({
    required this.action,
    required this.onTap,
    this.trailingOverride,
  });

  final GlassMenuAction action;
  final VoidCallback onTap;
  final Widget? trailingOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = action.danger
        ? colors.expense
        : action.selected
        ? colors.primary
        : colors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Pressable(
        onTap: onTap,
        shape: Radii.shape(16),
        pressedScale: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, size: 20, color: fg),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (action.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        action.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.text3),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingOverride != null)
                trailingOverride!
              else if (action.selected)
                Icon(Icons.check_rounded, size: 19, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// FlClash 二级折叠子菜单卡：展开时以独立亮面玻璃卡片叠加，箭头旋转为向下。
class _AccordionSubmenuItem extends StatelessWidget {
  const _AccordionSubmenuItem({
    required this.action,
    required this.expanded,
    required this.dimmed,
    required this.disableAnimations,
    required this.onToggle,
    required this.onSelectChild,
  });

  final GlassMenuAction action;
  final bool expanded;
  final bool dimmed;
  final bool disableAnimations;
  final VoidCallback onToggle;
  final ValueChanged<GlassMenuAction> onSelectChild;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = motionDuration(
      Timings.base,
      disableAnimations: disableAnimations,
    );

    return AnimatedOpacity(
      duration: duration,
      opacity: dimmed ? 0.42 : 1.0,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves2.out,
        margin: expanded
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
            : EdgeInsets.zero,
        decoration: expanded
            ? ShapeDecoration(
                color: colors.isDark
                    ? const Color(0xFF313440).withValues(alpha: 0.94)
                    : Colors.white.withValues(alpha: 0.96),
                shape: Radii.shape(22).copyWith(
                  side: BorderSide(
                    color: colors.isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: colors.isDark ? 0.36 : 0.10,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GlassMenuRow(
              action: action,
              onTap: onToggle,
              trailingOverride: AnimatedRotation(
                turns: expanded ? 0.25 : 0.0,
                duration: duration,
                curve: Curves2.out,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: colors.text3,
                ),
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: Curves2.out,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            child: Divider(
                              height: 1,
                              thickness: 0.7,
                              color: colors.divider,
                            ),
                          ),
                          for (final child in action.children!) ...[
                            if (child.sectionTitle != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  4,
                                  18,
                                  2,
                                ),
                                child: Text(
                                  child.sectionTitle!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text3,
                                  ),
                                ),
                              ),
                            _GlassMenuRow(
                              action: child,
                              onTap: () => onSelectChild(child),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单选项液态水滴下拉菜单（如主题页的配色风格 `鲜明 ⇕`）。
class GlassSelectMenu<T> extends StatelessWidget {
  const GlassSelectMenu({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.panelWidth = 176,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final double panelWidth;

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final rect = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    HapticFeedback.selectionClick();
    unawaited(
      showDropletGlassMenu(
        context,
        anchorRect: rect,
        panelWidth: panelWidth,
        preferRightAlign: true,
        items: [
          for (final value in values)
            GlassMenuAction(
              label: labelOf(value),
              selected: value == selected,
              onSelected: () => onChanged(value),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Builder(
      builder: (anchorContext) => Semantics(
        button: true,
        label: '${labelOf(selected)}，展开选项',
        onTap: () => _open(anchorContext),
        excludeSemantics: true,
        child: Pressable(
          onTap: () => _open(anchorContext),
          shape: Radii.pillShape,
          pressedScale: 0.95,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labelOf(selected),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.text2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more_rounded, size: 16, color: colors.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶栏悬浮圆形液态玻璃菜单按钮：点击以水滴形变展开玻璃菜单。
class GlassMenuButton extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.items,
    this.icon = Icons.more_vert_rounded,
    this.tooltip = '更多操作',
    this.panelWidth = 228,
  });

  final List<GlassMenuAction> items;
  final IconData icon;
  final String tooltip;
  final double panelWidth;

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final rect = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    HapticFeedback.selectionClick();
    unawaited(
      showDropletGlassMenu(
        context,
        anchorRect: rect,
        panelWidth: panelWidth,
        preferRightAlign: true,
        items: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) => GlassIconButton(
        icon: icon,
        tooltip: tooltip,
        onTap: () => _open(anchorContext),
      ),
    );
  }
}

/// 长按任意列表项/卡片，从手指触控坐标直接以液态水滴形态绽放上下文菜单（对应 FlClash 长按卡片交互）。
class LiquidContextMenuRegion extends StatefulWidget {
  const LiquidContextMenuRegion({
    super.key,
    required this.itemsBuilder,
    required this.child,
    this.panelWidth = 208,
    this.highlightRadius = Radii.card,
  });

  final List<GlassMenuAction> Function() itemsBuilder;
  final Widget child;
  final double panelWidth;
  final double highlightRadius;

  @override
  State<LiquidContextMenuRegion> createState() =>
      _LiquidContextMenuRegionState();
}

class _LiquidContextMenuRegionState extends State<LiquidContextMenuRegion> {
  bool _highlighted = false;

  Future<void> _handleLongPress(LongPressStartDetails details) async {
    final items = widget.itemsBuilder();
    if (items.isEmpty) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _highlighted = true);
    try {
      await showDropletGlassMenu(
        context,
        anchorOffset: details.globalPosition,
        panelWidth: widget.panelWidth,
        preferRightAlign: details.globalPosition.dx >
            MediaQuery.sizeOf(context).width * 0.45,
        items: items,
      );
    } finally {
      if (mounted) setState(() => _highlighted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = Radii.shape(widget.highlightRadius);
    return GestureDetector(
      onLongPressStart: _handleLongPress,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: motionDuration(
                  Timings.micro,
                  disableAnimations:
                      MediaQuery.maybeDisableAnimationsOf(context) ?? false,
                ),
                curve: Curves2.soft,
                opacity: _highlighted ? 1.0 : 0.0,
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: shape),
                  child: ColoredBox(
                    color: colors.text.withValues(alpha: colors.isDark ? 0.14 : 0.08),
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
