/// 基础 UI 原语：液态玻璃控件、折射脚手架、水滴弹簧按压、按钮、列表行、
/// 可拖拽液态分段控件、开关、空态与数字输入。
///
/// Liquid Glass 仅用于导航和交互控件；内容表面使用稳定、不遮字的语义色。
/// 独立可采样 BackdropLayer 驱动真实折射与色散、
/// 指向性镜面高光棱边、跟随手指膨胀倾斜的水滴形变与弹簧回弹。
library;

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

/// 为带有吸顶液态玻璃顶栏或悬浮胶囊的页面建立独立可采样 [LayerBackdrop]。
///
/// 下层滚动内容由 [BackdropLayer] 实时采集，上层浮岛通过 [AppBackdropScope]
/// 获取像素纹理，实现滚过顶栏/浮钮时的真实光学折射与色散。
class LiquidBackdropScaffold extends StatefulWidget {
  const LiquidBackdropScaffold({
    super.key,
    required this.body,
    required this.overlays,
  });

  final Widget body;
  final List<Widget> overlays;

  @override
  State<LiquidBackdropScaffold> createState() => _LiquidBackdropScaffoldState();
}

class _LiquidBackdropScaffoldState extends State<LiquidBackdropScaffold> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: BackdropLayer(
            backdrop: _backdrop,
            motionPixelRatio: 0.5,
            changeMargin: 24.0,
            child: widget.body,
          ),
        ),
        Positioned.fill(
          child: AppBackdropScope(
            backdrop: _backdrop,
            child: Stack(clipBehavior: Clip.none, children: widget.overlays),
          ),
        ),
      ],
    );
  }
}

/// 指向性镜面高光棱边：左上迎光面呈柔和晶白反光，
/// 沿连续曲率圆角渐隐过渡至右下微弱回光，赋予玻璃表面真实的厚度与折光感。
class LiquidSpecularRimPainter extends CustomPainter {
  const LiquidSpecularRimPainter({
    required this.shape,
    required this.isDark,
    this.strokeWidth = 1.0,
    this.accentTint,
    this.intensity = 1.0,
  });

  final ShapeBorder shape;
  final bool isDark;
  final double strokeWidth;
  final Color? accentTint;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || intensity <= 0) return;
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect.deflate(strokeWidth * 0.5));
    final tint = accentTint;
    final colors = isDark
        ? <Color>[
            Colors.white.withValues(alpha: (0.16 * intensity).clamp(0.0, 1.0)),
            (tint ?? Colors.white).withValues(
              alpha: (0.05 * intensity).clamp(0.0, 1.0),
            ),
            Colors.white.withValues(alpha: (0.015 * intensity).clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: (0.09 * intensity).clamp(0.0, 1.0)),
          ]
        : <Color>[
            Colors.white.withValues(alpha: (0.90 * intensity).clamp(0.0, 1.0)),
            (tint ?? const Color(0xFFD8E6FF)).withValues(
              alpha: (0.34 * intensity).clamp(0.0, 1.0),
            ),
            const Color(0xFF0A1633)
                .withValues(alpha: (0.045 * intensity).clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: (0.56 * intensity).clamp(0.0, 1.0)),
          ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0.0, 0.34, 0.68, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LiquidSpecularRimPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.isDark != isDark ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.accentTint != accentTint ||
      oldDelegate.intensity != intensity;
}

