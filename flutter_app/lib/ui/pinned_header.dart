/// 吸顶顶栏：单层高斯模糊 + 纵向染色渐隐。
///
/// 只用一层原生 BackdropFilter。顶部用高不透明度页面色压住背后的卡片
/// 轮廓，向下逐渐降低透明度，让内容从模糊里化开，而不是露出一个白色圆角块。
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:fluid_glass/fluid_glass.dart';

import '../core/theme_tokens.dart';
import 'widgets.dart';

class _HeaderGlass extends StatelessWidget {
  const _HeaderGlass();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceEffects = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final quality =
        GlassQualityScope.maybeOf(context) ?? GlassDeviceTier.instance.quality;
    final plain = quality == GlassQuality.plain;
    // 每一档都是一次独立的 BackdropFilter 采样。4 档已经足够做出
    // 「顶部清晰、向下化开」的渐进模糊；继续堆到 7 档会增加 GPU 采样，
    // 在滚动时几乎看不出差别。
    final bandCount = reduceEffects ? 2 : (plain ? 3 : 4);
    final maxSigma = reduceEffects ? 12.0 : (plain ? 15.0 : 20.0);
    final opaque = MediaQuery.of(context).highContrast;
    if (opaque) return ColoredBox(color: colors.page);

    final veil = Color.lerp(
      colors.page,
      Colors.white,
      colors.isDark ? 0.02 : 0.16,
    )!;
    return ClipRect(
      child: ShaderMask(
        // 整个玻璃层一起羽化，不再只让染色淡出而把模糊硬切在顶栏底边。
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.80, 1],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: BackdropGroup(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Column(
                  children: List.generate(bandCount, (index) {
                    final progress = index / (bandCount - 1);
                    final sigma = maxSigma * math.pow(1 - progress, 1.05);
                    return Expanded(
                      child: RepaintBoundary(
                        child: ClipRect(
                          child: sigma < 0.15
                              ? const SizedBox.expand()
                              : BackdropFilter.grouped(
                                  filter: ImageFilter.blur(
                                    sigmaX: sigma.toDouble(),
                                    sigmaY: sigma.toDouble(),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        veil.withValues(alpha: colors.isDark ? 0.985 : 0.995),
                        veil.withValues(alpha: colors.isDark ? 0.975 : 0.99),
                        veil.withValues(alpha: colors.isDark ? 0.90 : 0.97),
                        veil.withValues(alpha: colors.isDark ? 0.52 : 0.78),
                        veil.withValues(alpha: colors.isDark ? 0.18 : 0.32),
                        veil.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.38, 0.70, 0.88, 0.97, 1],
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

class PinnedHeader extends StatelessWidget {
  const PinnedHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.height = Gaps.headerHeight,
    this.bottom,
    this.bottomHeight = 48,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;
  final Widget? bottom;
  final double bottomHeight;

  /// 顶栏占据的总高度（状态栏 + 标题行 + 可选副行）。
  static double totalHeight(
    BuildContext context, {
    double height = Gaps.headerHeight,
    bool hasBottom = false,
    double bottomHeight = 48,
  }) =>
      MediaQuery.paddingOf(context).top +
      height +
      (hasBottom ? bottomHeight : 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final total = totalHeight(
      context,
      height: height,
      hasBottom: bottom != null,
      bottomHeight: bottomHeight,
    );

    return SizedBox(
      height: total,
      child: Stack(
        children: [
          Positioned.fill(child: const AbsorbPointer(child: _HeaderGlass())),
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: height,
            child: Padding(
              padding: EdgeInsets.only(
                left: compact ? 16 : 20,
                right: compact ? 12 : Gaps.lg,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Gaps.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 24 : 26,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.01,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (actions != null) ...[
                    const SizedBox(width: Gaps.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: compact ? 6 : 8,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (bottom != null)
            Positioned(
              top: topInset + height,
              left: 0,
              right: 0,
              height: bottomHeight,
              child: bottom!,
            ),
        ],
      ),
    );
  }
}

/// 二级页顶栏：返回按钮 + 标题，同一套实底渐变。
class PinnedSubHeader extends StatelessWidget {
  const PinnedSubHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  static double totalHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + Gaps.headerHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: totalHeight(context),
      child: Stack(
        children: [
          Positioned.fill(child: const AbsorbPointer(child: _HeaderGlass())),
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: Gaps.headerHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: Gaps.sm, right: Gaps.lg),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack,
                    tooltip: '返回',
                    iconSize: 20,
                    bright: true,
                  ),
                  const SizedBox(width: Gaps.sm),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
