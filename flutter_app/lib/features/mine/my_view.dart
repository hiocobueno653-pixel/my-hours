import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/profiles.dart';
import '../../state/app_controller.dart';
import '../../ui/export_sheet.dart';
import '../../ui/month_picker.dart';
import '../../ui/page_route.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';
import '../ledger/category_manager.dart';
import '../work/budget_panel.dart';
import '../work/wage_panel.dart';
import 'backup_page.dart';
import 'settings_page.dart';
import 'theme_page.dart';

/// 我的页：工作时薪、工资结算、预算与数据备份管理中心。
class MyView extends ConsumerWidget {
  const MyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final month = ref.watch(selectedMonthProvider);
    final workProfiles = ref.watch(workProfilesProvider);
    final summary = ref.watch(currentMonthWorkSummaryProvider);
    final monthWork = ref.watch(currentMonthWorkViewDataProvider);
    final monthLedger = ref.watch(currentMonthLedgerViewDataProvider);
    final pay = monthWork.monthPay;
    final ledger = monthLedger.summary;
    final settlement = monthWork.settlement;
    final budget = ref.watch(budgetTargetsProvider);
    final defaultWork =
        getWorkById(workProfiles, defaultWorkId) ??
        (workProfiles.isEmpty ? null : workProfiles.first);
    final wageRatio = settlement.total <= 0
        ? 0.0
        : (settlement.settled / settlement.total).clamp(0.0, 1.0);