/// 通用液态玻璃浮层表面：用于顶栏岛、胶囊按钮、悬浮工具条和独立浮标。
///
/// 极致档位且提供可采样 [LayerBackdrop] 时走 `fluid_glass` 真实折射与色散着色器；
/// 其余环境使用高透 `BackdropFilter` + 指向性镜面高光棱边 + 悬浮软投影；
/// 开启 [interactive] 后随手指轻按膨胀倾斜并投射可跨控件传递的交互式镜面光晕。
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = Radii.pill,
    this.padding = EdgeInsets.zero,
    this.height,
    this.width,
    this.selected = false,
    this.bright = true,
    this.blurSigma = 18,
    this.tintColor,
    this.refract = true,
    this.showShadow = true,
    this.interactive = false,
    this.chromaticAberration = true,
    this.depthEffect = true,
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
  final bool interactive;
  final bool chromaticAberration;
  final bool depthEffect;

  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface>
    with TickerProviderStateMixin {
  InteractiveHighlight? _highlight;

  InteractiveHighlight _ensureHighlight() =>
      _highlight ??= InteractiveHighlight(vsync: this);

  @override
  void dispose() {
    _highlight?.dispose();
    super.dispose();
  }

  void _applyLayerDeformation(GlassLayer layer) {
    final highlight = _highlight;
    if (highlight == null) return;
    final press = LiquidPressDeformation.resolve(
      layer.size,
      offset: highlight.offset,
      pressProgress: highlight.pressProgress,
    );
    layer
      ..scaleX = press.scaleX
      ..scaleY = press.scaleY
      ..translationX = press.translationX
      ..translationY = press.translationY;
  }

  void _paintGlaze(
    Canvas canvas,
    Size size,
    Color baseFill,
    bool isDark,
    bool selected,
    Color primary,
  ) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = baseFill);
    final topGlint = selected
        ? primary.withValues(alpha: isDark ? 0.16 : 0.08)
        : Colors.white.withValues(alpha: isDark ? 0.09 : 0.34);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topGlint, Colors.transparent],
          stops: const [0.0, 0.52],
        ).createShader(rect),
    );
  }

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
        widget.refract &&
        !highContrast &&
        !reduceEffects &&
        quality == GlassQuality.liquid &&
        backdrop != nativeBackdrop;
    final enableInteractive = widget.interactive && !reduceEffects;
    final highlight = enableInteractive ? _ensureHighlight() : null;

    final liquidFill =
        widget.tintColor ??
        (widget.selected
            ? colors.primaryContainer.withValues(
                alpha: colors.isDark ? 0.62 : 0.68,
              )
            : colors.isDark
            ? const Color(0xFF1D202A)
                  .withValues(alpha: widget.bright ? 0.50 : 0.42)
            : Colors.white.withValues(alpha: widget.bright ? 0.50 : 0.40));

    final plainFill =
        widget.tintColor ??
        (widget.selected
            ? colors.primaryContainer.withValues(
                alpha: highContrast ? 1.0 : (colors.isDark ? 0.80 : 0.86),
              )
            : colors.isDark
            ? const Color(0xFF1E212B).withValues(
                alpha: highContrast ? 1.0 : (widget.bright ? 0.78 : 0.70),
              )
            : Colors.white.withValues(
                alpha: highContrast ? 1.0 : (widget.bright ? 0.84 : 0.76),
              ));

    final shape = widget.radius >= Radii.pill
        ? Radii.pillShape
        : Radii.shape(widget.radius);

    final shadows = !widget.showShadow
        ? null
        : <BoxShadow>[
            BoxShadow(
              color: (colors.isDark ? Colors.black : const Color(0xFF0A1633))
                  .withValues(alpha: colors.isDark ? 0.28 : 0.055),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: (colors.isDark ? Colors.black : const Color(0xFF0A1633))
                  .withValues(alpha: colors.isDark ? 0.14 : 0.025),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ];

    Widget inner = Padding(padding: widget.padding, child: widget.child);
    if (widget.height != null || widget.width != null) {
      inner = SizedBox(
        width: widget.width,
        height: widget.height,
        child: inner,
      );
    }

    if (useLiquidShader) {
      final glassShape = widget.radius >= Radii.pill
          ? const Capsule()
          : RoundedRectangle(widget.radius);
      Widget body = inner;
      if (highlight != null) {
        body = highlight.wrapOverlay(
          child: highlight.wrapGestures(child: body),
        );
      }
      return DrawBackdrop(
        backdrop: backdrop,
        shape: () => glassShape,
        effects: (scope) => scope
          ..vibrancy()
          ..blur(widget.blurSigma * 0.36)
          ..lens(
            12,
            24,
            depthEffect: widget.depthEffect,
            chromaticAberration: widget.chromaticAberration,
          ),
        highlight: () => Highlight.standard,
        shadow: widget.showShadow ? () => GlassShadow.standard : null,
        layerBlock: highlight != null ? _applyLayerDeformation : null,
        repaint: highlight,
        onDrawSurface: (canvas, size) => _paintGlaze(
          canvas,
          size,
          liquidFill,
          colors.isDark,
          widget.selected,
          colors.primary,
        ),
        isolateSurface: false,
        child: body,
      );
    }

    final sigma = (highContrast || reduceEffects) ? 0.0 : widget.blurSigma;
    Widget surfaceContent = inner;
    if (highlight != null) {
      surfaceContent = highlight.wrapOverlay(
        child: highlight.wrapGestures(child: surfaceContent),
      );
    }
    final surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(plainFill, Colors.white, colors.isDark ? 0.07 : 0.24)!,
            plainFill,
          ],
        ),
      ),
      child: surfaceContent,
    );
    final outerBorder = widget.selected
        ? colors.primary.withValues(alpha: 0.34)
        : colors.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF0A1633).withValues(alpha: 0.055);
    final Widget glassBox = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape.copyWith(
          side: BorderSide(color: outerBorder, width: 0.75),
        ),
        shadows: shadows,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: CustomPaint(
          foregroundPainter: highContrast
              ? null
              : LiquidSpecularRimPainter(
                  shape: shape,
                  isDark: colors.isDark,
                  strokeWidth: 0.85,
                  accentTint: widget.selected ? colors.primary : null,
                ),
          child: sigma <= 0.1
              ? surface
              : BackdropFilter(
                  filter: LiquidGlassSurface._blurFilter(sigma),
                  child: surface,
                ),
        ),
      ),
    );
    if (highlight == null) return glassBox;
    return _InteractiveLiquidTransform(highlight: highlight, child: glassBox);
  }
}

