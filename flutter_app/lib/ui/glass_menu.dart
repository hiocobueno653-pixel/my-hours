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
  double panelWidth = 188,
  bool preferRightAlign = true,
}) {
  if (items.isEmpty) return Future<void>.value();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final media = MediaQuery.of(context);
  final screenSize = overlay != null
      ? (overlay.context.findRenderObject() as RenderBox?)?.size ?? media.size
      : media.size;
  final resolvedAnchor =
      anchorRect ??
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
    return AnimationController.unbounded(vsync: navigator!, value: 0.0);
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    if (disableAnimations) return null;
    if (forward) {
      final spring = LiquidSprings.dropletBloom;
      return SpringSimulation(spring, 0.0, 1.0, 0.45);
    }
    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 520.0,
      ratio: 0.96,
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
    final width = math.min(widget.panelWidth, screen.width - 40);
    final estimatedHeight = _estimateMenuHeight(widget.items)
        .clamp(80.0, screen.height * 0.68);

    final openBelow =
        widget.anchorRect.bottom + 8 + estimatedHeight <= safeBottom ||
        widget.anchorRect.top - 8 - estimatedHeight < safeTop;

    double left = widget.preferRightAlign
        ? widget.anchorRect.right - width
        : widget.anchorRect.left;
    left = left.clamp(14.0, math.max(14.0, screen.width - width - 14.0));

    double top = openBelow
        ? widget.anchorRect.bottom + 6
        : widget.anchorRect.top - 6 - estimatedHeight;
    top = top.clamp(safeTop, math.max(safeTop, safeBottom - estimatedHeight));

    final anchorOnTop = openBelow;
    final anchorOnRight = widget.anchorRect.center.dx >= (left + width * 0.5);
    final beadCenter = Offset(
      anchorOnRight
          ? math.min(left + width - 12, widget.anchorRect.right - 10)
          : math.max(left + 12, widget.anchorRect.left + 10),
      anchorOnTop ? widget.anchorRect.center.dy : widget.anchorRect.center.dy,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          if (!widget.disableAnimations)
            AnimatedBuilder(
              animation: widget.animation,
              builder: (context, _) {
                final t = widget.animation.value.clamp(0.0, 1.0);
                final fadeIn = (t / 0.14).clamp(0.0, 1.0);
                final fadeOut = 1.0 - ((t - 0.54) / 0.34).clamp(0.0, 1.0);
                final beadOpacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
                if (beadOpacity <= 0.01) return const SizedBox.shrink();
                final colors = context.colors;
                final beadScale = lerpDouble(0.75, 1.08, fadeIn)!;
                return Positioned(
                  left: beadCenter.dx - 7,
                  top: beadCenter.dy - 7,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: beadOpacity * (colors.isDark ? 0.65 : 0.78),
                      child: Transform.scale(
                        scale: beadScale,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : const Color(0xFFE2E8F2)
                                      .withValues(alpha: 0.85),
                            border: Border.all(
                              color: colors.isDark
                                  ? Colors.white.withValues(alpha: 0.24)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) {
                final raw = widget.disableAnimations
                    ? 1.0
                    : widget.animation.value;
                final t = raw.clamp(0.0, 1.0);
                final opacity = widget.disableAnimations
                    ? 1.0
                    : (t / 0.22).clamp(0.0, 1.0);
                final pullShift = widget.disableAnimations
                    ? 0.0
                    : (1.0 - Curves.easeOutCubic.transform(t)) *
                          (anchorOnTop ? -18.0 : 18.0);

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, pullShift),
                    child: _DropletMenuSurface(
                      rawProgress: raw,
                      anchorOnTop: anchorOnTop,
                      anchorOnRight: anchorOnRight,
                      disableAnimations: widget.disableAnimations,
                      child: child!,
                    ),
                  ),
                );
              },
              child: RepaintBoundary(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: screen.height * 0.68),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: _buildMenuBody(context),
                  ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Divider(height: 1, thickness: 0.6, color: colors.divider),
            ),
          if (widget.items[i].sectionTitle != null)
            AnimatedOpacity(
              duration: motionDuration(
                Timings.micro,
                disableAnimations: disable,
              ),
              opacity: hasExpanded && _expandedSubmenuIndex != i ? 0.42 : 1.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 3),
                child: Text(
                  widget.items[i].sectionTitle!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
                  _expandedSubmenuIndex = _expandedSubmenuIndex == i ? null : i;
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
    var total = 10.0;
    for (final item in items) {
      if (item.dividerBefore) total += 9;
      if (item.sectionTitle != null) total += 20;
      total += item.subtitle != null ? 50 : 40;
    }
    return total;
  }
}

class _DropletMenuSurface extends StatelessWidget {
  const _DropletMenuSurface({
    required this.rawProgress,
    required this.anchorOnTop,
    required this.anchorOnRight,
    required this.disableAnimations,
    required this.child,
  });

  static final ImageFilter _menuBlur = ImageFilter.blur(sigmaX: 26, sigmaY: 26);

  final double rawProgress;
  final bool anchorOnTop;
  final bool anchorOnRight;
  final bool disableAnimations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.isDark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final surface = isDark
        ? const Color(0xFF1C1E28).withValues(alpha: highContrast ? 1.0 : 0.76)
        : Colors.white.withValues(alpha: highContrast ? 1.0 : 0.76);
    final t = rawProgress.clamp(0.0, 1.0);
    final overshoot = math.max(0.0, rawProgress - 1.0);
    final widthEase = (Curves.easeOutCubic.transform(t) + overshoot * 0.48)
        .clamp(0.0, 1.05);
    final heightEase = (Curves.easeOutQuart.transform(t) + overshoot * 0.72)
        .clamp(0.0, 1.06);
    final contentScaleX = disableAnimations
        ? 1.0
        : lerpDouble(0.56, 1.0, widthEase)!.clamp(0.45, 1.05);
    final contentScaleY = disableAnimations
        ? 1.0
        : lerpDouble(0.52, 1.0, heightEase)!.clamp(0.45, 1.06);
    final contentAlign = Alignment(
      anchorOnRight ? 1.0 : -1.0,
      anchorOnTop ? -1.0 : 1.0,
    );

    final Widget innerContent = disableAnimations || t > 0.988
        ? child
        : Transform(
            alignment: contentAlign,
            transform: Matrix4.diagonal3Values(
              contentScaleX,
              contentScaleY,
              1.0,
            ),
            child: child,
          );
    final surfaceBody = ColoredBox(color: surface, child: innerContent);

    return CustomPaint(
      painter: _LiquidDropletShadowPainter(
        rawProgress: rawProgress,
        anchorOnTop: anchorOnTop,
        anchorOnRight: anchorOnRight,
        isDark: isDark,
        disableAnimations: disableAnimations,
      ),
      foregroundPainter: _LiquidDropletRimPainter(
        rawProgress: rawProgress,
        anchorOnTop: anchorOnTop,
        anchorOnRight: anchorOnRight,
        isDark: isDark,
        disableAnimations: disableAnimations,
      ),
      child: ClipPath(
        clipper: _LiquidDropletClipper(
          rawProgress: rawProgress,
          anchorOnTop: anchorOnTop,
          anchorOnRight: anchorOnRight,
          disableAnimations: disableAnimations,
        ),
        child: highContrast || disableAnimations
            ? surfaceBody
            : BackdropFilter(filter: _menuBlur, child: surfaceBody),
      ),
    );
  }
}