    final heroShape = Radii.shape(Radii.hero);
    return LiquidBackdropScaffold(
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          top: PinnedHeader.totalHeight(context) + 12,
          bottom: pageBottomInset(context),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: studioHeroDecoration(colors, radius: Radii.hero),
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: heroShape),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -42,
                          right: -28,
                          width: 196,
                          height: 196,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PassportArcWatermark(
                                lineColor: colors.outline.withValues(
                                  alpha: colors.isDark ? 0.14 : 0.22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  15,
                                  18,
                                  15,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Pressable(
                                          onTap: () async {
                                            final picked =
                                                await showMonthPicker(
                                                  context,
                                                  initialMonth: month,
                                                );
                                            if (picked != null &&
                                                context.mounted) {
                                              ref
                                                  .read(
                                                    selectedMonthProvider
                                                        .notifier,
                                                  )
                                                  .setMonth(picked);
                                            }
                                          },
                                          shape: Radii.pillShape,
                                          pressedScale: 0.96,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 5,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: colors.block,
                                              shape: Radii.pillShape,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AnimatedMonthLabel(
                                                  label: formatMonthLabel(
                                                    month,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.text,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                Icon(
                                                  Icons.unfold_more_rounded,
                                                  size: 14,
                                                  color: colors.text3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'TIMEPAGE · 月度总览',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0,
                                            color: colors.text3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    IntrinsicHeight(
                                      child: Row(
                                        children: [
                                          _MiniMetric(
                                            label: context.unit.quantity,
                                            numericValue: summary.totalHours,
                                            formatter: (v) =>
                                                formatHoursValue(v.toDouble()),
                                            unit: context.unit.short,
                                            color: colors.text,
                                            labelColor: colors.text3,
                                          ),
                                          if (!kHoursOnly) ...[
                                            Container(
                                              width: 0.7,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              color: colors.divider,
                                            ),
                                            _MiniMetric(
                                              label: '工资',
                                              numericValue: pay,
                                              formatter: (v) => formatAmount(
                                                v.toDouble(),
                                                withSymbol: true,
                                              ),
                                              color: colors.text,
                                              labelColor: colors.text3,
                                            ),
                                            Container(
                                              width: 0.7,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              color: colors.divider,
                                            ),
                                            _MiniMetric(
                                              label: '结余',
                                              numericValue: ledger.balance,
                                              formatter: (v) => formatAmount(
                                                v.toDouble(),
                                                withSymbol: true,
                                              ),
                                              color: ledger.balance >= 0
                                                  ? colors.text
                                                  : colors.expense,
                                              labelColor: colors.text3,
                                            ),
                                          ] else ...[
                                            Container(
                                              width: 0.7,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 3,
                                                  ),
                                              color: colors.divider,
                                            ),
                                            _MiniMetric(
                                              label: '出勤天数',
                                              numericValue: summary.workDays,
                                              formatter: (v) => '${v.round()}',
                                              unit: '天',
                                              color: colors.text,
                                              labelColor: colors.text3,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!kHoursOnly) ...[
                                Divider(
                                  height: 1,
                                  thickness: 0.7,
                                  color: colors.divider,
                                ),
                                ColoredBox(
                                  color: colors.heroWell,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      11,
                                      18,
                                      13,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '本月工资结算 ${(wageRatio * 100).round()}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: colors.text2,
                                                fontFeatures: tabularFigures,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '已结 ${formatAmount(settlement.settled, withSymbol: true)}'
                                              ' · 待结 ${formatAmount(settlement.pending, withSymbol: true)}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: colors.text3,
                                                fontFeatures: tabularFigures,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        ProgressBar(
                                          ratio: wageRatio,
                                          color: colors.income,
                                          height: 4.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gaps.lg),
                SectionHeading(
                  title: context.unit.id == 'hours'
                      ? '记工与账务'
                      : '${context.unit.quantity}与账务',
                ),
                if (!kHoursOnly)
                  Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _AtelierWorkspaceTile(
                                title: '工作与${context.unit.rateName}',
                                subtitle:
                                    defaultWork == null ||
                                        defaultWork.hourlyRate <= 0
                                    ? '点此配置默认${context.unit.rateName}'
                                    : '${defaultWork.name} · ¥${formatRate(defaultWork.hourlyRate)}/${context.unit.rateShort}',
                                badge: '${workProfiles.length} 项',
                                icon: Icons.work_outline_rounded,
                                accent: colors.primary,
                                onTap: () => showWorkManager(context),
                              ),
                            ),
                            const SizedBox(width: Gaps.cardGap),
                            Expanded(
                              child: _AtelierWorkspaceTile(
                                title: '工资结算明细',
                                subtitle: settlement.pending > 0
                                    ? '待结 ${formatAmount(settlement.pending, withSymbol: true)}'
                                    : '全部工资已结清',
                                badge: settlement.pending > 0 ? '待结' : '已清',
                                badgeColor: settlement.pending > 0
                                    ? colors.warning
                                    : colors.income,
                                badgeBg: settlement.pending > 0
                                    ? colors.warningSoft
                                    : colors.incomeSoft,
                                icon: Icons.payments_outlined,
                                accent: colors.income,
                                onTap: () => showWagePanel(context, month),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gaps.cardGap),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _AtelierWorkspaceTile(
                                title: '预算与月目标',
                                subtitle: budget.monthlyExpenseBudget > 0
                                    ? '上限 ${formatAmount(budget.monthlyExpenseBudget, withSymbol: true)}'
                                    : '设置支出上限与目标',
                                badge: budget.monthlyExpenseBudget > 0
                                    ? '已启用'
                                    : '未设',
                                badgeColor: budget.monthlyExpenseBudget > 0
                                    ? colors.primary
                                    : null,
                                badgeBg: budget.monthlyExpenseBudget > 0
                                    ? colors.primaryContainer
                                    : null,
                                icon: Icons.track_changes_rounded,
                                accent: colors.warning,
                                onTap: () => showBudgetPanel(context),
                              ),
                            ),
                            const SizedBox(width: Gaps.cardGap),
                            Expanded(
                              child: _AtelierWorkspaceTile(
                                title: '账目分类管理',
                                subtitle: '管理收支图标与分类',
                                badge: '自定义',
                                icon: Icons.sell_outlined,
                                accent: const Color(0xFF6E56CF),
                                onTap: () => showCategoryManager(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListRow(
                      title: '工作类型管理',
                      subtitle: '共 ${workProfiles.length} 项工作',
                      leading: AppIconBadge(
                        icon: Icons.work_outline_rounded,
                        color: colors.primary,
                        tinted: true,
                      ),
                      showChevron: true,
                      onTap: () => showWorkManager(context),
                    ),
                  ),
                const SizedBox(height: Gaps.lg),
                const SectionHeading(title: '数据与安全'),
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      ListRow(
                        title: '数据与备份',
                        subtitle: 'JSON 备份导出、恢复与自动快照',
                        leading: const AppIconBadge(
                          icon: Icons.inventory_2_outlined,
                          color: Color(0xFF5856D6),
                        ),
                        showChevron: true,
                        onTap: () => _openSubpage(
                          context,
                          (close) => BackupPage(onBack: close),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: colors.divider,
                        indent: 64,
                        endIndent: 16,
                      ),
                      ListRow(
                        title: '导出月度报表',
                        subtitle: '生成 CSV 表格分享或归档',
                        leading: const AppIconBadge(
                          icon: Icons.download_rounded,
                          color: Color(0xFF0EA5E9),
                        ),
                        showChevron: true,
                        onTap: () => showExportSheet(
                          context,
                          month: month,
                          records: ref.read(recordsProvider),
                          entries: ref.read(entriesProvider),
                          includeLedger: !kHoursOnly,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gaps.lg),
                const SectionHeading(title: '个性化与系统'),
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      ListRow(
                        title: '主题与外观',
                        subtitle: '主题色彩、深色模式与字体缩放',
                        leading: const AppIconBadge(
                          icon: Icons.palette_outlined,
                          color: Color(0xFFEC4899),
                        ),
                        showChevron: true,
                        onTap: () => _openSubpage(
                          context,
                          (close) => ThemePage(onBack: close),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: colors.divider,
                        indent: 64,
                        endIndent: 16,
                      ),
                      ListRow(
                        title: '使用设置',
                        subtitle: '计量单位、实时通知、动效与重置',
                        leading: const AppIconBadge(
                          icon: Icons.tune_rounded,
                          color: Color(0xFF64748B),
                        ),
                        showChevron: true,
                        onTap: () => _openSubpage(
                          context,
                          (close) => SettingsPage(onBack: close),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gaps.xl),
                Center(
                  child: Text(
                    '时页 TIMEPAGE · 1.8.0 · 数据完全本地保存',
                    style: TextStyle(fontSize: 11.5, color: colors.text3),
                  ),
                ),
                const SizedBox(height: Gaps.sm),
              ],
            ),
          ),
        ],
      ),
      overlays: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PinnedHeader(
            title: '我的',
            actions: [
              HeaderGlassSurface(
                height: 36,
                radius: Radii.pill,
                bright: true,
                interactive: true,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: colors.income,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '仅本机',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: colors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _openSubpage(
  BuildContext context,
  Widget Function(VoidCallback close) builder,
) {
  final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  Navigator.of(context).push(
    AppCardPageRoute<void>(
      disableAnimations: disable,
      builder: (pageContext) =>
          builder(() => Navigator.of(pageContext).maybePop()),
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.numericValue,
    required this.formatter,
    required this.color,
    this.unit,
    this.labelColor,
  });

  final String label;
  final num numericValue;
  final String Function(num value) formatter;
  final Color color;
  final String? unit;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: labelColor ?? colors.text3),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumericText(
                  value: numericValue,
                  formatter: formatter,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: color,
                  ),
                ),
                if (unit != null && unit!.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.text3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2×2 核心工作台瓷格：打破全屏长列表的单调感，让高频工具一眼触达。
class _AtelierWorkspaceTile extends StatelessWidget {
  const _AtelierWorkspaceTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badgeColor,
    this.badgeBg,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final Color? badgeColor;
  final Color? badgeBg;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      radius: Radii.card,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: icon,
                color: accent,
                size: 32,
                iconSize: 17,
                tinted: true,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: ShapeDecoration(
                  color:
                      badgeBg ??
                      colors.block.withValues(
                        alpha: colors.isDark ? 0.85 : 0.72,
                      ),
                  shape: Radii.pillShape,
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: badgeColor ?? colors.text2,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: colors.text3,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// 护照卡背景精密同心弧纹 + 主题微光：模拟高级腕表底盖蚀刻线条，极轻不抢主读数。
class _PassportArcWatermark extends CustomPainter {
  const _PassportArcWatermark({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.65, size.height * 0.35);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = lineColor;
    for (final radius in const [44.0, 68.0, 92.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.45,
        math.pi * 0.92,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PassportArcWatermark old) => old.lineColor != lineColor;
}
