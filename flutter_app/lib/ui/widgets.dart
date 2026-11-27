/// 基础 UI 原语：液态玻璃表面、卡片、按压面、按钮、列表行、分段控件、开关、空态与数字输入。
///
/// FlClash 液态玻璃体系：内容卡依靠大连续圆角与面差呼吸；顶栏、浮钮、弹窗与菜单
/// 采用真实毛玻璃/液态折射 + 镜面高光描边 + 轻悬浮投影。
library;

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/motion.dart';
import '../core/motion_origin.dart';
import '../core/theme_tokens.dart';
import '../data/dates.dart';

/// 内容卡：实心表面 + 1px 细描边，默认克制轻阴影。
/// 在页面树内共享主内容层的 [Backdrop]，让悬浮顶栏、胶囊按钮、开关与菜单
/// 可以直接采样背后的滚动内容做真实折射；独立路由或测试中自动回退到 [nativeBackdrop]。
class AppBackdropScope extends InheritedWidget {
  const AppBackdropScope({
    super.key,
    required this.backdrop,
    required super.child,
  });

  final Backdrop backdrop;

  static Backdrop of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppBackdropScope>()
            ?.backdrop ??
        nativeBackdrop;
  }

  @override
  bool updateShouldNotify(AppBackdropScope oldWidget) =>
      oldWidget.backdrop != backdrop;
}

/// 通用液态玻璃浮层表面：用于顶栏岛、胶囊按钮、悬浮工具条和独立浮标。
///
/// 极致档位且提供可采样 [LayerBackdrop] 时走 `fluid_glass` 真实折射着色器；
/// 其余环境使用高透 `BackdropFilter` + 定向镜面高光描边 + 悬浮软投影。
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = Radii.pill,
    this.padding = EdgeInsets.zero,
    this.height,
    this.width,
    this.selected = false,
    this.bright = true,
    this.blurSigma = 12,
    this.tintColor,
    this.refract = true,
    this.showShadow = true,
  });

  static final Map<double, ImageFilter> _blurCache = <double, ImageFilter>{};

  static ImageFilter _blurFilter(double sigma) {
    final quantized = (sigma * 2).round() / 2;
    return _blurCache.putIfAbsent(
      quantized,
      () => ImageFilter.blur(sigmaX: quantized, sigmaY: quantized),
    );
  }

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double? width;
  final bool selected;
  final bool bright;
  final double blurSigma;
  final Color? tintColor;
  final bool refract;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.maybeOf(context);
    final highContrast = media?.highContrast ?? false;
    final reduceEffects = media?.disableAnimations ?? false;
    final quality =
        GlassQualityScope.maybeOf(context) ?? GlassDeviceTier.instance.quality;
    final backdrop = AppBackdropScope.of(context);
    final useLiquidShader =
        refract &&
        !highContrast &&
        !reduceEffects &&
        quality == GlassQuality.liquid &&
        backdrop != nativeBackdrop;

    final baseFill =
        tintColor ??
        (selected
            ? colors.primaryContainer.withValues(
                alpha: colors.isDark ? 0.88 : 0.94,
              )
            : colors.isDark
            ? Color.lerp(
                colors.card,
                Colors.white,
                bright ? 0.05 : 0.02,
              )!.withValues(alpha: highContrast ? 1.0 : (bright ? 0.88 : 0.80))
            : colors.card.withValues(
                alpha: highContrast ? 1.0 : (bright ? 0.92 : 0.86),
              ));

    final outerBorder = selected
        ? colors.primary.withValues(alpha: 0.30)
        : colors.isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFF1C160C).withValues(alpha: bright ? 0.075 : 0.085);

    final shape = radius >= Radii.pill ? Radii.pillShape : Radii.shape(radius);

    final shadows = !showShadow
        ? null
        : <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF141519)
                  .withValues(alpha: colors.isDark ? 0.24 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: const Color(0xFF141519)
                  .withValues(alpha: colors.isDark ? 0.14 : 0.03),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
            ),
          ];

    Widget inner = Padding(padding: padding, child: child);
    if (height != null || width != null) {
      inner = SizedBox(width: width, height: height, child: inner);
    }

    if (useLiquidShader) {
      final glassShape = radius >= Radii.pill
          ? const Capsule()
          : RoundedRectangle(radius);
      return DrawBackdrop(
        backdrop: backdrop,
        shape: () => glassShape,
        effects: (scope) => scope
          ..vibrancy()
          ..blur(blurSigma * 0.45)
          ..lens(10, 18),
        highlight: () => Highlight.standard,
        shadow: showShadow ? () => GlassShadow.standard : null,
        onDrawSurface: (canvas, size) {
          canvas.drawRect(Offset.zero & size, Paint()..color = baseFill);
        },
        isolateSurface: false,
        child: inner,
      );
    }

    final sigma = (highContrast || reduceEffects) ? 0.0 : blurSigma;
    final surface = DecoratedBox(
      decoration: ShapeDecoration(color: baseFill, shape: shape),
      child: inner,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape.copyWith(
          side: BorderSide(color: outerBorder, width: 0.75),
        ),
        shadows: shadows,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: sigma <= 0.1
            ? surface
            : BackdropFilter(filter: _blurFilter(sigma), child: surface),
      ),
    );
  }
}

