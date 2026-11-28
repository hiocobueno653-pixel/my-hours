import 'package:flutter/cupertino.dart';

import '../core/motion.dart';

/// FlClash / iOS 风格二级页推入路由：
/// - 临界阻尼 300ms 弹簧（初速 9×），从右侧滑入；
/// - 前缘附带 4% 黑 6 段平滑渐变投影条（静止后不绘制，无昂贵模糊）；
/// - 被覆盖页向左侧视差位移 30% 并叠加 10% 黑压暗，移动期间由 SnapshotWidget 冻结重绘；
/// - 移动端支持左侧边缘跟手滑动返回。
class AppCardPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  AppCardPageRoute({
    required this.builder,
    this.disableAnimations = false,
    super.settings,
  });

  final WidgetBuilder builder;
  final bool disableAnimations;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Duration get transitionDuration =>
      motionDuration(Timings.slow, disableAnimations: disableAnimations);

  @override
  Duration get reverseTransitionDuration =>
      motionDuration(Timings.slow, disableAnimations: disableAnimations);

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (disableAnimations) return child;
    final linear = navigator?.userGestureInProgress ?? false;
    return _AppCardTransition(
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
      showLeadingEdgeShadow: true,
      linearTransition: linear,
      child: CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        this,
        context,
        const AlwaysStoppedAnimation<double>(1),
        const AlwaysStoppedAnimation<double>(0),
        child,
      ),
    );
  }
}

class _AppCardTransition extends StatefulWidget {
  const _AppCardTransition({
    required this.primaryAnimation,
    required this.secondaryAnimation,
    required this.showLeadingEdgeShadow,
    required this.linearTransition,
    required this.child,
  });

  final Animation<double> primaryAnimation;
  final Animation<double> secondaryAnimation;
  final bool showLeadingEdgeShadow;
  final bool linearTransition;
  final Widget child;

  @override
  State<_AppCardTransition> createState() => _AppCardTransitionState();
}

class _AppCardTransitionState extends State<_AppCardTransition> {
  final SnapshotController _snapshot = SnapshotController();
  static final Animatable<Offset> _primarySlideTween = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  );
  static final Animatable<Offset> _secondarySlideTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-FlClashSprings.coveredSlideFraction, 0.0),
  );
  static const Color _coveredDimColor = Color.fromRGBO(
    0,
    0,
    0,
    FlClashSprings.coveredDimAlpha,
  );

  late final CurvedAnimation _primaryCurved = CurvedAnimation(
    parent: widget.primaryAnimation,
    curve: LiquidSprings.smoothCurve,
    reverseCurve: LiquidSprings.smoothCurve.flipped,
  );
  late final CurvedAnimation _secondaryCurved = CurvedAnimation(
    parent: widget.secondaryAnimation,
    curve: LiquidSprings.smoothCurve,
    reverseCurve: LiquidSprings.smoothCurve.flipped,
  );
  late final Animation<Offset> _curvedPrimarySlide = _primarySlideTween.animate(
    _primaryCurved,
  );
  late final Animation<Offset> _linearPrimarySlide = _primarySlideTween.animate(
    widget.primaryAnimation,
  );
  late final Animation<Offset> _curvedSecondarySlide = _secondarySlideTween
      .animate(_secondaryCurved);
  late final Animation<Offset> _linearSecondarySlide = _secondarySlideTween
      .animate(widget.secondaryAnimation);
  bool _primaryMoving = false;
  bool _secondaryVisible = false;

  @override
  void initState() {
    super.initState();
    widget.primaryAnimation.addStatusListener(_syncPrimaryStatus);
    widget.secondaryAnimation.addStatusListener(_syncSnapshot);
    _syncPrimaryStatus(widget.primaryAnimation.status, allowSetState: false);
    _syncSnapshot(widget.secondaryAnimation.status, allowSetState: false);
  }

  void _syncPrimaryStatus(AnimationStatus status, {bool allowSetState = true}) {
    final moving =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (_primaryMoving != moving) {
      _primaryMoving = moving;
      if (allowSetState && mounted) setState(() {});
    }
  }

  void _syncSnapshot(AnimationStatus status, {bool allowSetState = true}) {
    final coveredMoving =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    _snapshot.allowSnapshotting = coveredMoving;
    final visible = status != AnimationStatus.dismissed;
    if (_secondaryVisible != visible) {
      _secondaryVisible = visible;
      if (allowSetState && mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.primaryAnimation.removeStatusListener(_syncPrimaryStatus);
    widget.secondaryAnimation.removeStatusListener(_syncSnapshot);
    _primaryCurved.dispose();
    _secondaryCurved.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  static const _shadowStops = <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
  static const _shadowColors = <Color>[
    Color.fromRGBO(0, 0, 0, 0.0),
    Color.fromRGBO(0, 0, 0, 0.0009),
    Color.fromRGBO(0, 0, 0, 0.0027),
    Color.fromRGBO(0, 0, 0, 0.0063),
    Color.fromRGBO(0, 0, 0, 0.0123),
    Color.fromRGBO(0, 0, 0, 0.02),
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveSecondary = widget.linearTransition
        ? widget.secondaryAnimation
        : _secondaryCurved;
    final primarySlide = widget.linearTransition
        ? _linearPrimarySlide
        : _curvedPrimarySlide;
    final secondarySlide = widget.linearTransition
        ? _linearSecondarySlide
        : _curvedSecondarySlide;
    final showShadow =
        widget.showLeadingEdgeShadow &&
        (_primaryMoving || widget.linearTransition);

    return SlideTransition(
      position: secondarySlide,
      child: SlideTransition(
        position: primarySlide,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            if (showShadow)
              const Positioned(
                top: 0,
                bottom: 0,
                left: -36,
                width: 36,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: _shadowColors,
                        stops: _shadowStops,
                      ),
                    ),
                  ),
                ),
              ),
            SnapshotWidget(
              controller: _snapshot,
              mode: SnapshotMode.permissive,
              child: widget.child,
            ),
            if (_secondaryVisible || widget.linearTransition)
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: effectiveSecondary,
                    child: const ColoredBox(color: _coveredDimColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
