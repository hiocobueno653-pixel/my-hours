import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme_tokens.dart';
import '../../ui/widgets.dart';

const welcomeBackground = Color(0xFFF4F5F7);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);

/// 时页品牌首屏：书法字标、品牌承诺与三段能力卡片。
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
    // 加载页切到欢迎页时先给内容一个可见底，避免首帧整页空白。
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0A1020) : welcomeBackground;
    final ink = dark ? const Color(0xFFF7F9FF) : _ink;
    final muted = dark ? const Color(0xFFA9B5CF) : _muted;
    final card = dark ? const Color(0xFF161D2E) : Colors.white;
    final cardBorder = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white;
    final colors = context.colors;

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
            Positioned(
              top: -120,
              right: -110,
              child: IgnorePointer(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: dark ? 0.20 : 0.14),
                        colors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -150,
              bottom: -160,
              child: IgnorePointer(
                child: Container(
                  width: 330,
                  height: 330,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: dark ? 0.11 : 0.055),
                        colors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0,
                                end: 0.46,
                                offset: 0.05,
                                child: _WelcomeHeading(
                                  dark: dark,
                                  ink: ink,
                                  muted: muted,
                                ),
                              ),
                              const SizedBox(height: 26),
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0.12,
                                end: 0.60,
                                offset: 0.16,
                                child: _FeatureCard(
                                  icon: Icons.calendar_month_rounded,
                                  accent: colors.primary,
                                  dark: dark,
                                  card: card,
                                  border: cardBorder,
                                  title: '日历记工',
                                  description: '点选日期，快速记录工时、加班与休息日。',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0.24,
                                end: 0.72,
                                offset: 0.16,
                                child: _FeatureCard(
                                  icon: Icons.payments_rounded,
                                  accent: colors.income,
                                  dark: dark,
                                  card: card,
                                  border: cardBorder,
                                  title: '工资自动核算',
                                  description: '累计工时、日均时长与待结算工资实时算清。',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0.36,
                                end: 0.84,
                                offset: 0.16,
                                child: _FeatureCard(
                                  icon: Icons.receipt_long_rounded,
                                  accent: colors.warning,
                                  dark: dark,
                                  card: card,
                                  border: cardBorder,
                                  title: '收支与结算',
                                  description: '收入、支出和结算状态在同一页看清。',
                                ),
                              ),
                              const SizedBox(height: 20),
                              _StaggerReveal(
                                controller: _entryController,
                                begin: 0.48,
                                end: 0.94,
                                offset: 0,
                                child: _PrivacyNote(muted: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      8,
                      24,
                      MediaQuery.paddingOf(context).bottom + 14,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: _StaggerReveal(
                          controller: _entryController,
                          begin: 0.50,
                          end: 0.98,
                          offset: 0.32,
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
  const _WelcomeHeading({
    required this.dark,
    required this.ink,
    required this.muted,
  });

  final bool dark;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
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
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.78),
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
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '时页 · 本地优先',
                style: TextStyle(
                  color: muted,
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
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.28,
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '把工时、工资与每一笔收支，留在属于你的时间页。',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13.5, height: 1.55),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.accent,
    required this.dark,
    required this.card,
    required this.border,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final bool dark;
  final Color card;
  final Color border;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: ShapeDecoration(
        color: card,
        shape: Radii.shape(22),
        shadows: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      foregroundDecoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  dark ? colors.card.withValues(alpha: 0.86) : Colors.white,
                  accent.withValues(alpha: dark ? 0.22 : 0.12),
                ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
              ),
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: dark ? const Color(0xFFF7F9FF) : _ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFA9B5CF)
                        : const Color(0xFF6B7280),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '数据只保存在本机 · 无需账号',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 11.5,
              height: 1.4,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
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
          shape: RoundedSuperellipseBorder(borderRadius: radius),
          pressedScale: 0.975,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 26,
                  offset: Offset(0, 12),
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
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          busy ? '正在进入…' : '开始使用',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (!busy) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
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