/// 内容卡：FlClash 纯净大连续圆角表面，默认无重描边，依靠面差与轻投影分层。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.radius = Radii.card,
    this.onTap,
    this.margin,
    this.bordered = false,
    this.flat = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool bordered;
  final bool flat;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = Radii.shape(radius);
    final pureBlack = colors.isDark && colors.page.toARGB32() == 0xFF000000;
    final borderColor = bordered
        ? colors.cardBorder
        : pureBlack
        ? Colors.white.withValues(alpha: 0.10)
        : colors.isDark
        ? Colors.white.withValues(alpha: 0.075)
        : colors.cardBorder.withValues(alpha: 0.72);
    final shape = base.copyWith(
      side: BorderSide(color: borderColor, width: bordered ? 0.9 : 0.75),
    );
    final content = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: color ?? colors.card,
        shape: shape,
        shadows: flat ? null : context.shadows,
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

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  static const Animation<double> _identityScale =
      AlwaysStoppedAnimation<double>(1.0);
  static const Animation<double> _fullOverlay = AlwaysStoppedAnimation<double>(
    1.0,
  );

  bool _pressed = false;
  bool _disableAnimations = false;
  Timer? _pressDelay;
  AnimationController? _controller;
  CurvedAnimation? _curved;
  Animation<double>? _scaleAnimation;

  bool get _usesScale => widget.pressedScale != 1;

  AnimationController _ensureController() {
    final existing = _controller;
    if (existing != null) return existing;
    final controller = AnimationController(
      vsync: this,
      duration: _usesScale ? Timings.press : Timings.fast,
    )..addStatusListener(_handleAnimationStatus);
    _controller = controller;
    _rebuildCurves();
    return controller;
  }

  void _rebuildCurves() {
    final controller = _controller;
    if (controller == null) return;
    controller.duration = _usesScale ? Timings.press : Timings.fast;
    _curved?.dispose();
    if (_usesScale) {
      _curved = CurvedAnimation(parent: controller, curve: Curves2.out);
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.pressedScale,
      ).animate(_curved!);
    } else {
      _curved = null;
      _scaleAnimation = null;
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_pressed && mounted) {
      setState(() {});
    }
  }

  void _setPressed(bool next) {
    if (_pressed == next) return;
    _pressed = next;
    if (_disableAnimations) {
      if (mounted) setState(() {});
      return;
    }
    final firstCreate = _controller == null;
    final controller = _ensureController();
    if (next) {
      controller.forward();
      if ((firstCreate || !_usesScale) && mounted) {
        setState(() {});
      }
    } else {
      controller.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_disableAnimations && _controller != null && _controller!.isAnimating) {
      _controller!.value = _pressed ? 1.0 : 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressedScale != widget.pressedScale) {
      _rebuildCurves();
    }
    if (widget.onTap == null && _pressed) {
      _pressDelay?.cancel();
      _setPressed(false);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _pressDelay?.cancel();
    final inScrollable = Scrollable.maybeOf(context) != null;
    if (inScrollable && widget.pressedScale == 1) {
      _pressDelay = Timer(Timings.press, () {
        if (mounted) _setPressed(true);
      });
    } else {
      _setPressed(true);
    }
  }

  void _handleTapCancel() {
    _pressDelay?.cancel();
    _setPressed(false);
  }

  void _handleTapUp(TapUpDetails details) {
    _pressDelay?.cancel();
    MotionOrigin.record(details.globalPosition);
    _setPressed(false);
  }

  @override
  void dispose() {
    _pressDelay?.cancel();
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = _disableAnimations;
    final usesScale = _usesScale;
    final showOverlay =
        widget.onTap != null &&
        !usesScale &&
        (_pressed ||
            (!disable && _controller != null && _controller!.value > 0));
    final CustomPainter? overlayPainter = showOverlay
        ? _ShapeOverlayPainter(
            shape: widget.shape ?? Radii.shape(widget.radius),
            color: colors.text,
            maxAlpha: 0.10,
            progress: disable || _controller == null
                ? _fullOverlay
                : _controller!,
          )
        : null;

    final Widget visual = usesScale
        ? ScaleTransition(
            scale: disable
                ? _identityScale
                : (_scaleAnimation ?? _identityScale),
            child: widget.child,
          )
        : CustomPaint(foregroundPainter: overlayPainter, child: widget.child);

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : _handleTapDown,
        onTapCancel: _handleTapCancel,
        onTapUp: _handleTapUp,
        onTap: widget.onTap == null
            ? null
            : () {
                // 触摸抬起后才算一次点击，滚动列表时不会误触发震动。
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: visual,
      ),
    );
  }
}

