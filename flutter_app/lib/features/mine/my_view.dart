import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';
import '../../data/dates.dart';
import '../../data/ledger.dart';
import '../../data/records.dart';
import '../../state/app_controller.dart';
import '../../ui/month_picker.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import '../ledger/category_manager.dart';
import '../charts/charts.dart';
import '../work/budget_panel.dart';
import '../work/wage_panel.dart';
import 'backup_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'theme_page.dart';

/// 我的页：数据带 + 功能入口。二级页走 Navigator（返回键与手势由路由负责）。
class MyView extends ConsumerWidget {
  const MyView({
    super.key,
    required this.largeText,
    required this.onLargeTextChanged,
  });

  final bool largeText;
  final ValueChanged<bool> onLargeTextChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final month = ref.watch(selectedMonthProvider);
    final hours = getMonthSummary(state.records, month).totalHours;
    final pay = getMonthPay(state.records, month, state.workProfiles);
    final ledger = getLedgerMonthSummary(state.entries, month);
    final settlement = getSettlementSummary(
      state.records,
      month,
      state.workProfiles,
    );
    final monthDelta = getMonthDelta(state.records, month);
    final budget = ref.watch(budgetTargetsProvider);
    final wageRatio = settlement.total <= 0
        ? 0.0
        : settlement.settled / settlement.total;
    final budgetRatio = budget.monthlyExpenseBudget <= 0
        ? 0.0
        : ledger.expense / budget.monthlyExpenseBudget;
    final goalRatio = budget.monthlyIncomeGoal <= 0
        ? 0.0
        : ledger.income / budget.monthlyIncomeGoal;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.only(
              top: PinnedHeader.totalHeight(context) + 8,
              bottom: pageBottomInset(context),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
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
                                shape: Radii.shape(Radii.sm),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedMonthLabel(
                                        label: formatMonthLabel(month),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text2,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.expand_more_rounded,
                                        size: 17,
                                        color: colors.text3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (monthDelta != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${monthDelta.delta >= 0 ? '↑' : '↓'} 比上月 '
                              '${monthDelta.delta >= 0 ? '+' : ''}'
                              '${formatHoursValue(monthDelta.delta.abs())} 小时'
                              '（${monthDelta.percent >= 0 ? '+' : ''}${monthDelta.percent}%）',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: monthDelta.delta >= 0
                                    ? colors.income
                                    : colors.expense,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ],
                          const SizedBox(height: Gaps.md),
                          Row(
                            children: [
                              _MiniMetric(
                                label: '工时',
                                value: formatHoursValue(hours),
                                color: colors.accent,
                              ),
                              _MiniMetric(
                                label: '工资',
                                value: formatAmount(pay),
                                color: colors.income,
                              ),
                              _MiniMetric(
                                label: '结余',
                                value: formatAmount(ledger.balance),
                                color: ledger.balance >= 0
                                    ? colors.text
                                    : colors.expense,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.md),
                    if (!kHoursOnly) ...[
                      GlassCard(
                        onTap: () => showWagePanel(context, month),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '本月工资',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '结算明细',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.text3,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: colors.text3,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatAmount(pay),
                                  style: TextStyle(
                                    fontSize: 26,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.02,
                                    color: colors.income,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 3,
                                    bottom: 2,
                                  ),
                                  child: Text(
                                    '元',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: colors.text2,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '待结算 ${formatAmount(settlement.pending)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.text2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ProgressBar(
                              ratio: wageRatio,
                              color: colors.income,
                              height: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gaps.md),
                      GlassCard(
                        onTap: () => showBudgetPanel(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '预算与目标',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text2,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: colors.text3,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _BudgetMiniRow(
                              label: '支出',
                              value: ledger.expense,
                              target: budget.monthlyExpenseBudget,
                              ratio: budgetRatio,
                              color: colors.expense,
                            ),
                            const SizedBox(height: 8),
                            _BudgetMiniRow(
                              label: '收入',
                              value: ledger.income,
                              target: budget.monthlyIncomeGoal,
                              ratio: goalRatio,
                              color: colors.income,
                              invert: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gaps.md),
                    ],
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                      child: Column(
                        children: [
                          ListRow(
                            title: '年度统计',
                            subtitle: '全年工时/工资趋势、收支与分类占比',
                            showChevron: true,
                            onTap: () => _push(
                              context,
                              StatsPage(
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: colors.divider),
                          ListRow(
                            title: '数据与备份',
                            subtitle: '导出 / 导入 / 迁移对账',
                            showChevron: true,
                            onTap: () => _push(
                              context,
                              BackupPage(
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: colors.divider),
                          ListRow(
                            title: '主题与外观',
                            subtitle: '主题色、液态玻璃、底栏与文本缩放',
                            showChevron: true,
                            onTap: () => _push(
                              context,
                              ThemePage(
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: colors.divider),
                          ListRow(
                            title: '分类管理',
                            subtitle: '默认分类与自定义分类',
                            showChevron: true,
                            onTap: () => showCategoryManager(context),
                          ),
                          Divider(height: 1, color: colors.divider),
                          ListRow(
                            title: '使用设置',
                            subtitle: '深色模式、大字、动效、清空数据',
                            showChevron: true,
                            onTap: () => _push(
                              context,
                              SettingsPage(
                                onBack: () => Navigator.of(context).pop(),
                                largeText: largeText,
                                onLargeTextChanged: onLargeTextChanged,
                              ),
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
          child: PinnedHeader(
            title: '我的',
            actions: [
              HeaderGlassSurface(
                height: 30,
                radius: 15,
                bright: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 13,
                      color: colors.text2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '仅本机',
                      style: TextStyle(fontSize: 11, color: colors.text2),
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

  void _push(BuildContext context, Widget page) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: motionDuration(
          Timings.medium,
          disableAnimations: disable,
        ),
        reverseTransitionDuration: motionDuration(
          Timings.short,
          disableAnimations: disable,
        ),
        pageBuilder: (routeContext, _, _) => Scaffold(
          backgroundColor: routeContext.colors.bg,
          body: SafeArea(top: false, child: page),
        ),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves2.out);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02,
                color: color,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetMiniRow extends StatelessWidget {
  const _BudgetMiniRow({
    required this.label,
    required this.value,
    required this.target,
    required this.ratio,
    required this.color,
    this.invert = false,
  });

  final String label;
  final double value;
  final double target;
  final double ratio;
  final Color color;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasTarget = target > 0;
    final reached = invert ? ratio >= 1 : ratio > 1;
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: colors.text2)),
            const Spacer(),
            Text(
              hasTarget
                  ? '${formatAmount(value)} / ${formatAmount(target)}'
                  : '未设置',
              style: TextStyle(
                fontSize: 11.5,
                color: reached ? color : colors.text2,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ProgressBar(
          ratio: hasTarget ? ratio : 0,
          color: reached ? color : colors.primary,
          height: 4,
        ),
      ],
    );
  }
}
