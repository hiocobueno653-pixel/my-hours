import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final linear = navigator?.userGestureInProgress ?? false;
    return _AppCardTransition(
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
      showLeadingEdgeShadow: isLight,
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
  late final CurvedAnimation _primaryCurved = CurvedAnimation(
    parent: widget.primaryAnimation,
    curve: FlClashSprings.pushCurve,
    reverseCurve: FlClashSprings.pushCurve.flipped,
  );
  late final CurvedAnimation _secondaryCurved = CurvedAnimation(
    parent: widget.secondaryAnimation,
    curve: FlClashSprings.pushCurve,
    reverseCurve: FlClashSprings.pushCurve.flipped,
  );

  @override
  void initState() {
    super.initState();
    widget.secondaryAnimation.addStatusListener(_syncSnapshot);
    _syncSnapshot(widget.secondaryAnimation.status);
  }

  void _syncSnapshot(AnimationStatus status) {
    final coveredMoving =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    _snapshot.allowSnapshotting = coveredMoving;
  }

  @override
  void dispose() {
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
    final effectivePrimary = widget.linearTransition
        ? widget.primaryAnimation
        : _primaryCurved;
    final effectiveSecondary = widget.linearTransition
        ? widget.secondaryAnimation
        : _secondaryCurved;
    final primarySlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(effectivePrimary);
    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-FlClashSprings.coveredSlideFraction, 0.0),
    ).animate(effectiveSecondary);

    return SlideTransition(
      position: secondarySlide,
      child: SlideTransition(
        position: primarySlide,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.primaryAnimation,
            widget.secondaryAnimation,
          ]),
          builder: (context, child) {
            final primaryVal = widget.primaryAnimation.value;
            final movingIn = primaryVal > 0.001 && primaryVal < 0.999;
            final dimAlpha =
                FlClashSprings.coveredDimAlpha *
                effectiveSecondary.value.clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                if (widget.showLeadingEdgeShadow && movingIn)
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
                child!,
                if (dimAlpha > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: dimAlpha),
                      ),
                    ),
                  ),
              ],
            );
          },
          child: SnapshotWidget(
            controller: _snapshot,
            mode: SnapshotMode.permissive,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