/// 在降级磨砂路径上复用 `fluid_glass` 同一套水滴膨胀倾斜形变律。
class _InteractiveLiquidTransform extends StatelessWidget {
  const _InteractiveLiquidTransform({
    required this.highlight,
    required this.child,
  });

  final InteractiveHighlight highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: highlight,
      child: child,
      builder: (context, child) {
        final progress = highlight.pressProgress;
        final offset = highlight.offset;
        if (progress <= 0.0005 && offset.distanceSquared <= 0.01) {
          return child!;
        }
        final box = context.findRenderObject() as RenderBox?;
        final size = (box != null && box.hasSize)
            ? box.size
            : const Size(44, 44);
        final press = LiquidPressDeformation.resolve(
          size,
          offset: offset,
          pressProgress: progress,
        );
        return Transform(
          alignment: Alignment.center,
          transform: press.transform,
          child: child,
        );
      },
    );
  }
}

/// 内容卡使用稳定语义色；Liquid Glass 仅用于悬浮导航与交互控件。
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
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final base = Radii.shape(radius);
    final pureBlack = colors.isDark && colors.page.toARGB32() == 0xFF000000;
    final borderColor = highContrast
        ? colors.outline
        : bordered
        ? colors.cardBorder
        : pureBlack
        ? Colors.white.withValues(alpha: 0.12)
        : colors.cardBorder;
    final shape = base.copyWith(
      side: BorderSide(
        color: borderColor,
        width: highContrast ? 1.2 : (bordered ? 0.9 : 0.75),
      ),
    );
    final resolvedFill = color ?? colors.card;
    final content = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: resolvedFill,
        shape: shape,
        shadows: flat ? null : context.shadows,
      ),
      child: child,
    );
    final wrapped = onTap == null
        ? content
        : Pressable(
            shape: base,
            pressedScale: 0.985,
            onTap: onTap!,
            child: content,
          );
    return margin == null ? wrapped : Padding(padding: margin!, child: wrapped);
  }
}

/// 可按压面：水滴弹簧按压反馈，按下柔压、抬手由物理弹簧自然回弹。
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
    final controller = _usesScale
        ? AnimationController.unbounded(vsync: this, value: 0.0)
        : AnimationController(vsync: this, duration: Timings.fast);
    controller.addStatusListener(_handleAnimationStatus);
    _controller = controller;
    _rebuildCurves();
    return controller;
  }

  void _rebuildCurves() {
    final controller = _controller;
    if (controller == null) return;
    _curved?.dispose();
    if (_usesScale) {
      _curved = null;
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.pressedScale,
      ).animate(controller);
    } else {
      controller.duration = Timings.fast;
      _curved = null;
      _scaleAnimation = null;
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if ((status == AnimationStatus.dismissed ||
            status == AnimationStatus.completed) &&
        !_pressed &&
        (_controller?.value.abs() ?? 0) < 0.002 &&
        mounted) {
      setState(() {});
    }
  }

  void _setPressed(bool next) {
    if (_pressed == next) return;
    _pressed = next;
    if (_disableAnimations) {
      _controller?.value = next ? 1.0 : 0.0;
      if (mounted) setState(() {});
      return;
    }
    final firstCreate = _controller == null;
    final controller = _ensureController();
    if (_usesScale) {
      if (next) {
        controller.animateTo(
          1.0,
          duration: Timings.instant,
          curve: Curves2.out,
        );
        if (firstCreate && mounted) setState(() {});
      } else {
        controller.animateWith(
          SpringSimulation(
            LiquidSprings.pressRelease,
            controller.value,
            0.0,
            -1.2,
          ),
        );
      }
    } else {
      if (next) {
        controller.forward();
        if (mounted) setState(() {});
      } else {
        controller.reverse();
      }
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
    this.duration = Timings.slow,
    this.curve,
  });

  final num value;
  final String Function(num value) formatter;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool softWrap;
  final Duration duration;
  final Curve? curve;

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
      curve: curve ?? LiquidSprings.smoothCurve,
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