/// 液态水滴三段形态路径生成器：
/// 1) 触点水滴拉出（锚点角尖收、对角水腹圆润鼓胀）；
/// 2) 脱离触点后的饱满椭圆水珠；
/// 3) 弹簧回弹定型为连续曲率超椭圆玻璃卡片。
Path buildLiquidDropletPath(
  Size size, {
  required double rawProgress,
  required bool anchorOnTop,
  required bool anchorOnRight,
  required bool disableAnimations,
}) {
  final width = size.width;
  final height = size.height;
  if (width <= 0 || height <= 0) return Path();
  if (disableAnimations || (rawProgress - 1.0).abs() < 0.001) {
    return Path()..addRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(22),
      ),
    );
  }

  final t = rawProgress.clamp(0.0, 1.0);
  final overshoot = math.max(0.0, rawProgress - 1.0);
  final widthEase = (Curves.easeOutCubic.transform(t) + overshoot * 0.48).clamp(
    0.0,
    1.05,
  );
  final heightEase = (Curves.easeOutQuart.transform(t) + overshoot * 0.72)
      .clamp(0.0, 1.06);

  final startW = math.min(width * 0.34, 58.0);
  final startH = math.min(height * 0.24, 42.0);
  final curW = lerpDouble(startW, width, widthEase)!.clamp(24.0, width * 1.06);
  final curH = lerpDouble(
    startH,
    height,
    heightEase,
  )!.clamp(24.0, height * 1.06);

  final rectLeft = anchorOnRight ? (width - curW) : 0.0;
  final rectTop = anchorOnTop ? 0.0 : (height - curH);
  final rect = Rect.fromLTWH(rectLeft, rectTop, curW, curH);

  final teardrop = math.sin(((t - 0.02) / 0.62).clamp(0.0, 1.0) * math.pi);
  final ovalness =
      1.0 -
      Curves.easeInOutCubic.transform(((t - 0.30) / 0.64).clamp(0.0, 1.0));

  final minDim = math.min(curW, curH);
  final finalR = math.min(22.0, minDim * 0.44);
  final maxR = minDim * 0.495;

  final bellyR = lerpDouble(finalR, maxR, ovalness)!;
  final sideR = lerpDouble(finalR, maxR * 0.94, ovalness)!;
  final baseAnchorR = lerpDouble(finalR, maxR * 0.86, ovalness)!;
  final pinchR = math.min(minDim * 0.11, 14.0);
  final anchorR = lerpDouble(baseAnchorR, pinchR, teardrop * 0.94)!;

  double rTL;
  double rTR;
  double rBR;
  double rBL;
  if (anchorOnTop && anchorOnRight) {
    rTR = anchorR;
    rBL = bellyR;
    rTL = sideR;
    rBR = sideR;
  } else if (anchorOnTop && !anchorOnRight) {
    rTL = anchorR;
    rBR = bellyR;
    rTR = sideR;
    rBL = sideR;
  } else if (!anchorOnTop && anchorOnRight) {
    rBR = anchorR;
    rTL = bellyR;
    rTR = sideR;
    rBL = sideR;
  } else {
    rBL = anchorR;
    rTR = bellyR;
    rTL = sideR;
    rBR = sideR;
  }

  // 防止相邻圆角之和超出边长导致路径自交。
  double scale = 1.0;
  if (rTL + rTR > curW) scale = math.min(scale, curW / (rTL + rTR));
  if (rBL + rBR > curW) scale = math.min(scale, curW / (rBL + rBR));
  if (rTL + rBL > curH) scale = math.min(scale, curH / (rTL + rBL));
  if (rTR + rBR > curH) scale = math.min(scale, curH / (rTR + rBR));
  if (scale < 1.0) {
    rTL *= scale;
    rTR *= scale;
    rBR *= scale;
    rBL *= scale;
  }

  // 液体球润到超椭圆平滑过渡的贝塞尔控制柄系数。
  final k = lerpDouble(0.61, 0.55228, ovalness)!;
  final neckStretch = teardrop * 0.08 * minDim;
  final l = rect.left;
  final r = rect.right;
  final top = rect.top;
  final b = rect.bottom;

  // 锚点角处沿两条邻边轻微收束，形成真实水滴颈弧。
  final trTipX = (anchorOnTop && anchorOnRight) ? r : r;
  final trTipY = (anchorOnTop && anchorOnRight) ? top : top;
  final topPull = (anchorOnTop && anchorOnRight) ? neckStretch : 0.0;
  final topLeftPull = (anchorOnTop && !anchorOnRight) ? neckStretch : 0.0;
  final botRightPull = (!anchorOnTop && anchorOnRight) ? neckStretch : 0.0;
  final botLeftPull = (!anchorOnTop && !anchorOnRight) ? neckStretch : 0.0;

  final path = Path()
    ..moveTo(l + rTL, top)
    // 顶边 -> 右上角
    ..lineTo(trTipX - rTR, trTipY)
    ..cubicTo(
      trTipX - rTR + rTR * k + topPull * 0.15,
      trTipY,
      trTipX,
      trTipY + rTR - rTR * k - topPull * 0.15,
      trTipX,
      trTipY + rTR,
    )
    // 右边 -> 右下角
    ..lineTo(r, b - rBR)
    ..cubicTo(
      r,
      b - rBR + rBR * k + botRightPull * 0.15,
      r - rBR + rBR * k + botRightPull * 0.15,
      b,
      r - rBR,
      b,
    )
    // 底边 -> 左下角
    ..lineTo(l + rBL, b)
    ..cubicTo(
      l + rBL - rBL * k - botLeftPull * 0.15,
      b,
      l,
      b - rBL + rBL * k + botLeftPull * 0.15,
      l,
      b - rBL,
    )
    // 左边 -> 左上角
    ..lineTo(l, top + rTL)
    ..cubicTo(
      l,
      top + rTL - rTL * k - topLeftPull * 0.15,
      l + rTL - rTL * k - topLeftPull * 0.15,
      top,
      l + rTL,
      top,
    )
    ..close();
  return path;
}

