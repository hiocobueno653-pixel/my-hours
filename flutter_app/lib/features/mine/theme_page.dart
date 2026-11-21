import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/settings.dart';
import '../../core/theme_tokens.dart';
import '../../ui/dialog.dart';
import '../../ui/glass_menu.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import 'custom_color_sheet.dart';

/// 主题与外观。版式参考系统主题页：顶部实时预览 + 分区设置卡片。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final colors = context.colors;
        final palette = settings.accentPalette;
        final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        return Scaffold(
          backgroundColor: colors.page,
          body: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    top: PinnedSubHeader.totalHeight(context) + 12,
                    bottom: MediaQuery.paddingOf(context).bottom + 40,
                  ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ThemePreview(settings: settings),
                        const SizedBox(height: Gaps.xl),
                        const _SectionLabel(label: '主题模式'),
                        const SizedBox(height: Gaps.sm),
                        GlassCard(
                          padding: const EdgeInsets.all(Gaps.md),
                          child: Segmented<ThemeMode>(
                            values: const [
                              ThemeMode.system,
                              ThemeMode.light,
                              ThemeMode.dark,
                            ],
                            selected: settings.themeMode,
                            labelOf: (mode) => switch (mode) {
                              ThemeMode.system => '自动',
                              ThemeMode.light => '浅色',
                              ThemeMode.dark => '深色',
                            },
                            onChanged: settings.setThemeMode,
                          ),
                        ),
                        const SizedBox(height: Gaps.md),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: LiquidSwitchRow(
                            title: '纯黑模式',
                            subtitle: settings.themeMode == ThemeMode.light
                                ? '仅深色模式生效'
                                : '深色模式下使用纯黑页面与深色卡片',
                            leading: AppIconBadge(
                              icon: Icons.contrast_rounded,
                              color: colors.isDark
                                  ? colors.text
                                  : const Color(0xFF18181C),
                            ),
                            value: settings.pureBlack,
                            onChanged: settings.themeMode == ThemeMode.light
                                ? null
                                : settings.setPureBlack,
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        Row(
                          children: [
                            const _SectionLabel(label: '主题色彩'),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: motionDuration(
                                Timings.fast,
                                disableAnimations: disable,
                              ),
                              switchInCurve: Curves2.out,
                              switchOutCurve: Curves2.out,
                              child: settings.isDefaultThemeColor
                                  ? const SizedBox.shrink(
                                      key: ValueKey('reset-hidden'),
                                    )
                                  : Pressable(
                                      key: const ValueKey('reset-shown'),
                                      onTap: () =>
                                          _confirmResetColors(context, settings),
                                      shape: Radii.pillShape,
                                      pressedScale: 0.94,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: colors.primaryContainer,
                                          shape: Radii.pillShape,
                                        ),
                                        child: Text(
                                          '恢复默认',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gaps.sm),
                        GlassCard(
                          padding: const EdgeInsets.all(Gaps.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 14,
                                runSpacing: 12,
                                children: [
                                  for (final color in palette)
                                    _ColorDot(
                                      color: color,
                                      selected:
                                          color.toARGB32() ==
                                          settings.accentColor.toARGB32(),
                                      onTap: () =>
                                          settings.setAccentColor(color),
                                      onLongPress: (pos) => _showSwatchMenu(
                                        context,
                                        settings: settings,
                                        color: color,
                                        canDelete: palette.length > 1,
                                        globalPosition: pos,
                                      ),
                                    ),
                                  _AddColorDot(
                                    onTap: () =>
                                        _showCustomColor(context, settings),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '点「+」可按网格、光谱、滑块或 HEX 自由取色；长按色块可编辑或删除',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.text3,
                                ),
                              ),
                              const SizedBox(height: Gaps.lg),
                              Text(
                                '配色风格',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text2,
                                ),
                              ),
                              const SizedBox(height: Gaps.sm),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GlassSelectMenu<AppColorStyle>(
                                  values: AppColorStyle.values,
                                  selected: settings.colorStyle,
                                  labelOf: (style) => switch (style) {
                                    AppColorStyle.vivid => '鲜明',
                                    AppColorStyle.atmospheric => '氛围',
                                    AppColorStyle.soft => '柔和',
                                    AppColorStyle.monochrome => '单色',
                                  },
                                  onChanged: settings.setColorStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        const _SectionLabel(label: '布局与动效'),
                        const SizedBox(height: Gaps.sm),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(
                            Gaps.lg,
                            Gaps.lg,
                            Gaps.lg,
                            Gaps.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ControlLabel('选项卡动画'),
                              const SizedBox(height: Gaps.sm),
                              Segmented<AppTabTransition>(
                                values: AppTabTransition.values,
                                selected: settings.tabTransition,
                                labelOf: (style) =>
                                    style == AppTabTransition.slide
                                    ? '滑动'
                                    : '淡入',
                                onChanged: settings.setTabTransition,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        const _SectionLabel(label: '字体与阅读'),
                        const SizedBox(height: Gaps.sm),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListRow(
                            title: '字体',
                            subtitle: '系统默认字体 · 保持现有字形不变',
                            leading: const AppIconBadge(
                              icon: Icons.text_fields_rounded,
                              color: Color(0xFF5856D6),
                            ),
                          ),
                        ),
                        const SizedBox(height: Gaps.md),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(
                            Gaps.lg,
                            Gaps.lg,
                            Gaps.lg,
                            Gaps.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ControlLabel(
                                settings.largeText
                                    ? '大字模式 · 112%'
                                    : '文本缩放 · ${(settings.textScale * 100).round()}%',
                              ),
                              const SizedBox(height: Gaps.sm),
                              Segmented<bool>(
                                values: const [true, false],
                                selected: settings.followSystemText,
                                labelOf: (follow) => follow ? '跟随系统' : '自定义',
                                onChanged: (follow) {
                                  if (settings.largeText) {
                                    settings.setLargeText(false);
                                  }
                                  settings.setFollowSystemText(follow);
                                },
                              ),
                              if (!settings.followSystemText) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'A',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.text2,
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: settings.customTextScale,
                                        min: 0.9,
                                        max: 1.3,
                                        divisions: 8,
                                        label:
                                            '${(settings.customTextScale * 100).round()}%',
                                        onChanged: (value) {
                                          if (settings.largeText) {
                                            settings.setLargeText(false);
                                          }
                                          settings.setCustomTextScale(value);
                                        },
                                      ),
                                    ),
                                    Text(
                                      'A',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: colors.text2,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '应用内文字会放大到 ${(settings.customTextScale * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.text3,
                                  ),
                                ),
                              ] else
                                Text(
                                  settings.largeText
                                      ? '大字模式当前覆盖系统字号；切换缩放会关闭大字模式'
                                      : '跟随系统字体大小；可在系统设置中调整',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.text3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        const _SectionLabel(label: '液态玻璃与底栏'),
                        const SizedBox(height: Gaps.sm),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(
                            Gaps.lg,
                            Gaps.lg,
                            Gaps.lg,
                            Gaps.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ControlLabel('玻璃材质档位'),
                              const SizedBox(height: Gaps.sm),
                              Segmented<AppGlassPreference>(
                                values: AppGlassPreference.values,
                                selected: settings.glassPreference,
                                labelOf: (pref) => switch (pref) {
                                  AppGlassPreference.none => '纯色',
                                  AppGlassPreference.standard => '标准',
                                  AppGlassPreference.extreme => '极致折射',
                                },
                                onChanged: settings.setGlassPreference,
                              ),
                              const SizedBox(height: Gaps.lg),
                              const _ControlLabel('底部导航样式'),
                              const SizedBox(height: Gaps.sm),
                              Segmented<AppDockStyle>(
                                values: AppDockStyle.values,
                                selected: settings.dockStyle,
                                labelOf: (style) =>
                                    style == AppDockStyle.floating
                                    ? '悬浮玻璃'
                                    : '固定底栏',
                                onChanged: settings.setDockStyle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.xxl),
                      ],
                    ),
                  ),
                ],
              ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: PinnedSubHeader(title: '主题', onBack: onBack),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCustomColor(
    BuildContext context,
    AppSettings settings,
  ) async {
    await showCustomColorSheet(
      context,
      initialColor: settings.accentColor,
      colorStyle: settings.colorStyle,
      pureBlack: settings.pureBlack,
      floatingDock: settings.dockStyle == AppDockStyle.floating,
      onConfirmed: (color) => unawaited(settings.addAccentColor(color)),
    );
  }

  Future<void> _showEditColor(
    BuildContext context,
    AppSettings settings,
    Color original,
  ) async {
    await showCustomColorSheet(
      context,
      title: '编辑主题色',
      initialColor: original,
      colorStyle: settings.colorStyle,
      pureBlack: settings.pureBlack,
      floatingDock: settings.dockStyle == AppDockStyle.floating,
      onConfirmed: (edited) =>
          unawaited(settings.editAccentColor(original, edited)),
    );
  }

  Future<void> _confirmDeleteColor(
    BuildContext context,
    AppSettings settings,
    Color color,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除这个主题色？',
      description: '从色板中移除后，如仍需要可重新添加。',
      confirmLabel: '删除',
      danger: true,
    );
    if (ok == true) {
      await settings.removeAccentColor(color);
    }
  }

  Future<void> _confirmResetColors(
    BuildContext context,
    AppSettings settings,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: '恢复默认主题色？',
      description: '会还原默认色板、默认蓝色强调色与「鲜明」配色风格。',
      confirmLabel: '恢复默认',
      danger: true,
    );
    if (ok == true) {
      await settings.resetThemeColors();
    }
  }

  void _showSwatchMenu(
    BuildContext context, {
    required AppSettings settings,
    required Color color,
    required bool canDelete,
    required Offset globalPosition,
  }) {
    HapticFeedback.mediumImpact();
    unawaited(showDropletGlassMenu(
      context,
      anchorOffset: globalPosition,
      preferRightAlign: false,
      items: [
        GlassMenuAction(
          label: '编辑颜色',
          icon: Icons.tune_rounded,
          onSelected: () => unawaited(_showEditColor(context, settings, color)),
        ),
        if (canDelete)
          GlassMenuAction(
            label: '删除颜色',
            icon: Icons.delete_outline_rounded,
            danger: true,
            onSelected: () =>
                unawaited(_confirmDeleteColor(context, settings, color)),
          ),
      ],
    ));
  }
}

