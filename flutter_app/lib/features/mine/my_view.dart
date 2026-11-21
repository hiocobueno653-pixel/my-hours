import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/ledger.dart';
import '../../data/profiles.dart';
import '../../data/records.dart';
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
    final state = ref.watch(appControllerProvider);
    final month = ref.watch(selectedMonthProvider);
    final summary = getMonthSummary(state.records, month);
    final pay = getMonthPay(state.records, month, state.workProfiles);
    final ledger = getLedgerMonthSummary(state.entries, month);
    final settlement = getSettlementSummary(
      state.records,
      month,
      state.workProfiles,
    );
    final budget = ref.watch(budgetTargetsProvider);
    final defaultWork =
        getWorkById(state.workProfiles, defaultWorkId) ??
        (state.workProfiles.isEmpty ? null : state.workProfiles.first);
    final wageRatio = settlement.total <= 0
        ? 0.0
        : (settlement.settled / settlement.total).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
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
                    GlassCard(
                      radius: Radii.hero,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Pressable(
                                onTap: () async {
                                  final picked = await showMonthPicker(
                                    context,
                                    initialMonth: month,
                                  );
                                  if (picked != null && context.mounted) {
                                    ref
                                        .read(selectedMonthProvider.notifier)
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
                                        label: formatMonthLabel(month),
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
                                '月度总览',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.text3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _MiniMetric(
                                label: context.unit.quantity,
                                numericValue: summary.totalHours,
                                formatter: (v) =>
                                    '${formatHoursValue(v.toDouble())}${context.unit.short}',
                                color: colors.primary,
                              ),
                              if (!kHoursOnly) ...[
                                _MiniMetric(
                                  label: '工资',
                                  numericValue: pay,
                                  formatter: (v) => formatAmount(
                                    v.toDouble(),
                                    withSymbol: true,
                                  ),
                                  color: colors.income,
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
                                ),
                              ] else
                                _MiniMetric(
                                  label: '出勤天数',
                                  numericValue: summary.workDays,
                                  formatter: (v) => '${v.round()} 天',
                                  color: colors.income,
                                ),
                            ],
                          ),
                          if (!kHoursOnly) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: ShapeDecoration(
                                color: colors.block.withValues(
                                  alpha: colors.isDark ? 0.62 : 0.72,
                                ),
                                shape: Radii.shape(Radii.md),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '本月工资结算',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text2,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: colors.incomeSoft,
                                          shape: Radii.pillShape,
                                        ),
                                        child: Text(
                                          '${(wageRatio * 100).round()}%',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: colors.income,
                                            fontFeatures: tabularFigures,
                                          ),
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
                                  const SizedBox(height: 6),
                                  ProgressBar(
                                    ratio: wageRatio,
                                    color: colors.income,
                                    height: 4.5,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.lg),
                    SectionHeading(
                      title: context.unit.id == 'hours'
                          ? '记工与账务'
                          : '${context.unit.quantity}与账务',
                    ),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          if (!kHoursOnly) ...[
                            ListRow(
                              title: '工作与${context.unit.rateName}',
                              subtitle: defaultWork == null ||
                                      defaultWork.hourlyRate <= 0
                                  ? '未设置默认${context.unit.rateName}，点此配置'
                                  : '${defaultWork.name} · ¥${formatRate(defaultWork.hourlyRate)}/${context.unit.rateShort}'
                                        '${state.workProfiles.length > 1 ? '（共 ${state.workProfiles.length} 项）' : ''}',
                              leading: AppIconBadge(
                                icon: Icons.work_outline_rounded,
                                color: colors.primary,
                              ),
                              showChevron: true,
                              onTap: () => showWorkManager(context),
                            ),
                            Divider(
                              height: 1,
                              color: colors.divider,
                              indent: 64,
                              endIndent: 16,
                            ),
                            ListRow(
                              title: '工资结算明细',
                              subtitle: settlement.pending > 0
                                  ? '还有 ${formatAmount(settlement.pending, withSymbol: true)} 待结算'
                                  : '批量标记已结算并同步入账',
                              leading: AppIconBadge(
                                icon: Icons.payments_outlined,
                                color: colors.income,
                              ),
                              showChevron: true,
                              onTap: () => showWagePanel(context, month),
                            ),
                            Divider(
                              height: 1,
                              color: colors.divider,
                              indent: 64,
                              endIndent: 16,
                            ),
                            ListRow(
                              title: '预算与月目标',
                              subtitle: budget.monthlyExpenseBudget > 0
                                  ? '月支出预算 ${formatAmount(budget.monthlyExpenseBudget, withSymbol: true)}'
                                  : '设置月支出上限与收入目标',
                              leading: AppIconBadge(
                                icon: Icons.track_changes_rounded,
                                color: colors.warning,
                              ),
                              showChevron: true,
                              onTap: () => showBudgetPanel(context),
                            ),
                            Divider(
                              height: 1,
                              color: colors.divider,
                              indent: 64,
                              endIndent: 16,
                            ),
                            ListRow(
                              title: '账目分类管理',
                              subtitle: '管理自定义收支分类',
                              leading: const AppIconBadge(
                                icon: Icons.sell_outlined,
                                color: Color(0xFFAF52DE),
                              ),
                              showChevron: true,
                              onTap: () => showCategoryManager(context),
                            ),
                          ] else
                            ListRow(
                              title: '工作类型管理',
                              subtitle: '共 ${state.workProfiles.length} 项工作',
                              leading: AppIconBadge(
                                icon: Icons.work_outline_rounded,
                                color: colors.primary,
                              ),
                              showChevron: true,
                              onTap: () => showWorkManager(context),
                            ),
                        ],
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
                              records: state.records,
                              entries: state.entries,
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
                        '时页 TIMEPAGE · 1.7.6 · 数据完全本地保存',
                        style: TextStyle(fontSize: 11.5, color: colors.text3),
                      ),
                    ),
                    const SizedBox(height: Gaps.sm),
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
          child: PinnedHeader(
            title: '我的',
            actions: [
              HeaderGlassSurface(
                height: 40,
                radius: Radii.pill,
                bright: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: colors.income,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '仅本机',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
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
  });

  final String label;
  final num numericValue;
  final String Function(num value) formatter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text3)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedNumericText(
              value: numericValue,
              formatter: formatter,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