/// 主按钮：液态全圆胶囊主操作钮 + 镜面高光棱边 + 水滴弹簧按压。
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
    final shape = Radii.pillShape;
    final button = Opacity(
      opacity: onPressed == null ? 0.42 : 1,
      child: Pressable(
        onTap: onPressed,
        shape: shape,
        pressedScale: 0.965,
        child: CustomPaint(
          foregroundPainter: LiquidSpecularRimPainter(
            shape: shape,
            isDark: true,
            strokeWidth: 0.7,
            intensity: 0.32,
          ),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(bg, Colors.white, colors.isDark ? 0.07 : 0.08)!,
                  bg,
                ],
              ),
              shape: shape,
              shadows: onPressed == null
                  ? null
                  : [
                      BoxShadow(
                        color: bg.withValues(
                          alpha: colors.isDark ? 0.20 : 0.14,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// 次级按钮：轻透磨砂全圆胶囊按钮 + 镜面高光棱边。
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
    final shape = Radii.pillShape;
    final button = Opacity(
      opacity: onPressed == null ? 0.42 : 1,
      child: Pressable(
        onTap: onPressed,
        shape: shape,
        pressedScale: 0.97,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          decoration: ShapeDecoration(
            color: bg,
            shape: shape.copyWith(
              side: BorderSide(
                color: danger
                    ? colors.expense.withValues(alpha: 0.18)
                    : colors.cardBorder,
                width: 0.75,
              ),
            ),
          ),
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
    this.interactive = false,
  });

  final Widget child;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool bright;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      height: height,
      radius: radius,
      padding: padding,
      selected: selected,
      bright: bright,
      interactive: interactive,
      child: child,
    );
  }
}

/// 顶栏悬浮圆形液态玻璃按钮：支持水滴膨胀倾斜与手指光晕追踪。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.selected = false,
    this.iconSize = 18,
    this.size = 44,
    this.radius = Radii.pill,
    this.bright = true,
    this.iconOffset = Offset.zero,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool selected;
  final double iconSize;
  final double size;
  final double radius;
  final bool bright;
  final Offset iconOffset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget iconWidget = Icon(
      icon,
      size: iconSize,
      color: selected ? colors.primary : colors.text,
    );
    if (iconOffset != Offset.zero) {
      iconWidget = Transform.translate(offset: iconOffset, child: iconWidget);
    }
    final content = HeaderGlassSurface(
      height: size,
      radius: radius,
      selected: selected,
      bright: bright,
      interactive: onTap != null,
      child: SizedBox(width: size, height: size, child: iconWidget),
    );
    final button = Pressable(
      onTap: onTap,
      shape: radius >= Radii.pill ? Radii.pillShape : Radii.shape(radius),
      pressedScale: 0.96,
      child: content,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 融合式液态玻璃按钮组：多枚图标共居一枚悬浮玻璃胶囊，如 `[🔍  ✓]`。
class GlassActionGroup extends StatelessWidget {
  const GlassActionGroup({super.key, required this.children, this.height = 38});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LiquidGlassSurface(
      height: height,
      radius: Radii.pill,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      interactive: true,
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
      pressedScale: 0.96,
      child: SizedBox(
        width: 44,
        height: 44,
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

/// 撤销条：液态玻璃胶囊浮条，6 秒后自动消失。
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
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final shape = Radii.pillShape;
    final barContent = SizedBox(
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
              left: 16,
              right: 16,
              bottom: 0,
              height: 2.5,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _countdown,
                  builder: (context, child) {
                    final remain = (1.0 - _countdown.value).clamp(0.0, 1.0);
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: remain,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.primary.withValues(alpha: 0.80),
                      shape: Radii.pillShape,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: highContrast
              ? colors.card
              : colors.card.withValues(alpha: colors.isDark ? 0.78 : 0.80),
          shape: shape.copyWith(
            side: BorderSide(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.86),
              width: 0.8,
            ),
          ),
          shadows: context.floatingShadows,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: CustomPaint(
            foregroundPainter: highContrast
                ? null
                : LiquidSpecularRimPainter(
                    shape: shape,
                    isDark: colors.isDark,
                    strokeWidth: 1.0,
                  ),
            child: (highContrast || disable)
                ? barContent
                : BackdropFilter(
                    filter: LiquidGlassSurface._blurFilter(20),
                    child: barContent,
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
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: colors.text3.withValues(alpha: 0.72),
            ),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Center(
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
        ),
      ),
    );
  }
}

/// 液态玻璃分段控件：可点可滑，滑块随手势带速度拉伸与色散折射。
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
    final selectedIndex = values.indexOf(selected).clamp(0, values.length - 1);
    final backdrop = AppBackdropScope.of(context);
    final trackColor = colors.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF767680).withValues(alpha: 0.11);
    final thumbColor = accentActive
        ? colors.primary.withValues(alpha: 0.92)
        : (colors.isDark ? const Color(0xFF393B47) : Colors.white);

    return LiquidGlassTheme(
      colors: LiquidGlassTheme.of(context).copyWith(
        container: trackColor,
        content: colors.text,
        accent: colors.primary,
      ),
      child: LiquidSegmentedControl(
        selectedIndex: selectedIndex,
        backdrop: backdrop,
        height: 36,
        thumbColor: thumbColor,
        onSelected: (index) {
          if (index < 0 || index >= values.length) return;
          final next = values[index];
          if (next == selected) return;
          HapticFeedback.selectionClick();
          onChanged(next);
        },
        segments: [
          for (final value in values)
            AnimatedDefaultTextStyle(
              duration: motionDuration(
                Timings.micro,
                disableAnimations: disable,
              ),
              curve: Curves2.out,
              style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 13,
                fontWeight: value == selected
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: value == selected
                    ? (accentActive ? colors.onPrimary : colors.text)
                    : colors.text2,
              ),
              child: Text(
                labelOf(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// 彩色超椭圆图标微标：以轻微渐变区分分类与功能。
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
    this.iconSize = 17,
    this.tinted = true,
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
    final shape = Radii.shape(size * 0.31);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        gradient: useTint
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: colors.isDark ? 0.28 : 0.18),
                  color.withValues(alpha: colors.isDark ? 0.16 : 0.09),
                ],
              )
            : null,
        color: useTint
            ? null
            : colors.block.withValues(alpha: colors.isDark ? 0.80 : 0.85),
        shape: shape.copyWith(
          side: BorderSide(
            color: useTint
                ? color.withValues(alpha: colors.isDark ? 0.32 : 0.22)
                : colors.divider.withValues(alpha: 0.75),
            width: 0.75,
          ),
        ),
      ),
      child: Icon(icon, size: iconSize, color: useTint ? color : colors.text),
    );
  }
}