class _ShapeOverlayPainter extends CustomPainter {
  _ShapeOverlayPainter({
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
  bool shouldRepaint(_ShapeOverlayPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.maxAlpha != maxAlpha ||
      old.progress != progress;
}

/// 数字滚动文本：数值变化时从旧值平滑过渡到新值。
///
/// 仅在视觉上滚动，不改变底层计算；统一启用等宽数字，避免宽度跳动。
class AnimatedNumericText extends StatelessWidget {
  const AnimatedNumericText({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.softWrap = false,
    this.duration = Timings.fast,
    this.curve = Curves2.out,
  });

  final num value;
  final String Function(num value) formatter;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool softWrap;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final resolvedStyle = (style ?? DefaultTextStyle.of(context).style)
        .copyWith(fontFeatures: tabularFigures);
    if (disable) {
      return Text(
        formatter(value),
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        style: resolvedStyle,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: motionDuration(duration, disableAnimations: disable),
      curve: curve,
      builder: (context, current, _) => Text(
        formatter(current),
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        style: resolvedStyle,
      ),
    );
  }
}

/// 逐位滚轮数字文本：仅对发生变化的数字位做纵向滑动过渡，符号位保持静止。
///
/// 适用于计时读数等高频跳动数值；系统或应用关闭动效时直接退化为普通 `Text`。
class RollingDigitsText extends StatefulWidget {
  const RollingDigitsText({
    super.key,
    required this.text,
    required this.style,
    this.ascending = true,
    this.duration = Timings.fast,
  });

  final String text;
  final TextStyle style;
  final bool ascending;
  final Duration duration;

  @override
  State<RollingDigitsText> createState() => _RollingDigitsTextState();
}

class _RollingDigitsTextState extends State<RollingDigitsText> {
  static final RegExp _digitPattern = RegExp(r'^[0-9]$');

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final resolvedStyle = widget.style.copyWith(fontFeatures: tabularFigures);
    if (disable) {
      return Text(widget.text, maxLines: 1, style: resolvedStyle);
    }

    final chars = widget.text.split('');
    final direction = widget.ascending ? 1.0 : -1.0;
    final duration = motionDuration(widget.duration, disableAnimations: false);

    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (var index = 0; index < chars.length; index++)
            _buildSlot(
              char: chars[index],
              slotKey: chars.length - 1 - index,
              style: resolvedStyle,
              direction: direction,
              duration: duration,
            ),
        ],
      ),
    );
  }

  Widget _buildSlot({
    required String char,
    required int slotKey,
    required TextStyle style,
    required double direction,
    required Duration duration,
  }) {
    if (!_digitPattern.hasMatch(char)) {
      return Text(
        char,
        key: ValueKey('sep-$slotKey-$char'),
        maxLines: 1,
        style: style,
      );
    }
    return ClipRect(
      key: ValueKey('slot-$slotKey'),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves2.out,
        switchOutCurve: Curves2.out,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.center,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey('d-$slotKey-$char');
          final offsetTween = isIncoming
              ? Tween<Offset>(
                  begin: Offset(0, 0.58 * direction),
                  end: Offset.zero,
                )
              : Tween<Offset>(
                  begin: Offset(0, -0.58 * direction),
                  end: Offset.zero,
                );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetTween.animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          char,
          key: ValueKey('d-$slotKey-$char'),
          maxLines: 1,
          style: style,
        ),
      ),
    );
  }
}

