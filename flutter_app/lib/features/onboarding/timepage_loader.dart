import 'dart:math' as math;

import 'package:flutter/material.dart';

const _wordmarkAsset = 'assets/brand/loading_wordmark.png';
const _wordmarkDarkAsset = 'assets/brand/loading_wordmark_dark.png';
const _wordmarkAspect = 1400 / 303;

/// TIMEPAGE 手写擦除加载记号。
///
/// 参考视频：先完整停留，再用一条柔和的蓝色笔锋从左向右擦除字标，
/// 末尾只留下一个笔点；擦除完成后字标重新聚合并循环。
class TimepageLoader extends StatefulWidget {
  const TimepageLoader({super.key, this.width = 232, this.color});

  final double width;
  final Color? color;

  @override
  State<TimepageLoader> createState() => _TimepageLoaderState();
}

class _TimepageLoaderState extends State<TimepageLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion == reduce) return;
    _reduceMotion = reduce;
    if (reduce) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = widget.color;
    final asset = dark ? _wordmarkDarkAsset : _wordmarkAsset;
    final color =
        tint ?? (dark ? const Color(0xFFF0F5FF) : const Color(0xFF0B2E7A));
    final image = Image.asset(
      asset,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
    final height = widget.width / _wordmarkAspect;

    if (_reduceMotion ?? false) {
      return Semantics(
        label: 'TIMEPAGE 正在加载',
        liveRegion: true,
        child: SizedBox(width: widget.width, height: height, child: image),
      );
    }

    return Semantics(
      label: 'TIMEPAGE 正在加载',
      liveRegion: true,
      child: SizedBox(
        width: widget.width,
        height: height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final erase = ((t - 0.18) / 0.66).clamp(0.0, 1.0);
            final dot = t < 0.84 ? 0.0 : ((t - 0.84) / 0.16).clamp(0.0, 1.0);
            final reappear = ((t - 0.88) / 0.12).clamp(0.0, 1.0);
            final reappearOpacity = Curves.easeOutCubic.transform(reappear);
            final soft = 0.035;
            final s1 = (erase - soft).clamp(0.0, 1.0);
            final s2 = (erase + soft).clamp(0.0, 1.0);
            final ghostOpacity =
                (math.sin(erase * math.pi) * 0.9).clamp(0.0, 0.9).toDouble() *
                (1 - reappearOpacity);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                      ],
                      stops: [0, s1, s2, 1],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: child,
                  ),
                ),
                if (ghostOpacity > 0.01)
                  Positioned(
                    left: widget.width * erase - 34,
                    top: height * 0.02,
                    bottom: height * 0.02,
                    width: 68,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.62,
                            colors: [
                              color.withValues(alpha: 0.14 * ghostOpacity),
                              color.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (dot > 0.01)
                  Positioned(
                    left: widget.width * 0.91,
                    top: height * 0.47,
                    child: Transform.scale(
                      scale: 0.75 + dot * 0.35,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: dot * 0.9 * (1 - reappearOpacity),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                if (reappear > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: reappearOpacity,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          color: tint,
                          colorBlendMode: tint == null ? null : BlendMode.srcIn,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          child: image,
        ),
      ),
    );
  }
}