/// 页面画布使用系统分组背景色，为悬浮材质提供稳定对比。
class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: context.colors.page),
    child: child,
  );
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
              letterSpacing: 0,
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
    this.embedded = false,
  });

  final String month;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final parsed = parseMonthKey(month);
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final currentYear = DateTime.now().year;
    final label = parsed == null
        ? formatMonthLabel(month)
        : (compact || parsed.year == currentYear)
        ? '${parsed.month}月'
        : '${parsed.year}年${parsed.month}月';
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthArrowButton(
          icon: Icons.chevron_left_rounded,
          label: '上个月',
          onTap: () => onChanged(shiftMonth(month, -1)),
        ),
        Pressable(
          onTap: onPick,
          shape: Radii.pillShape,
          pressedScale: 0.98,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: 44,
              child: Center(
                child: AnimatedMonthLabel(
                  label: label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
            ),
          ),
        ),
        _MonthArrowButton(
          icon: Icons.chevron_right_rounded,
          label: '下个月',
          onTap: () => onChanged(shiftMonth(month, 1)),
        ),
      ],
    );
    if (embedded) {
      return SizedBox(height: 44, child: content);
    }
    return HeaderGlassSurface(
      height: 44,
      radius: Radii.pill,
      bright: true,
      interactive: true,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: content,
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
        shape: Radii.pillShape,
        pressedScale: 0.96,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 17, color: context.colors.text2),
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
      duration: motionDuration(Timings.base, disableAnimations: disable),
      switchInCurve: LiquidSprings.bouncyCurve,
      switchOutCurve: Curves2.out,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.20),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              child: child,
            ),
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
                      letterSpacing: 0,
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