class _LiquidDropletClipper extends CustomClipper<Path> {
  const _LiquidDropletClipper({
    required this.rawProgress,
    required this.anchorOnTop,
    required this.anchorOnRight,
    required this.disableAnimations,
  });

  final double rawProgress;
  final bool anchorOnTop;
  final bool anchorOnRight;
  final bool disableAnimations;

  @override
  Path getClip(Size size) => buildLiquidDropletPath(
    size,
    rawProgress: rawProgress,
    anchorOnTop: anchorOnTop,
    anchorOnRight: anchorOnRight,
    disableAnimations: disableAnimations,
  );

  @override
  bool shouldReclip(_LiquidDropletClipper old) =>
      old.rawProgress != rawProgress ||
      old.anchorOnTop != anchorOnTop ||
      old.anchorOnRight != anchorOnRight ||
      old.disableAnimations != disableAnimations;
}

class _LiquidDropletShadowPainter extends CustomPainter {
  const _LiquidDropletShadowPainter({
    required this.rawProgress,
    required this.anchorOnTop,
    required this.anchorOnRight,
    required this.isDark,
    required this.disableAnimations,
  });

  final double rawProgress;
  final bool anchorOnTop;
  final bool anchorOnRight;
  final bool isDark;
  final bool disableAnimations;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildLiquidDropletPath(
      size,
      rawProgress: rawProgress,
      anchorOnTop: anchorOnTop,
      anchorOnRight: anchorOnRight,
      disableAnimations: disableAnimations,
    );
    final alphaScale = disableAnimations ? 1.0 : rawProgress.clamp(0.0, 1.0);
    canvas.drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0xFF0F172A)
            .withValues(alpha: (isDark ? 0.42 : 0.11) * alphaScale)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(_LiquidDropletShadowPainter old) =>
      old.rawProgress != rawProgress ||
      old.isDark != isDark ||
      old.anchorOnTop != anchorOnTop ||
      old.anchorOnRight != anchorOnRight;
}

