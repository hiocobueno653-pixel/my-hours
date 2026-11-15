import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    duration: const Duration(milliseconds: 1100),
    value: 0.14,
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.22),
                  radius: 0.84,
                  colors: [
                    colors.primary.withValues(alpha: dark ? 0.16 : 0.09),
                    background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0,
                                end: 0.40,
                                offset: 0.05,
                                child: const _WelcomeHeading(),
                              ),
                              const SizedBox(height: 22),
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0.10,
                                end: 0.54,
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
                                        begin: 0.24,
                                        end: 0.70,
                                        offset: 0.12,
                                        child: const _LocalFirstCard(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StaggerReveal(
                                        controller: _entryController,
                                        begin: 0.30,
                                        end: 0.76,
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
                                begin: 0.40,
                                end: 0.84,
                                offset: 0.06,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: _StaggerReveal(
                          controller: _entryController,
                          begin: 0.50,
                          end: 1,
                          offset: 0.24,
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
    final width = math.min(310.0, MediaQuery.sizeOf(context).width - 62);
    return Column(
      children: [
        Semantics(
          image: true,
          label: '时页 TIMEPAGE',
          child: SizedBox(
            width: width,
            child: Image.asset(
              dark
                  ? 'assets/brand/wordmark_dark.png'
                  : 'assets/brand/wordmark.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: ShapeDecoration(
            color: colors.card.withValues(alpha: dark ? 0.74 : 0.88),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
              side: BorderSide(
                color: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
              ),
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
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: colors.card,
        shape: Radii.shape(24),
        shadows: colors.isDark ? null : context.shadows.take(2).toList(),
      ),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: ShapeDecoration(
                  color: colors.inset,
                  shape: Radii.pillShape,
                ),
                child: Text(
                  '示例',
                  style: TextStyle(
                    color: colors.text3,
                    fontSize: TypeScale.micro,
                    fontWeight: FontWeight.w600,
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
                    background: colors.primaryContainer,
                    foreground: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _PreviewMetric(
                    label: kHoursOnly ? '出勤' : '本周工资',
                    value: kHoursOnly ? '5' : '¥800',
                    unit: kHoursOnly ? '天' : '',
                    background: kHoursOnly
                        ? colors.incomeSoft
                        : colors.warningSoft,
                    foreground: kHoursOnly ? colors.income : colors.warning,
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
            style: TextStyle(color: colors.text2, fontSize: 11.5, height: 1.45),
          ),
        ],
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
  });

  final String label;
  final String value;
  final String unit;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: ShapeDecoration(color: background, shape: Radii.shape(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.72),
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
                  color: colors.primary.withValues(alpha: 0.18 + 0.48 * level),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(color: colors.card, shape: Radii.shape(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: colors.incomeSoft,
              shape: Radii.shape(12),
            ),
            child: Icon(Icons.shield_outlined, size: 19, color: colors.income),
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

class _HoursPresetCard extends StatefulWidget {
  const _HoursPresetCard();

  @override
  State<_HoursPresetCard> createState() => _HoursPresetCardState();
}

class _HoursPresetCardState extends State<_HoursPresetCard> {
  int _selected = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(color: colors.card, shape: Radii.shape(22)),
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
          Text(
            '进入后可随时调整',
            style: TextStyle(color: colors.text2, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final hours in const [8, 10]) ...[
                Expanded(
                  child: Pressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = hours);
                    },
                    shape: Radii.pillShape,
                    pressedScale: 0.95,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: hours == _selected
                            ? colors.primaryContainer
                            : colors.inset,
                        shape: Radii.pillShape,
                      ),
                      child: Text(
                        '${hours}h',
                        style: TextStyle(
                          color: hours == _selected
                              ? colors.onPrimaryContainer
                              : colors.text2,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: tabularFigures,
                        ),
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
    final radius = BorderRadius.circular(28);
    final bottom = Color.lerp(colors.primary, Colors.black, 0.24)!;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: busy ? '正在进入' : '开始使用',
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Pressable(
          onTap: onPressed,
          haptic: false,
          shape: RoundedSuperellipseBorder(borderRadius: radius),
          pressedScale: 0.97,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.primary, bottom],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 26,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (busy) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                colors.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          busy ? '正在进入…' : '开始使用',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (!busy) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: colors.onPrimary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
    final interval = Interval(
      widget.begin,
      widget.end,
      curve: Curves.easeOutCubic,
    );
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
