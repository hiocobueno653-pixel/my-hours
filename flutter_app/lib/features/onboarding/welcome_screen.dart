import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';
import '../../core/formatters.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../ui/widgets.dart';

/// 时页品牌首屏：书法字标、1+2 Bento 预览与本地优先承诺。
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final Future<void> Function() onStart;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: Timings.sheet,
  );
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_entryController.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _entryController
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await widget.onStart();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂时无法保存，请再试一次')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = colors.page;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, constraints.maxHeight - 40),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _StaggerReveal(
                                    controller: _entryController,
                                    begin: 0,
                                    end: 0.38,
                                    offset: 0.06,
                                    child: const _WelcomeHeading(),
                                  ),
                                  const SizedBox(height: 22),
                                  _StaggerReveal(
                                    controller: _entryController,
                                    begin: 0.10,
                                    end: 0.48,
                                    offset: 0.12,
                                    child: const _BentoPreview(),
                                  ),
                                  const SizedBox(height: 12),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _StaggerReveal(
                                            controller: _entryController,
                                            begin: 0.20,
                                            end: 0.58,
                                            offset: 0.12,
                                            child: const _LocalFirstCard(),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _StaggerReveal(
                                            controller: _entryController,
                                            begin: 0.26,
                                            end: 0.64,
                                            offset: 0.12,
                                            child: const _HoursPresetCard(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _StaggerReveal(
                                    controller: _entryController,
                                    begin: 0.34,
                                    end: 0.72,
                                    offset: 0.06,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          size: 13,
                                          color: colors.text3,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            '数据只保存在本机 · 无需账号',
                                            style: TextStyle(
                                              color: colors.text3,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: _StaggerReveal(
                          controller: _entryController,
                          begin: 0.42,
                          end: 0.90,
                          offset: 0.18,
                          child: _StartButton(
                            busy: _starting,
                            onPressed: _starting ? null : _start,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeading extends StatelessWidget {
  const _WelcomeHeading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = colors.isDark;
    final width = math.min(260.0, MediaQuery.sizeOf(context).width - 96);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: dark ? 0.28 : 0.18),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: ShapeDecoration(
                color: colors.card,
                shape: Radii.shape(20).copyWith(
                  side: BorderSide(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.14)
                        : colors.cardBorder,
                    width: 0.75,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: dark ? 0.24 : 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF141519)
                        .withValues(alpha: dark ? 0.26 : 0.06),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: Radii.shape(20)),
                child: Image.asset(
                  'assets/brand/app_icon.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          image: true,
          label: '时页 TIMEPAGE',
          child: SizedBox(
            width: width,
            height: 68,
            child: Image.asset(
              dark
                  ? 'assets/brand/wordmark_dark.png'
                  : 'assets/brand/wordmark.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: ShapeDecoration(
            color: colors.card,
            shape: Radii.pillShape.copyWith(
              side: BorderSide(color: colors.cardBorder),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '时页 · 本地优先',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '记录时间，记下生活。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.28,
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          kHoursOnly ? '把每一天的工时，留在属于你的时间页。' : '把工时、工资与每一笔收支，留在属于你的时间页。',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.text2, fontSize: 13.5, height: 1.55),
        ),
      ],
    );
  }
}

class _BentoPreview extends StatelessWidget {
  const _BentoPreview();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: studioHeroDecoration(colors, radius: Radii.hero),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: Radii.shape(Radii.hero)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '本周预览',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: ShapeDecoration(
                      color: colors.block,
                      shape: Radii.shape(Radii.sm),
                    ),
                    child: Text(
                      '示例',
                      style: TextStyle(
                        color: colors.text3,
                        fontSize: TypeScale.micro,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PreviewMetric(
                        label: '本周工时',
                        value: '32.0',
                        unit: 'h',
                        background: colors.block,
                        foreground: colors.text,
                        labelColor: colors.text2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _PreviewMetric(
                        label: kHoursOnly ? '出勤' : '本周工资',
                        value: kHoursOnly ? '5' : '¥800',
                        unit: kHoursOnly ? '天' : '',
                        background: colors.block,
                        foreground: colors.text,
                        labelColor: colors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _WeekBars(colors: colors),
              const SizedBox(height: 9),
              Text(
                kHoursOnly ? '日历点选记工 · 工时与出勤一起看清' : '日历点选记工 · 工时、工资与收支一起看清',
                style: TextStyle(
                  color: colors.text3,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.background,
    required this.foreground,
    required this.labelColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color background;
  final Color foreground;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: ShapeDecoration(
        color: background,
        shape: Radii.shape(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: TypeScale.micro,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 23,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.04,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    const levels = [0.42, 0.72, 0.56, 0.92, 0.68, 0.34, 0.46];
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final level in levels) ...[
            Expanded(
              child: Container(
                height: 8 + 16 * level,
                decoration: ShapeDecoration(
                  color: colors.primary.withValues(alpha: 0.22 + 0.68 * level),
                  shape: Radii.shape(5),
                ),
              ),
            ),
            if (level != levels.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _LocalFirstCard extends StatelessWidget {
  const _LocalFirstCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      flat: true,
      radius: Radii.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: ShapeDecoration(
              color: colors.incomeSoft,
              shape: Radii.shape(10).copyWith(
                side: BorderSide(
                  color: colors.income.withValues(alpha: 0.16),
                  width: 0.6,
                ),
              ),
            ),
            child: Icon(Icons.shield_outlined, size: 18, color: colors.income),
          ),
          const SizedBox(height: 10),
          Text(
            '本地离线',
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '三代备份 · 无需账号',
            style: TextStyle(color: colors.text2, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// 日工时预设的展示卡。
///
/// 这里**不是选择器**：快捷档位在记工页里是固定的 `0/4/6/8/8.5/10/12`，
/// 欢迎页选了也不会写进任何设置。原来做成可点却什么都不改变，属于假控件；
/// 现在只把「8h 是常用档」这件事画出来，不提供点击。
class _HoursPresetCard extends StatelessWidget {
  const _HoursPresetCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      flat: true,
      radius: Radii.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '日工时预设',
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text('记工时一键选', style: TextStyle(color: colors.text2, fontSize: 11.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final hours in const [8, 10]) ...[
                Expanded(
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: hours == 8
                          ? colors.primaryContainer
                          : colors.block,
                      shape: Radii.shape(Radii.sm),
                    ),
                    child: Text(
                      '${hours}h',
                      style: TextStyle(
                        color: hours == 8
                            ? colors.onPrimaryContainer
                            : colors.text2,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                ),
                if (hours == 8) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = Radii.shape(Radii.lg);
    final gradStart = colors.primary;
    final gradEnd = Color.lerp(colors.primary, const Color(0xFF0F172A), 0.24)!;
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Pressable(
          onTap: onPressed,
          shape: shape,
          pressedScale: 0.97,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradStart, gradEnd],
              ),
              shape: shape,
              shadows: onPressed == null
                  ? null
                  : [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha: colors.isDark ? 0.38 : 0.32,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!busy) ...[
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: colors.onPrimary,
                  ),
                  const SizedBox(width: Gaps.sm),
                ],
                Text(
                  busy ? '正在进入…' : '开始使用',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

class _StaggerReveal extends StatefulWidget {
  const _StaggerReveal({
    required this.controller,
    required this.begin,
    required this.end,
    required this.offset,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final double offset;
  final Widget child;

  @override
  State<_StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<_StaggerReveal> {
  late CurvedAnimation _fade;
  late CurvedAnimation _slideCurve;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _buildAnimations();
  }

  @override
  void didUpdateWidget(covariant _StaggerReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.begin != widget.begin ||
        oldWidget.end != widget.end ||
        oldWidget.offset != widget.offset) {
      _disposeAnimations();
      _buildAnimations();
    }
  }

  void _buildAnimations() {
    final interval = Interval(widget.begin, widget.end, curve: Curves2.out);
    _fade = CurvedAnimation(parent: widget.controller, curve: interval);
    _slideCurve = CurvedAnimation(parent: widget.controller, curve: interval);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(_slideCurve);
  }

  void _disposeAnimations() {
    _fade.dispose();
    _slideCurve.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