class _LiquidDropletRimPainter extends CustomPainter {
  const _LiquidDropletRimPainter({
    required this.rawProgress,
    required this.anchorOnTop,
    required this.anchorOnRight,
    required this.isDark,
    required this.disableAnimations,
  });

  final double rawProgress;
  final bool anchorOnTop;
  final bool anchorOnRight;
  final bool isDark;
  final bool disableAnimations;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildLiquidDropletPath(
      size,
      rawProgress: rawProgress,
      anchorOnTop: anchorOnTop,
      anchorOnRight: anchorOnRight,
      disableAnimations: disableAnimations,
    );
    final rect = Offset.zero & size;
    final rimShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.12),
            ]
          : [
              Colors.white.withValues(alpha: 0.92),
              const Color(0xFF0F172A).withValues(alpha: 0.08),
              const Color(0xFF0F172A).withValues(alpha: 0.05),
            ],
    ).createShader(rect);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05
        ..shader = rimShader,
    );
  }

  @override
  bool shouldRepaint(_LiquidDropletRimPainter old) =>
      old.rawProgress != rawProgress ||
      old.isDark != isDark ||
      old.anchorOnTop != anchorOnTop ||
      old.anchorOnRight != anchorOnRight;
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
    final iconColor = action.danger
        ? colors.expense
        : action.selected
        ? colors.primary
        : colors.text2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      child: Pressable(
        onTap: onTap,
        shape: Radii.shape(10),
        pressedScale: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 37),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, size: 17, color: iconColor),
                const SizedBox(width: 9),
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
                        fontSize: 13.5,
                        fontWeight: action.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (action.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        action.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.text3),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingOverride != null)
                trailingOverride!
              else if (action.selected)
                Icon(Icons.check_rounded, size: 16, color: colors.primary),
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
                color: colors.isDark ? colors.block : colors.page,
                shape: Radii.shape(12).copyWith(
                  side: BorderSide(
                    color: colors.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFF0F172A).withValues(alpha: 0.05),
                  ),
                ),
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
    final rect = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
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
    this.icon = Icons.more_horiz_rounded,
    this.tooltip = '更多操作',
    this.panelWidth = 188,
    this.clustered = false,
  });

  final List<GlassMenuAction> items;
  final IconData icon;
  final String tooltip;
  final double panelWidth;
  final bool clustered;

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final rect = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
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
      builder: (anchorContext) => clustered
          ? GlassGroupIconAction(
              icon: icon,
              tooltip: tooltip,
              onTap: () => _open(anchorContext),
            )
          : GlassIconButton(
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
    this.panelWidth = 188,
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

class _LiquidContextMenuRegionState extends State<LiquidContextMenuRegion>
    with SingleTickerProviderStateMixin {
  static const Animation<double> _fullHighlight =
      AlwaysStoppedAnimation<double>(1.0);

  bool _highlighted = false;
  AnimationController? _controller;
  CurvedAnimation? _curved;

  AnimationController _ensureController() {
    final existing = _controller;
    if (existing != null) return existing;
    final controller = AnimationController(vsync: this, duration: Timings.micro)
      ..addStatusListener(_handleStatus);
    _curved = CurvedAnimation(parent: controller, curve: Curves2.soft);
    _controller = controller;
    return controller;
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_highlighted && mounted) {
      setState(() {});
    }
  }

  void _setHighlighted(bool next) {
    if (_highlighted == next) return;
    _highlighted = next;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      if (mounted) setState(() {});
      return;
    }
    final controller = _ensureController();
    if (next) {
      controller.forward();
      if (mounted) setState(() {});
    } else {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleLongPress(LongPressStartDetails details) async {
    final items = widget.itemsBuilder();
    if (items.isEmpty) return;
    unawaited(HapticFeedback.mediumImpact());
    _setHighlighted(true);
    try {
      await showDropletGlassMenu(
        context,
        anchorOffset: details.globalPosition,
        panelWidth: widget.panelWidth,
        preferRightAlign:
            details.globalPosition.dx > MediaQuery.sizeOf(context).width * 0.45,
        items: items,
      );
    } finally {
      if (mounted) _setHighlighted(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final showHighlight =
        _highlighted ||
        (!disable && _controller != null && _controller!.value > 0);
    return GestureDetector(
      onLongPressStart: _handleLongPress,
      child: CustomPaint(
        foregroundPainter: showHighlight
            ? _ContextHighlightPainter(
                shape: Radii.shape(widget.highlightRadius),
                color: colors.text,
                maxAlpha: colors.isDark ? 0.14 : 0.08,
                progress: disable || _curved == null
                    ? _fullHighlight
                    : _curved!,
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

class _ContextHighlightPainter extends CustomPainter {
  _ContextHighlightPainter({
    required this.shape,
    required this.color,
    required this.maxAlpha,
    required this.progress,
  }) : super(repaint: progress);

  final ShapeBorder shape;
  final Color color;
  final double maxAlpha;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (maxAlpha * progress.value).clamp(0.0, 1.0);
    if (alpha <= 0.001) return;
    canvas.drawPath(
      shape.getOuterPath(Offset.zero & size),
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_ContextHighlightPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.maxAlpha != maxAlpha ||
      old.progress != progress;
}