class _ThemePreview extends StatefulWidget {
  const _ThemePreview({required this.settings});

  final AppSettings settings;

  @override
  State<_ThemePreview> createState() => _ThemePreviewState();
}

class _ThemePreviewState extends State<_ThemePreview> {
  int _tabIndex = 0;
  int _direction = 1;
  late AppTabTransition _lastTransition = widget.settings.tabTransition;

  static const _icons = [
    Icons.schedule_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.insights_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    final next = widget.settings.tabTransition;
    if (next != _lastTransition) {
      _lastTransition = next;
      if (mounted) {
        setState(() {
          _direction = 1;
          _tabIndex = (_tabIndex + 1) % _icons.length;
        });
      }
    }
  }

  void _selectPreviewTab(int index) {
    if (index == _tabIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = index > _tabIndex ? 1 : -1;
      _tabIndex = index;
    });
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = widget.settings;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isSlide = settings.tabTransition == AppTabTransition.slide;
    return GlassCard(
      padding: const EdgeInsets.all(Gaps.md),
      child: AnimatedContainer(
        duration: motionDuration(Timings.base, disableAnimations: disable),
        curve: Curves2.out,
        height: 226,
        decoration: ShapeDecoration(
          color: colors.isDark ? colors.card : const Color(0xFFF8FAFC),
          shape: Radii.shape(Radii.xl),
          shadows: colors.isDark ? null : context.shadows.take(2).toList(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: Stack(
            children: [
              Positioned(
                top: -34,
                right: -26,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.26),
                        colors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '时页',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        const Spacer(),
                        _MiniPill(
                          color: colors.inset,
                          child: Text(
                            '2026年11月',
                            style: TextStyle(
                              fontSize: TypeScale.micro,
                              fontWeight: FontWeight.w600,
                              color: colors.text2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 13,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: motionDuration(
                            isSlide ? Timings.slow : Timings.fast,
                            disableAnimations: disable,
                          ),
                          switchInCurve: isSlide ? Curves2.out : Curves2.inOut,
                          switchOutCurve: isSlide ? Curves2.out : Curves2.inOut,
                          transitionBuilder: (child, animation) {
                            if (!isSlide) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            }
                            final incoming =
                                child.key == ValueKey('preview-tab-$_tabIndex');
                            final offset = Tween<Offset>(
                              begin: Offset(
                                (incoming ? _direction : -_direction) * 0.36,
                                0,
                              ),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: _buildTabBody(colors),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (settings.dockStyle == AppDockStyle.floating)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniPill(
                            color: settings.glassPreference ==
                                    AppGlassPreference.none
                                ? colors.card
                                : colors.inset,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < _icons.length; i++)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _selectPreviewTab(i),
                                    child: AnimatedContainer(
                                      duration: motionDuration(
                                        Timings.fast,
                                        disableAnimations: disable,
                                      ),
                                      curve: Curves2.out,
                                      width: i == _tabIndex ? 24 : 18,
                                      height: 20,
                                      margin: EdgeInsets.only(
                                        left: i == 0 ? 0 : 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: i == _tabIndex
                                            ? colors.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Icon(
                                        _icons[i],
                                        size: 11,
                                        color: i == _tabIndex
                                            ? colors.onPrimary
                                            : colors.text3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.divider, width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < _icons.length; i++)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectPreviewTab(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Icon(
                                    _icons[i],
                                    size: 13,
                                    color: i == _tabIndex
                                        ? colors.primary
                                        : colors.text3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(AppColors colors) {
    final accent = switch (_tabIndex) {
      1 => colors.income,
      2 => colors.warning,
      3 => colors.primary,
      _ => colors.primary,
    };
    return Column(
      key: ValueKey('preview-tab-$_tabIndex'),
      children: [
        Container(
          height: 70,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
          decoration: ShapeDecoration(
            color: colors.card,
            shape: Radii.shape(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 52,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.inset,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PreviewChartPainter(
                    color: accent,
                    grid: colors.divider,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.inset,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 24,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.inset,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _MiniBlock(
                color: _tabIndex == 1
                    ? colors.incomeSoft
                    : colors.primaryContainer,
                accent: _tabIndex == 1 ? colors.income : colors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MiniBlock(
                color: _tabIndex == 2
                    ? colors.warningSoft
                    : colors.incomeSoft,
                accent: _tabIndex == 2 ? colors.warning : colors.income,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewChartPainter extends CustomPainter {
  const _PreviewChartPainter({required this.color, required this.grid});

  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 3;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    final path = Path()
      ..moveTo(0, baseline - 6)
      ..cubicTo(
        size.width * .16,
        baseline - 20,
        size.width * .20,
        baseline - 2,
        size.width * .34,
        baseline - 12,
      )
      ..cubicTo(
        size.width * .46,
        baseline - 26,
        size.width * .51,
        baseline - 8,
        size.width * .63,
        baseline - 16,
      )
      ..cubicTo(
        size.width * .77,
        baseline - 30,
        size.width * .84,
        baseline - 9,
        size.width,
        baseline - 19,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PreviewChartPainter old) =>
      old.color != color || old.grid != grid;
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

class _MiniBlock extends StatelessWidget {
  const _MiniBlock({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(
            width: 30,
            height: 5,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final checkColor =
        color.computeLuminance() >= 0.42 ? const Color(0xFF18181C) : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: '主题色',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPressStart: onLongPress == null
            ? null
            : (details) => onLongPress!(details.globalPosition),
        child: Pressable(
          onTap: onTap,
          shape: const CircleBorder(),
          pressedScale: .88,
          child: AnimatedContainer(
            duration: motionDuration(Timings.micro, disableAnimations: disable),
            curve: Curves2.out,
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? .9 : .55),
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                duration: motionDuration(
                  Timings.micro,
                  disableAnimations: disable,
                ),
                curve: Curves2.out,
                scale: selected ? 1.0 : 0.0,
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: checkColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddColorDot extends StatelessWidget {
  const _AddColorDot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      shape: const CircleBorder(),
      pressedScale: .88,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.inset,
          border: Border.all(color: colors.divider),
        ),
        child: Icon(Icons.add_rounded, size: 18, color: colors.text2),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.text2,
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: context.colors.text,
      ),
    );
  }
}
