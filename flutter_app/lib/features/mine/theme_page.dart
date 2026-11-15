import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../core/theme_tokens.dart';
import '../../ui/pinned_header.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';

/// 主题与外观。版式参考系统主题页：顶部实时预览 + 分区设置卡片。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key, required this.onBack});

  final VoidCallback onBack;

  static const _presets = <Color>[
    Color(0xFF2563EB),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFFACC15),
    Color(0xFF22C55E),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final colors = context.colors;
        return Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.only(
                  top: PinnedSubHeader.totalHeight(context) + 8,
                  bottom: 48,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gaps.lg,
                            vertical: 2,
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: settings.pureBlack,
                              onChanged: settings.setPureBlack,
                              title: const Text('纯黑模式'),
                              subtitle: const Text('深色模式下使用纯黑页面与深色卡片'),
                            ),
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        const _SectionLabel(label: '主题色彩'),
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
                                  for (final color in _presets)
                                    _ColorDot(
                                      color: color,
                                      selected:
                                          color.toARGB32() ==
                                          settings.accentColor.toARGB32(),
                                      onTap: () =>
                                          settings.setAccentColor(color),
                                    ),
                                  _AddColorDot(
                                    onTap: () => _showCustomColor(
                                      context,
                                      settings,
                                    ),
                                  ),
                                ],
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
                              Segmented<AppColorStyle>(
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
                              const _ControlLabel('底栏'),
                              const SizedBox(height: Gaps.sm),
                              Segmented<AppDockStyle>(
                                values: AppDockStyle.values,
                                selected: settings.dockStyle,
                                labelOf: (style) =>
                                    style == AppDockStyle.floating
                                    ? '悬浮'
                                    : '固定',
                                onChanged: settings.setDockStyle,
                              ),
                              const SizedBox(height: Gaps.lg),
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
                              const SizedBox(height: Gaps.lg),
                              const _ControlLabel('液态玻璃'),
                              const SizedBox(height: Gaps.sm),
                              Segmented<AppGlassPreference>(
                                values: AppGlassPreference.values,
                                selected: settings.glassPreference,
                                labelOf: (value) => switch (value) {
                                  AppGlassPreference.none => '无',
                                  AppGlassPreference.standard => '标准',
                                  AppGlassPreference.extreme => '极致',
                                },
                                onChanged: settings.setGlassPreference,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '无：只保留磨砂；标准：按设备能力；极致：强制折射（较耗电）',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: colors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        const _SectionLabel(label: '字体与阅读'),
                        const SizedBox(height: Gaps.sm),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gaps.lg,
                            vertical: 2,
                          ),
                          child: ListRow(
                            title: '字体',
                            subtitle: '系统默认字体 · 保持现有字形不变',
                            leading: Icon(
                              Icons.text_fields_rounded,
                              color: colors.text2,
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
                                labelOf: (follow) =>
                                    follow ? '跟随系统' : '自定义',
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
        );
      },
    );
  }

  Future<void> _showCustomColor(
    BuildContext context,
    AppSettings settings,
  ) async {
    final choice = await showAppSheet<Color>(
      context: context,
      builder: (sheetContext) => SheetScaffold(
        title: '自定义主题色',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择一个颜色，主题会立即更新。',
              style: TextStyle(
                fontSize: 13,
                color: sheetContext.colors.text2,
              ),
            ),
            const SizedBox(height: Gaps.lg),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final color in const [
                  Color(0xFF0EA5E9),
                  Color(0xFF14B8A6),
                  Color(0xFF84CC16),
                  Color(0xFFF43F5E),
                  Color(0xFFA855F7),
                  Color(0xFF475569),
                ])
                  _ColorDot(
                    color: color,
                    selected: false,
                    onTap: () => Navigator.of(sheetContext).pop(color),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice != null) await settings.setAccentColor(choice);
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      padding: const EdgeInsets.all(Gaps.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
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
                          '记工',
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
                              fontSize: 9,
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
                    Container(
                      height: 72,
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
                                  color: colors.primary,
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
                                  color: colors.primary.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 29,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _PreviewChartPainter(
                                color: colors.primary,
                                grid: colors.divider,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
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
                            color: colors.primaryContainer,
                            accent: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _MiniBlock(
                            color: colors.incomeSoft,
                            accent: colors.income,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MiniPill(
                          color: colors.inset,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
                                  color: colors.onPrimary,
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 14,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.text3.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: colors.text3.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '主题色',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: const CircleBorder(),
        pressedScale: .88,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.text : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .8),
                width: 1.5,
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
