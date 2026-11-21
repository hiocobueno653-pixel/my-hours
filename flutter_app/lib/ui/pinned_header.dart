/// 吸顶顶栏：FlClash 悬浮液态玻璃岛 + 顶部柔和渐隐遮罩 + 胶囊变形搜索。
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import '../core/theme_tokens.dart';
import 'widgets.dart';

/// 顶部羽化渐隐遮罩：压住状态栏文字对比度，向下化开，让下方卡片自然滑入玻璃岛背后。
class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    if (highContrast) return ColoredBox(color: colors.page);
    final base = colors.page;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            base.withValues(alpha: 0.94),
            base.withValues(alpha: 0.86),
            base.withValues(alpha: 0.52),
            base.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.56, 0.82, 1.0],
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
    this.animateTitle = false,
    this.onTitleLongPress,
    this.titleHint,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;
  final Widget? bottom;
  final double bottomHeight;
  final bool animateTitle;
  final void Function(Offset globalPosition)? onTitleLongPress;
  final String? titleHint;

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
      height: total + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: _HeaderScrim()),
          ),
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
                    child: _HeaderTitle(
                      title: title,
                      compact: compact,
                      animate: animateTitle,
                      onLongPress: onTitleLongPress,
                      hint: titleHint,
                      color: colors.text,
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

class _HeaderTitle extends StatefulWidget {
  const _HeaderTitle({
    required this.title,
    required this.compact,
    required this.animate,
    required this.onLongPress,
    required this.hint,
    required this.color,
  });

  final String title;
  final bool compact;
  final bool animate;
  final void Function(Offset globalPosition)? onLongPress;
  final String? hint;
  final Color color;

  @override
  State<_HeaderTitle> createState() => _HeaderTitleState();
}

class _HeaderTitleState extends State<_HeaderTitle> {
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final style = TextStyle(
      fontSize: widget.compact ? 23 : 26,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: widget.color,
    );
    final textWidget = widget.animate
        ? AnimatedMonthLabel(label: widget.title, style: style)
        : Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
    final onLongPress = widget.onLongPress;
    if (onLongPress == null) return textWidget;
    return Semantics(
      header: true,
      hint: widget.hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _holding = true),
        onTapUp: (_) => setState(() => _holding = false),
        onTapCancel: () => setState(() => _holding = false),
        onLongPressStart: (details) {
          setState(() => _holding = false);
          HapticFeedback.mediumImpact();
          onLongPress(details.globalPosition);
        },
        child: AnimatedScale(
          scale: _holding && !disable ? 0.96 : 1.0,
          duration: motionDuration(Timings.press, disableAnimations: disable),
          curve: Curves2.out,
          alignment: Alignment.centerLeft,
          child: Align(
            alignment: Alignment.centerLeft,
            child: textWidget,
          ),
        ),
      ),
    );
  }
}

/// 二级页顶栏：悬浮圆形液态玻璃返回钮 + 标题 + 可选右侧玻璃操作。
class PinnedSubHeader extends StatelessWidget {
  const PinnedSubHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.actions,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;

  static double totalHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + Gaps.headerHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: totalHeight(context) + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: _HeaderScrim()),
          ),
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: Gaps.headerHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: Gaps.lg, right: Gaps.lg),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack,
                    tooltip: '返回',
                    iconSize: 20,
                    bright: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (actions != null) ...[
                    const SizedBox(width: Gaps.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FlClash 风格液态玻璃胶囊变形搜索顶栏：
/// 常态为「标题 + 中间胶囊 + 右侧玻璃按钮组」；点击放大镜后，玻璃胶囊弹性展开为
/// 全宽搜索框，右侧图标平滑切为圆形关闭钮，并伴随轻度高斯模糊过渡。
class MorphingSearchHeader extends StatefulWidget {
  const MorphingSearchHeader({
    super.key,
    required this.title,
    required this.searching,
    required this.controller,
    required this.hintText,
    required this.onSearchingChanged,
    required this.onQueryChanged,
    required this.onClearQuery,
    this.middleAction,
    this.trailingAction,
    this.height = Gaps.headerHeight,
  });

  final String title;
  final bool searching;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<bool> onSearchingChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final Widget? middleAction;
  final Widget? trailingAction;
  final double height;

  static double totalHeight(
    BuildContext context, {
    double height = Gaps.headerHeight,
  }) => MediaQuery.paddingOf(context).top + height;

  @override
  State<MorphingSearchHeader> createState() => _MorphingSearchHeaderState();
}

class _MorphingSearchHeaderState extends State<MorphingSearchHeader> {
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant MorphingSearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching && !oldWidget.searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.searching && oldWidget.searching) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _closeSearch() {
    HapticFeedback.selectionClick();
    widget.onClearQuery();
    widget.onSearchingChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final total = MorphingSearchHeader.totalHeight(
      context,
      height: widget.height,
    );

    return SizedBox(
      height: total + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: _HeaderScrim()),
          ),
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: widget.height,
            child: Padding(
              padding: EdgeInsets.only(
                left: compact ? 16 : 20,
                right: compact ? 12 : Gaps.lg,
              ),
              child: AnimatedSwitcher(
                duration: motionDuration(
                  Timings.toast,
                  disableAnimations: disable,
                ),
                reverseDuration: motionDuration(
                  Timings.base,
                  disableAnimations: disable,
                ),
                switchInCurve: FlClashSprings.searchOpenCurve,
                switchOutCurve: FlClashSprings.searchCloseCurve,
                transitionBuilder: (child, animation) {
                  if (disable) return child;
                  return AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, inner) {
                      final raw = animation.value;
                      final t = raw.clamp(0.0, 1.0);
                      final blur = (1 - t) * 4.0;
                      final scale = (0.94 + 0.06 * raw).clamp(0.90, 1.03);
                      return Opacity(
                        opacity: t,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.centerRight,
                          child: blur > 0.15
                              ? ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: blur,
                                    sigmaY: blur,
                                  ),
                                  child: inner,
                                )
                              : inner,
                        ),
                      );
                    },
                  );
                },
                child: widget.searching
                    ? Row(
                        key: const ValueKey('header-search-active'),
                        children: [
                          Expanded(
                            child: LiquidGlassSurface(
                              height: 44,
                              radius: Radii.pill,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 19,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: widget.controller,
                                      focusNode: _focusNode,
                                      onChanged: widget.onQueryChanged,
                                      textInputAction: TextInputAction.search,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        color: colors.text,
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
                                          fontSize: 14,
                                          color: colors.text3,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.controller.text.isNotEmpty)
                                    Pressable(
                                      onTap: widget.onClearQuery,
                                      shape: Radii.pillShape,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.cancel_rounded,
                                          size: 18,
                                          color: colors.text3,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GlassIconButton(
                            icon: Icons.close_rounded,
                            tooltip: '关闭搜索',
                            onTap: _closeSearch,
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('header-search-idle'),
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 23 : 26,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: colors.text,
                              ),
                            ),
                          ),
                          if (widget.middleAction != null) ...[
                            const SizedBox(width: Gaps.sm),
                            widget.middleAction!,
                          ],
                          const SizedBox(width: 8),
                          GlassIconButton(
                            icon: Icons.search_rounded,
                            tooltip: '搜索',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onSearchingChanged(true);
                            },
                          ),
                          if (widget.trailingAction != null) ...[
                            const SizedBox(width: 8),
                            widget.trailingAction!,
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