/// 主按钮：FlClash 全圆胶囊主操作按钮 + 柔光投影。
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
    final bg = danger ? colors.expense : colors.primary;
    final fg = danger ? scheme.onError : colors.onPrimary;
    final shape = Radii.shape(Radii.lg);
    final button = Opacity(
      opacity: onPressed == null ? 0.42 : 1,
      child: Pressable(
        onTap: onPressed,
        shape: shape,
        pressedScale: 0.96,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
          decoration: ShapeDecoration(
            color: bg,
            shape: shape,
            shadows: onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A)
                          .withValues(alpha: colors.isDark ? 0.28 : 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
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

/// 次级按钮：FlClash 轻填充胶囊按钮。
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
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = danger ? colors.expense : colors.text;
    final bg = danger ? colors.expenseSoft : colors.block;
    final shape = Radii.shape(Radii.lg);
    final button = Opacity(
      opacity: onPressed == null ? 0.42 : 1,
      child: Pressable(
        onTap: onPressed,
        shape: shape,
        pressedScale: 0.96,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          decoration: ShapeDecoration(color: bg, shape: shape),
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

/// 顶栏悬浮液态玻璃胶囊表面。
class HeaderGlassSurface extends StatelessWidget {
  const HeaderGlassSurface({
    super.key,
    required this.child,
    this.height = 36,
    this.radius = Radii.pill,
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
    return LiquidGlassSurface(
      height: height,
      radius: radius,
      padding: padding,
      selected: selected,
      bright: bright,
      child: child,
    );
  }
}

/// 顶栏悬浮圆形液态玻璃按钮（参考 FlClash 顶栏独立玻璃圆钮）。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.selected = false,
    this.iconSize = 18.5,
    this.size = 36,
    this.radius = Radii.pill,
    this.bright = true,
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
          color: selected ? colors.primary : colors.text,
        ),
      ),
    );
    final button = Pressable(
      onTap: onTap,
      shape: radius >= Radii.pill ? Radii.pillShape : Radii.shape(radius),
      pressedScale: 0.92,
      child: content,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 融合式液态玻璃按钮组：多枚图标共居一枚悬浮玻璃胶囊，如 `[🔍  ✓]`。
class GlassActionGroup extends StatelessWidget {
  const GlassActionGroup({super.key, required this.children, this.height = 36});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LiquidGlassSurface(
      height: height,
      radius: Radii.pill,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                width: 0.8,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: colors.text.withValues(
                  alpha: colors.isDark ? 0.14 : 0.09,
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 融合胶囊内部单枚图标动作。
class GlassGroupIconAction extends StatelessWidget {
  const GlassGroupIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = Pressable(
      onTap: onTap,
      shape: Radii.pillShape,
      pressedScale: 0.90,
      child: SizedBox(
        width: 38,
        height: 36,
        child: Icon(
          icon,
          size: iconSize,
          color: selected ? colors.primary : colors.text,
        ),
      ),
    );
    return tooltip == null ? item : Tooltip(message: tooltip!, child: item);
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
    this.size = 42,
    this.radius = Radii.pill,
    this.bright = true,
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
class UndoBar extends StatefulWidget {
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
  State<UndoBar> createState() => _UndoBarState();
}

class _UndoBarState extends State<UndoBar> with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _countdown.stop();
      return;
    }
    if (!_started) {
      _started = true;
      _countdown.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant UndoBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _countdown.duration = Duration(seconds: widget.seconds);
    }
    if (oldWidget.message != widget.message) {
      final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!disable) {
        _countdown.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shape = Radii.shape(Radii.md);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.card,
          shape: shape.copyWith(
            side: BorderSide(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.8,
            ),
          ),
          shadows: context.floatingShadows,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: SizedBox(
            height: 50,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Gaps.lg, right: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
                      Pressable(
                        onTap: widget.onUndo,
                        shape: Radii.pillShape,
                        pressedScale: 0.94,
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
                ),
                if (!disable && widget.seconds > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2.5,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _countdown,
                        builder: (context, child) {
                          final remain = (1.0 - _countdown.value).clamp(
                            0.0,
                            1.0,
                          );
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: remain,
                            child: child,
                          );
                        },
                        child: ColoredBox(
                          color: colors.primary.withValues(alpha: 0.72),
                        ),
                      ),
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

/// 分段控件：FlClash 胶囊轨道 + 弹性浮块，支持高对比主题高亮。
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.accentActive = false,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final bool accentActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final outerShape = Radii.shape(11);
    final thumbShape = Radii.shape(8.5);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: colors.block, shape: outerShape),
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
                  Timings.fast,
                  disableAnimations: disable,
                ),
                curve: Curves2.out,
                left: selectedIndex * segmentWidth,
                top: 0,
                width: segmentWidth,
                height: 30,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: accentActive
                        ? colors.primary
                        : (colors.isDark ? colors.inset : colors.card),
                    shape: thumbShape,
                    shadows: [
                      BoxShadow(
                        color: const Color(0xFF0F172A)
                            .withValues(alpha: colors.isDark ? 0.24 : 0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
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
                          shape: thumbShape,
                          child: SizedBox(
                            height: 30,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: motionDuration(
                                  Timings.fast,
                                  disableAnimations: disable,
                                ),
                                curve: Curves2.inOut,
                                style: DefaultTextStyle.of(context).style
                                    .copyWith(
                                      fontSize: 13,
                                      fontWeight: value == selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: value == selected
                                          ? (accentActive
                                                ? colors.onPrimary
                                                : colors.text)
                                          : colors.text2,
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

/// 彩色超椭圆图标微标：用于「我的」与设置列表行，一眼区分功能模块。
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
    this.iconSize = 17,
    this.tinted = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDanger = color == colors.expense;
    final useTint = tinted || isDanger;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: useTint
            ? color.withValues(alpha: colors.isDark ? 0.20 : 0.11)
            : colors.block.withValues(alpha: colors.isDark ? 0.80 : 0.85),
        shape: Radii.shape(size * 0.32).copyWith(
          side: BorderSide(
            color: useTint
                ? color.withValues(alpha: colors.isDark ? 0.22 : 0.14)
                : colors.divider.withValues(alpha: 0.75),
            width: 0.7,
          ),
        ),
      ),
      child: Icon(icon, size: iconSize, color: useTint ? color : colors.text),
    );
  }
}

/// 页面顶部主题氛围微光：给浅/深画布顶部一层极轻的主题色径向光晕，
/// 让内容界面与「时页」品牌光感自然衔接，不再是单调死板的纯灰底。
class AmbientPageGlow extends StatelessWidget {
  const AmbientPageGlow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pureBlack = colors.isDark && colors.page.toARGB32() == 0xFF000000;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    if (pureBlack || highContrast) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -110,
          left: -40,
          right: -40,
          height: 260,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.25, -0.7),
                  radius: 1.0,
                  colors: [
                    colors.primary.withValues(
                      alpha: colors.isDark ? 0.075 : 0.024,
                    ),
                    colors.primary.withValues(
                      alpha: colors.isDark ? 0.02 : 0.008,
                    ),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 液态玻璃拨动开关行：直接驱动 `fluid_glass` 的 [LiquidToggle]，
/// 既获得拉丝果冻折射手感，又彻底避免 `SwitchListTile` 嵌套装饰容器断言。
class LiquidSwitchRow extends StatelessWidget {
  const LiquidSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final backdrop = AppBackdropScope.of(context);
    final enabled = onChanged != null;
    return Pressable(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(
            horizontal: Gaps.lg,
            vertical: 10,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: Gaps.md),
              ],
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
                        color: colors.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.38,
                          color: colors.text2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gaps.sm),
              LiquidToggle(
                selected: value,
                onSelect: onChanged,
                backdrop: backdrop,
                semanticLabel: title,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分组区标题：置于分组卡片外部上方，克制留白建立节奏。
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.text3,
              letterSpacing: 0.3,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// 共享的月份切换胶囊，工时页与账本页顶栏统一使用。
class MonthSwitchPill extends StatelessWidget {
  const MonthSwitchPill({
    super.key,
    required this.month,
    required this.onChanged,
    required this.onPick,
  });

  final String month;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final parsed = parseMonthKey(month);
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final label = compact && parsed != null
        ? '${parsed.month}月'
        : formatMonthLabel(month);
    return HeaderGlassSurface(
      height: 36,
      radius: Radii.pill,
      bright: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthArrowButton(
            icon: Icons.chevron_left_rounded,
            label: '上个月',
            onTap: () => onChanged(shiftMonth(month, -1)),
          ),
          Pressable(
            onTap: onPick,
            shape: Radii.shape(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedMonthLabel(
                    label: label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colors.text3,
                  ),
                ],
              ),
            ),
          ),
          _MonthArrowButton(
            icon: Icons.chevron_right_rounded,
            label: '下个月',
            onTap: () => onChanged(shiftMonth(month, 1)),
          ),
        ],
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.shape(10),
        pressedScale: 0.92,
        child: SizedBox(
          width: 24,
          height: 34,
          child: Icon(icon, size: 16.5, color: context.colors.text2),
        ),
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
      duration: motionDuration(Timings.fast, disableAnimations: disable),
      switchInCurve: Curves2.out,
      switchOutCurve: Curves2.out,
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

/// 入场动效：从下方轻推入位 + 淡入。
///
/// 只用于页面首次成形时的「主视觉区块」——错峰 0 / 70 / 140ms 让三层信息
/// 依次落定，而不是整页一起出现。滚动、切 Tab 回来都不重播（由 State 保活
/// 保证），所以它不是装饰性循环动画。系统「移除动画」时直接给终态。
class RevealOnMount extends StatefulWidget {
  const RevealOnMount({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    // R06：UI 动效总长必须 < 300ms。三段错峰 0/40/80 + 200 = 280ms。
    this.duration = Timings.fast,
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// 起始纵向偏移（逻辑像素）。
  final double offset;

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves2.out,
  );
  Timer? _startTimer;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // 读 MediaQuery 而不是 platformDispatcher：应用内的「减少动效」会被
    // main.dart 合成进 MediaQuery.disableAnimations，只读系统开关会漏掉它。
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _startTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final dy = widget.offset * (1 - _curve.value);
          return Transform.translate(
            offset: dy.abs() < 0.05 ? Offset.zero : Offset(0, dy),
            child: child,
          );
        },
        child: widget.child,
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
                  Timings.micro,
                  disableAnimations: disable,
                ),
                curve: Curves2.out,
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
