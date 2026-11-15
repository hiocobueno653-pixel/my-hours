import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/models.dart';
import '../../data/profiles.dart';
import '../../data/records.dart';
import '../../state/app_controller.dart';
import '../charts/charts.dart';
import '../../ui/dialog.dart';
import '../../ui/export_sheet.dart';
import '../../ui/month_picker.dart';
import '../../ui/pinned_header.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import '../ledger/ledger_view.dart';
import 'budget_panel.dart';
import 'month_detail.dart';
import 'wage_panel.dart';

/// 记工页：今天卡 + 月汇总 + 日历。
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key, this.onOpenLedger});

  /// 「记一笔」跳到记账页并预填日期（只记工时变体为 null）。
  final void Function(String date)? onOpenLedger;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  double _dragDx = 0;
  bool _dayFlowOpen = false;

  Future<void> _openDay(String date) async {
    if (_dayFlowOpen) return;
    _dayFlowOpen = true;
    try {
      final state = ref.read(appControllerProvider);
      final record = getRecordByDate(state.records, date);
      if (record == null) {
        await showDayEditor(context, date);
      } else {
        final edit = await showDayDetail(context, record);
        if (edit == true && mounted) {
          await showDayEditor(context, record.date, record: record);
        }
      }
    } finally {
      _dayFlowOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final month = ref.watch(selectedMonthProvider);
    final today = todayISO();
    final todayRecord = getRecordByDate(state.records, today);
    final summary = getMonthSummary(state.records, month);
    final monthPay = getMonthPay(state.records, month, state.workProfiles);
    final settlement = getSettlementSummary(
      state.records,
      month,
      state.workProfiles,
    );
    final monthDelta = getMonthDelta(state.records, month);
    final todayEntries = [
      for (final entry in state.entries)
        if (entry.date == today) entry,
    ];
    var todayIncome = 0.0;
    var todayExpense = 0.0;
    for (final entry in todayEntries) {
      if (entry.type == LedgerType.income) {
        todayIncome += entry.amount;
      } else {
        todayExpense += entry.amount;
      }
    }
    final deltaText = monthDelta == null
        ? null
        : '${monthDelta.delta >= 0 ? '↑' : '↓'} 比上月 '
              '${monthDelta.delta >= 0 ? '+' : ''}'
              '${formatHoursValue(monthDelta.delta.abs())} 小时'
              '（${monthDelta.percent >= 0 ? '+' : ''}${monthDelta.percent}%）';
    final dates = getMonthDates(month);
    // 真实工作日数（周一至周五）。硬编码 22 会让百分比偏离实际值。
    // 用 parseMonthKey 而不是 substring + int.parse：后者遇到 `999-12`
    // 这类异常月份键会在 substring(0, 4) 上抛 FormatException，直接打挂整页。
    final parsedMonth = parseMonthKey(month);
    final workdays = parsedMonth == null
        ? 0
        : workdaysInMonth(parsedMonth.year, parsedMonth.month);
    // 记了工时却算不出钱的天数：只可能是缺时薪（或时长与日薪都为 0）。
    final underpaidDays = [
      for (final record in getMonthRecords(state.records, month))
        if (record.hours > 0 && recordPay(record, state.workProfiles) <= 0)
          record,
    ].length;
    final recordsByDate = {
      for (final record in state.records)
        if (record.date.startsWith('$month-')) record.date: record,
    };
    final entriesByDate = <String, List<LedgerEntry>>{};
    for (final entry in state.entries) {
      if (!entry.date.startsWith('$month-')) continue;
      entriesByDate.putIfAbsent(entry.date, () => []).add(entry);
    }

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
                    if (month == currentMonthKey()) ...[
                      TodayCard(
                        date: today,
                        record: todayRecord,
                        profiles: state.workProfiles,
                        income: todayIncome,
                        expense: todayExpense,
                        entryCount: todayEntries.length,
                        onOpenLedger: widget.onOpenLedger == null
                            ? null
                            : () => widget.onOpenLedger!(today),
                        onTap: () => _openDay(today),
                      ),
                      if (todayEntries.isNotEmpty) ...[
                        const SizedBox(height: Gaps.md),
                        _TodayLedgerCard(entries: todayEntries),
                      ],
                      const SizedBox(height: Gaps.md),
                    ] else
                      // 非当前月不渲染「今天」工作区：否则上面是今天的账、
                      // 下面是所选月的日历，两套时间语境会互相误导。
                      _PastMonthBanner(
                        month: month,
                        onTap: () => ref
                            .read(selectedMonthProvider.notifier)
                            .setMonth(currentMonthKey()),
                      ),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _MetricCard(
                              label: '本月工时',
                              value: formatHoursValue(summary.totalHours),
                              unit: '小时',
                              accent: colors.accent,
                              footer:
                                  '工作 ${summary.workDays} 天 · 日均 ${formatHoursValue(summary.averageHours)}',
                              progress: workdays <= 0
                                  ? 0.0
                                  : (summary.workDays / workdays).clamp(
                                      0.0,
                                      1.0,
                                    ),
                              delta: deltaText,
                              deltaColor:
                                  monthDelta != null && monthDelta.delta >= 0
                                  ? colors.income
                                  : colors.expense,
                              onTap: () => showMonthDetail(context, month),
                            ),
                          ),
                          const SizedBox(width: Gaps.md),
                          Expanded(
                            flex: 2,
                            child: _MetricCard(
                              label: '本月工资',
                              value: formatAmount(monthPay),
                              unit: '元',
                              accent: colors.income,
                              footer: '待结算 ${formatAmount(settlement.pending)}',
                              onTap: () => showWagePanel(context, month),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 有工时却没算出工资 = 记录缺时薪。不提示的话用户只会看到
                    // 一个恒为 0 的「本月工资」，很难自己想明白是缺时薪。
                    // 只记工时变体没有工资概念，不提示。
                    if (!kHoursOnly && underpaidDays > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: Gaps.md),
                        child: _MissingRateHint(
                          days: underpaidDays,
                          onTap: () => showWorkManager(context),
                        ),
                      ),
                    const SizedBox(height: Gaps.md),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) => _dragDx = 0,
                      onHorizontalDragUpdate: (details) {
                        _dragDx += details.delta.dx;
                      },
                      onHorizontalDragEnd: (_) {
                        if (_dragDx.abs() < 50) return;
                        final next = shiftMonth(month, _dragDx < 0 ? 1 : -1);
                        ref.read(selectedMonthProvider.notifier).setMonth(next);
                      },
                      child: _CalendarCard(
                        month: month,
                        dates: dates,
                        records: recordsByDate,
                        entriesByDate: entriesByDate,
                        today: today,
                        onTapDate: _openDay,
                        onOpenDetail: () => showMonthDetail(context, month),
                      ),
                    ),
                    const SizedBox(height: Gaps.md),
                    _QuickActions(
                      onOpenLedger: widget.onOpenLedger,
                      onOpenBudget: () => showBudgetPanel(context),
                      onOpenWorks: () => showWagePanel(context, month),
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
            title: '记工',
            actions: [
              _MonthSwitch(
                month: month,
                onChanged: (value) =>
                    ref.read(selectedMonthProvider.notifier).setMonth(value),
                onPick: () async {
                  final picked = await showMonthPicker(
                    context,
                    initialMonth: month,
                  );
                  if (picked != null && context.mounted) {
                    ref.read(selectedMonthProvider.notifier).setMonth(picked);
                  }
                },
              ),
              BarActionButton(
                icon: Icons.download_rounded,
                tooltip: '导出本月数据',
                bright: true,
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
      ],
    );
  }
}

class _MonthSwitch extends StatelessWidget {
  const _MonthSwitch({
    required this.month,
    required this.onChanged,
    required this.onPick,
  });

  final String month;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HeaderGlassSurface(
      height: 44,
      radius: 22,
      bright: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthStepButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: '上个月',
            onTap: () => onChanged(shiftMonth(month, -1)),
          ),
          Pressable(
            onTap: onPick,
            shape: Radii.pillShape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedMonthLabel(
                    label: formatMonthLabel(month),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: colors.text3,
                  ),
                ],
              ),
            ),
          ),
          _MonthStepButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: '下个月',
            onTap: () => onChanged(shiftMonth(month, 1)),
          ),
        ],
      ),
    );
  }
}

class _MonthStepButton extends StatelessWidget {
  const _MonthStepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.pillShape,
        pressedScale: 0.92,
        child: SizedBox(
          width: 38,
          height: 44,
          child: Icon(icon, size: 18, color: context.colors.text2),
        ),
      ),
    );
  }
}

/// 非当前月的顶部提示条，用来替代「今天」工作区。
///
/// 不显示今天卡片是刻意的：否则页面顶部是今天的工资与账目、下方是所选月的
/// 日历，用户点「修改记录」改的却是今天，编辑目标与所见月份错位。
class _PastMonthBanner extends StatelessWidget {
  const _PastMonthBanner({required this.month, required this.onTap});

  final String month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '正在查看${formatMonthLabel(month)}，回到本月',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.shape(Radii.md),
        pressedScale: 0.98,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: ShapeDecoration(
            // inset 而不是 block：浅色下 block 与页底同色，提示条会隐形。
            color: colors.inset,
            shape: Radii.shape(Radii.md),
          ),
          child: Row(
            children: [
              Icon(Icons.today_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '正在查看 ${formatMonthLabel(month)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: colors.text2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '回到本月',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 有工时但没有时薪时的引导条：把「工资恒为 0」变成一个可点的下一步。
class _MissingRateHint extends StatelessWidget {
  const _MissingRateHint({required this.days, required this.onTap});

  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '$days 天有工时但未设时薪，去设置时薪',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.shape(Radii.md),
        pressedScale: 0.98,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: ShapeDecoration(
            color: colors.primaryContainer,
            shape: Radii.shape(Radii.md),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$days 天记了工时却没算工资：先给工作设时薪',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '去设置',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.date,
    required this.record,
    required this.profiles,
    required this.income,
    required this.expense,
    required this.entryCount,
    required this.onOpenLedger,
    required this.onTap,
  });

  final String date;
  final WorkDayRecord? record;
  final List<WorkProfile> profiles;
  final double income;
  final double expense;
  final int entryCount;
  final VoidCallback? onOpenLedger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pay = record == null ? 0.0 : recordPay(record!, profiles);
    final ledgerSummary = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (income > 0)
          Text(
            '+${formatAmount(income)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.income,
              fontFeatures: tabularFigures,
            ),
          ),
        if (income > 0 && expense > 0)
          Text(' · ', style: TextStyle(fontSize: 12, color: colors.text3)),
        if (expense > 0)
          Text(
            '-${formatAmount(expense)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.expense,
              fontFeatures: tabularFigures,
            ),
          ),
      ],
    );
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '今天 · 周${weekdayName(DateTime.parse(date).weekday % 7)} · '
                        '${formatDateLabel(date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: colors.text3,
                        ),
                      ),
                    ),
                    if (record?.settled == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: ShapeDecoration(
                          color: colors.warningSoft,
                          shape: Radii.pillShape,
                        ),
                        child: Text(
                          '已结算',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: colors.warning,
                          ),
                        ),
                      )
                    else if (record == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: ShapeDecoration(
                          color: colors.inset,
                          shape: Radii.pillShape,
                        ),
                        child: Text(
                          '待记录',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: colors.text3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gaps.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      record == null ? '—' : formatHoursValue(record!.hours),
                      style: TextStyle(
                        fontSize: 34,
                        height: 1,
                        // 无记录时用细体，避免 40sp 的破折号看起来像一根横杠
                        fontWeight: record == null
                            ? FontWeight.w300
                            : FontWeight.w700,
                        letterSpacing: -0.04,
                        color: record == null ? colors.text2 : colors.accent,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        '小时',
                        style: TextStyle(fontSize: 12, color: colors.text3),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              record == null ? '—' : formatAmount(pay),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: record == null
                                    ? FontWeight.w300
                                    : FontWeight.w700,
                                letterSpacing: -0.03,
                                color: record == null
                                    ? colors.text2
                                    : colors.income,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '今日工资',
                          style: TextStyle(fontSize: 10.5, color: colors.text3),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.lg),
                if (onOpenLedger != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entryCount == 0 ? '今天还没有账目' : '今天 $entryCount 笔账目',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.text2),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: ledgerSummary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gaps.md),
                ],
              ],
            ),
          ),
          // 主操作：无记录时是品牌蓝实心按钮，有记录时降为次级
          Row(
            children: [
              if (onOpenLedger != null) ...[
                Expanded(
                  child: GhostButton(
                    label: '记一笔',
                    icon: Icons.receipt_long_rounded,
                    expand: true,
                    onPressed: onOpenLedger,
                  ),
                ),
                const SizedBox(width: Gaps.sm),
              ],
              Expanded(
                child: record == null
                    ? PrimaryButton(
                        label: '记工时',
                        icon: Icons.add_rounded,
                        expand: true,
                        onPressed: onTap,
                      )
                    : GhostButton(
                        label: '修改记录',
                        icon: Icons.edit_outlined,
                        expand: true,
                        onPressed: onTap,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayLedgerCard extends StatelessWidget {
  const _TodayLedgerCard({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text(
                  '今日账目',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length} 笔',
                  style: TextStyle(fontSize: 11.5, color: colors.text2),
                ),
              ],
            ),
          ),
          for (final entry in entries)
            Pressable(
              onTap: () => showLedgerEditor(context, entry: entry),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: entry.type == LedgerType.income
                            ? colors.incomeSoft
                            : colors.expenseSoft,
                        shape: Radii.shape(10),
                      ),
                      child: Icon(
                        entry.type == LedgerType.income
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 16,
                        color: entry.type == LedgerType.income
                            ? colors.income
                            : colors.expense,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.category,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.text,
                            ),
                          ),
                          if (entry.remark.isNotEmpty)
                            Text(
                              entry.remark,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.text2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${entry.type == LedgerType.income ? '+' : '-'}'
                      '${formatAmount(entry.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: entry.type == LedgerType.income
                            ? colors.income
                            : colors.expense,
                        fontFeatures: tabularFigures,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.footer,
    required this.onTap,
    this.progress,
    this.delta,
    this.deltaColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final String footer;
  final VoidCallback onTap;
  final String? delta;
  final Color? deltaColor;

  /// 0..1，非空时在右上角显示小圆环仪表盘。
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gaps.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.text2)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.03,
                    color: accent,
                    fontFeatures: tabularFigures,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(fontSize: 11.5, color: colors.text2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: colors.text2),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ProgressBar(ratio: progress!, color: accent, height: 4),
          ],
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(
              delta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: deltaColor ?? colors.text2,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.dates,
    required this.records,
    required this.entriesByDate,
    required this.today,
    required this.onTapDate,
    required this.onOpenDetail,
  });

  final String month;
  final List<MonthDay> dates;
  final Map<String, WorkDayRecord> records;
  final Map<String, List<LedgerEntry>> entriesByDate;
  final String today;
  final ValueChanged<String> onTapDate;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrentMonth = month == currentMonthKey();
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    // MonthDay.weekday 是 0(周日)…6(周六)，日历第一列是周一。
    final leadingBlanks = dates.isEmpty ? 0 : (dates.first.weekday + 6) % 7;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, Gaps.lg),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                isCurrentMonth ? '本月日历' : '每日记录',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${dates.length}天 · 点击日期记录',
                style: TextStyle(fontSize: 11, color: colors.text2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 10.5, color: colors.text3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + dates.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              // 固定行高而不是按宽度算正方形：窄屏/键盘弹出时 7 列宽度
              // 只有约 44dp，正方形会把日期内容挤爆；50dp 能容纳
              // 日期 + 工时 + 状态点，同时保留足够的纵向触控面积。
              mainAxisExtent: 50 * textScale,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = dates[index - leadingBlanks];
              return _CalendarCell(
                day: day,
                record: records[day.date],
                entries: entriesByDate[day.date] ?? const [],
                isToday: day.date == today,
                isFuture: day.date.compareTo(today) > 0,
                isWeekend: day.weekday == 0 || day.weekday == 6,
                onTap: () => onTapDate(day.date),
              );
            },
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.isDark ? colors.divider : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CalendarLegendDot(color: colors.income, label: '收入'),
              const SizedBox(width: 12),
              _CalendarLegendDot(color: colors.expense, label: '支出'),
              const SizedBox(width: 12),
              _CalendarLegendDot(color: colors.warning, label: '已结算'),
              const Spacer(),
              Pressable(
                onTap: onOpenDetail,
                shape: Radii.shape(Radii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    '明细',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  const _CalendarLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: colors.text2)),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.record,
    required this.entries,
    required this.isToday,
    required this.isFuture,
    required this.isWeekend,
    required this.onTap,
  });

  final MonthDay day;
  final WorkDayRecord? record;
  final List<LedgerEntry> entries;
  final bool isToday;
  final bool isFuture;
  final bool isWeekend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasRecord = record != null;
    final isRest = (record?.hours ?? 0) == 0;
    var income = 0.0;
    var expense = 0.0;
    for (final entry in entries) {
      if (entry.type == LedgerType.income) {
        income += entry.amount;
      } else {
        expense += entry.amount;
      }
    }
    final dayColor = isFuture
        ? colors.text3
        : isToday
        ? colors.primary
        : hasRecord
        ? colors.text
        : (isWeekend ? colors.text2 : colors.text3);
    final hours = record?.hours ?? 0;
    final isSettled = record?.settled == true;
    // 琥珀色（warning）在日历图例里专门表示「已结算」。
    // 原来工时 > 8 也用它，于是超时那天看起来像已结算。
    // 工时长短由数字本身表达，不再占用这个颜色。
    final workColor = isSettled
        ? colors.warning
        : isRest
        ? colors.text2
        : colors.income;
    final selectedGradient = colors.isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primaryContainer.withValues(alpha: 0.58),
              colors.primaryContainer.withValues(alpha: 0.30),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          );
    final semanticsLabel = [
      '${day.day}日',
      if (isToday) '今天',
      if (isFuture) '未来日期',
      if (hasRecord) isRest ? '休息' : '${formatHoursValue(hours)}小时',
      if (!hasRecord) '未记工',
      if (isSettled) '已结算',
      if (income > 0) '收入${formatAmount(income)}元',
      if (expense > 0) '支出${formatAmount(expense)}元',
    ].join('，');
    return Semantics(
      button: !isFuture,
      enabled: !isFuture,
      selected: isToday,
      label: semanticsLabel,
      onTap: isFuture ? null : onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: isFuture ? 0.55 : 1,
        child: Pressable(
          onTap: isFuture ? null : onTap,
          child: Container(
            decoration: ShapeDecoration(
              color: isToday ? null : Colors.transparent,
              gradient: isToday ? selectedGradient : null,
              shadows: isToday
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(14),
                side: isToday
                    ? BorderSide(
                        color: Colors.white.withValues(alpha: 0.92),
                        width: 1.5,
                      )
                    : BorderSide.none,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: dayColor,
                    fontFeatures: tabularFigures,
                  ),
                ),
                const SizedBox(height: 1),
                if (hasRecord)
                  Text(
                    isRest ? '休' : formatHoursValue(hours),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: workColor,
                      fontFeatures: tabularFigures,
                    ),
                  )
                else
                  const SizedBox(height: 12),
                const SizedBox(height: 3),
                SizedBox(
                  height: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (record?.settled == true)
                        _CalendarCellDot(color: colors.warning),
                      if (income > 0) _CalendarCellDot(color: colors.income),
                      if (expense > 0) _CalendarCellDot(color: colors.expense),
                    ],
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

class _CalendarCellDot extends StatelessWidget {
  const _CalendarCellDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenLedger,
    required this.onOpenBudget,
    required this.onOpenWorks,
  });

  final void Function(String date)? onOpenLedger;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenWorks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      if (onOpenLedger != null)
        (
          icon: Icons.receipt_long_rounded,
          label: '记一笔',
          onTap: () => onOpenLedger!(todayISO()),
        ),
      (
        icon: Icons.check_circle_outline_rounded,
        label: '结算',
        onTap: onOpenWorks,
      ),
      (icon: Icons.flag_outlined, label: '预算', onTap: onOpenBudget),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) Container(width: 1, height: 24, color: colors.divider),
            Expanded(
              child: Pressable(
                onTap: actions[i].onTap,
                shape: Radii.shape(Radii.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(actions[i].icon, size: 19, color: colors.text2),
                      const SizedBox(width: 6),
                      Text(
                        actions[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 编辑器 / 详情

Future<void> showDayEditor(
  BuildContext context,
  String date, {
  WorkDayRecord? record,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(archiveReadOnlyProvider)) {
    showArchiveReadOnlyMessage(context);
    return Future<void>.value();
  }
  return showAppSheet<void>(
    context: context,
    dismissible: false,
    builder: (_) => DayEditorSheet(date: date, record: record),
  );
}

Future<bool?> showDayDetail(BuildContext context, WorkDayRecord record) {
  return showAppSheet<bool>(
    context: context,
    builder: (_) => DayDetailSheet(record: record),
  );
}

class DayEditorSheet extends ConsumerStatefulWidget {
  const DayEditorSheet({super.key, required this.date, this.record});

  final String date;
  final WorkDayRecord? record;

  @override
  ConsumerState<DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends ConsumerState<DayEditorSheet> {
  late final TextEditingController _hours;
  late final TextEditingController _remark;
  late final TextEditingController _fixedPay;
  final FocusNode _remarkFocus = FocusNode();
  late String _date;
  WorkDayRecord? _record;
  String? _workId;
  bool _settled = false;
  String? _error;
  bool _submitted = false;

  // 初始快照：用它做值比较判断「有没有改过」。
  // 不能用 controller listener 直接置 dirty——TextEditingController 在光标移动时也会通知，
  // 导致「打开弹层什么都没改，关闭却提示放弃」。
  late String _initialHours;
  late String _initialRemark;
  late String _initialFixedPay;
  late String? _initialWorkId;
  late bool _initialSettled;

  bool get _isDirty =>
      _hours.text != _initialHours ||
      _remark.text != _initialRemark ||
      _fixedPay.text != _initialFixedPay ||
      _workId != _initialWorkId ||
      _settled != _initialSettled;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _hours = TextEditingController();
    _remark = TextEditingController();
    _fixedPay = TextEditingController();
    _applyRecord(widget.record);
  }

  void _applyRecord(WorkDayRecord? record) {
    _record = record;
    _initialHours = record == null ? '' : formatHoursValue(record.hours);
    _initialRemark = record?.remark ?? '';
    _initialFixedPay = record?.fixedPay == null
        ? ''
        : formatAmountInput(record!.fixedPay!);
    _initialWorkId = record?.workId;
    _initialSettled = record?.settled ?? false;
    _hours.text = _initialHours;
    _remark.text = _initialRemark;
    _fixedPay.text = _initialFixedPay;
    _workId = _initialWorkId;
    _settled = _initialSettled;
  }

  @override
  void dispose() {
    _hours.dispose();
    _remark.dispose();
    _fixedPay.dispose();
    _remarkFocus.dispose();
    super.dispose();
  }

  double get _previewHours {
    final parsed = parseHoursInput(_hours.text);
    return parsed is HoursInputOk ? parsed.hours : 0;
  }

  double get _previewPay {
    final state = ref.read(appControllerProvider);
    final fixed = double.tryParse(normalizeNumericInput(_fixedPay.text));
    final record = WorkDayRecord(
      date: _date,
      hours: _previewHours,
      workId: _workId,
      rate: _draftRate(state.workProfiles),
      fixedPay: (fixed != null && fixed > 0) ? fixed : null,
    );
    return recordPay(record, state.workProfiles);
  }

  double? _draftRate(List<WorkProfile> workProfiles) {
    final selectedWorkId = _workId ?? defaultWorkId;
    final originalWorkId = _record?.workId ?? defaultWorkId;
    final originalRate = _record?.rate;
    if (_record != null &&
        selectedWorkId == originalWorkId &&
        originalRate != null) {
      return originalRate;
    }
    final profile = workProfiles.firstWhere(
      (item) => item.id == selectedWorkId,
      orElse: () => workProfiles.isEmpty
          ? createDefaultWorkProfile()
          : workProfiles.first,
    );
    return profile.hourlyRate > 0 ? profile.hourlyRate : null;
  }

  Future<void> _switchDay(int delta) async {
    final target = shiftDate(_date, delta);
    if (target.compareTo(todayISO()) > 0) return;
    if (_isDirty && !_submitted) {
      final discard = await showConfirmDialog(
        context,
        title: '放弃未保存的修改？',
        description: '切换日期后，本页尚未保存的输入不会保留。',
        confirmLabel: '切换',
        danger: true,
      );
      if (discard != true || !mounted) return;
    }
    final state = ref.read(appControllerProvider);
    final record = getRecordByDate(state.records, target);
    ref.read(selectedMonthProvider.notifier).setMonth(target.substring(0, 7));
    setState(() {
      _date = target;
      _applyRecord(record);
      _error = null;
    });
  }

  void _save() {
    final parsed = parseHoursInput(_hours.text);
    if (parsed is! HoursInputOk) {
      setState(() => _error = (parsed as HoursInputError).message);
      return;
    }
    if (_date.compareTo(todayISO()) > 0) {
      setState(() => _error = '不能记录未来日期');
      return;
    }
    final fixedText = normalizeNumericInput(_fixedPay.text);
    double? fixedPay;
    if (fixedText.isNotEmpty) {
      final value = double.tryParse(fixedText);
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value > maxFixedPay ||
          (roundMoney(value) - value).abs() > decimalTolerance) {
        setState(() => _error = '当日工资最多两位小数');
        return;
      }
      fixedPay = value;
    }
    final state = ref.read(appControllerProvider);
    final rate = _draftRate(state.workProfiles);
    // 用真正会落盘的参数算一次工资：0 元日不允许带 settled 标记，
    // 否则会出现工资面板统计不到、批量撤销也清不掉的脏记录。
    final pay = recordPay(
      WorkDayRecord(
        date: _date,
        hours: parsed.hours,
        workId: _workId,
        rate: rate,
        fixedPay: fixedPay,
      ),
      state.workProfiles,
    );
    ref
        .read(appControllerProvider.notifier)
        .saveDay(
          _date,
          parsed.hours,
          _remark.text.trim(),
          workId: _workId,
          rate: rate,
          fixedPay: fixedPay,
          settled: pay > 0 && _settled,
        );
    HapticFeedback.mediumImpact();
    _submitted = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    return SheetScaffold(
      title: '${formatDateLabel(_date)} 工时',
      guard: () => _isDirty && !_submitted,
      titleWidget: _DayDateNavigator(
        date: _date,
        canGoNext: _date.compareTo(todayISO()) < 0,
        onPrevious: () => _switchDay(-1),
        onNext: () => _switchDay(1),
      ),
      actions: [TextActionButton(label: '保存', onPressed: _save)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormRow(
            label: '工时',
            child: NumberField(
              controller: _hours,
              hintText: '0',
              suffixText: '小时',
              autofocus: _record == null,
              onSubmitted: (_) => _remarkFocus.requestFocus(),
            ),
          ),
          QuickChips(
            values: const [0, 4, 6, 8, 8.5, 10, 12],
            selected: _previewHours,
            labelOf: (value) =>
                value == 0 ? '休息' : '${formatHoursValue(value)}h',
            onSelect: (value) {
              _hours.text = formatHoursValue(value);
              _remarkFocus.requestFocus();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: Gaps.md),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: colors.expense),
            ),
          ],
          const SizedBox(height: Gaps.xl),
          FormRow(
            label: '工作',
            hint: '时薪决定自动工资',
            child: Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                for (final profile in state.workProfiles)
                  Pressable(
                    onTap: () => setState(() => _workId = profile.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: ShapeDecoration(
                        color: (_workId ?? defaultWorkId) == profile.id
                            ? colors.primaryContainer
                            : colors.block,
                        shape: Radii.pillShape,
                      ),
                      child: Text(
                        '${profile.name}${profile.hourlyRate > 0 ? ' · ${formatAmount(profile.hourlyRate)}/h' : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: (_workId ?? defaultWorkId) == profile.id
                              ? colors.onPrimaryContainer
                              : colors.text2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FormRow(
            label: '当日工资',
            hint: '留空 = 工时 × 时薪',
            child: NumberField(
              controller: _fixedPay,
              hintText: '自动',
              suffixText: '元',
              fontSize: 18,
            ),
          ),
          FormRow(
            label: '备注',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
              decoration: ShapeDecoration(
                color: colors.block,
                shape: Radii.shape(Radii.md),
              ),
              child: TextField(
                controller: _remark,
                focusNode: _remarkFocus,
                maxLength: maxRemarkLength,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: '做了什么',
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已结算',
                      style: TextStyle(fontSize: 14, color: colors.text),
                    ),
                    if (_previewPay <= 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '当天工资为 0，无需结算',
                          style: TextStyle(fontSize: 11.5, color: colors.text3),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                // 0 元日没有可结算金额：开关固定关闭并禁用，避免出现
                // 「已结算但 0 元」这种工资面板统计不到、撤销也清不掉的脏状态。
                value: _settled && _previewPay > 0,
                onChanged: _previewPay <= 0
                    ? null
                    : (value) => setState(() => _settled = value),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Container(
            padding: const EdgeInsets.all(Gaps.lg),
            decoration: ShapeDecoration(
              color: colors.block,
              shape: Radii.shape(Radii.md),
            ),
            child: Row(
              children: [
                Text(
                  '本日工资',
                  style: TextStyle(fontSize: 12.5, color: colors.text3),
                ),
                const Spacer(),
                Text(
                  formatAmount(_previewPay, withSymbol: true),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.income,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gaps.lg),
          PrimaryButton(label: '保存', expand: true, onPressed: _save),
        ],
      ),
    );
  }
}

class _DayDateNavigator extends StatelessWidget {
  const _DayDateNavigator({
    required this.date,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String date;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        _DayStepButton(
          icon: Icons.chevron_left_rounded,
          label: '前一天',
          onTap: onPrevious,
        ),
        Expanded(
          child: Text(
            formatDateLabel(date),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
        _DayStepButton(
          icon: Icons.chevron_right_rounded,
          label: '后一天',
          onTap: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}

class _DayStepButton extends StatelessWidget {
  const _DayStepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Pressable(
          onTap: onTap,
          shape: const CircleBorder(),
          pressedScale: 0.90,
          child: Opacity(
            opacity: enabled ? 1 : 0.35,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: colors.inset,
                shape: const CircleBorder(),
              ),
              child: Icon(icon, size: 20, color: colors.text2),
            ),
          ),
        ),
      ),
    );
  }
}

class DayDetailSheet extends ConsumerWidget {
  const DayDetailSheet({super.key, required this.record});

  final WorkDayRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final pay = recordPay(record, state.workProfiles);
    final work = state.workProfiles.firstWhere(
      (p) => p.id == (record.workId ?? defaultWorkId),
      orElse: () => state.workProfiles.first,
    );
    final controller = ref.read(appControllerProvider.notifier);

    return SheetScaffold(
      title: formatDateLabel(record.date),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: '工时',
                  value: formatHoursValue(record.hours),
                  unit: '小时',
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: Gaps.xl),
              Expanded(
                child: _DetailMetric(
                  label: '工资',
                  value: formatAmount(pay),
                  unit: '元',
                  color: colors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.lg),
          _DetailRow(label: '工作', value: work.name),
          _DetailRow(
            label: '有效时薪',
            value:
                '${formatAmount(effectiveRate(record, state.workProfiles))} 元/小时',
          ),
          if (hasFixedPay(record))
            _DetailRow(
              label: '自定义日薪',
              value: '${formatAmount(record.fixedPay!)} 元',
            ),
          _DetailRow(
            label: '结算',
            value: record.settled ? (pay > 0 ? '已结算' : '已结算（0 元）') : '未结算',
            // 与日历图例一致：warning 琥珀 = 已结算（原来这里用 income 绿，
            // 同一状态在日历和详情里是两种颜色）。
            valueColor: record.settled ? colors.warning : colors.text3,
          ),
          if (record.remark.isNotEmpty)
            _DetailRow(label: '备注', value: record.remark),
          const SizedBox(height: Gaps.xl),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  // 0 元日没有可结算金额：按钮退化为不可点。
                  // 已结算的 0 元历史脏数据仍允许「取消结算」清掉。
                  label: record.settled ? '取消结算' : (pay > 0 ? '标记结算' : '无需结算'),
                  icon: record.settled
                      ? Icons.undo_rounded
                      : (pay > 0
                            ? Icons.check_circle_outline_rounded
                            : Icons.do_not_disturb_on_outlined),
                  onPressed: pay > 0 || record.settled
                      ? () {
                          controller.setRecordSettled(
                            record.date,
                            !record.settled,
                          );
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: GhostButton(
                  label: '编辑',
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          GhostButton(
            label: '删除记录',
            icon: Icons.delete_outline_rounded,
            danger: true,
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: '删除这天的记录？',
                description: '删除后 6 秒内可撤销；已结算的工资账目会一并移除。',
                confirmLabel: '删除',
                danger: true,
              );
              if (confirmed != true || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              controller.deleteDay(record.date);
              if (context.mounted) {
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  SnackBar(
                    // 与确认框承诺的 6 秒一致（原来只有 3 秒，用户读到时已经过期）。
                    content: const Text('已删除 · 可撤销'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: '撤销',
                      onPressed: () {
                        // 只恢复工时记录；工资账目交给对账按**当前**时薪重建。
                        // 用删除前的旧金额回写会与时薪改动后的 recordPay 分叉。
                        controller.saveDay(
                          record.date,
                          record.hours,
                          record.remark,
                          workId: record.workId,
                          rate: record.rate,
                          fixedPay: record.fixedPay,
                          settled: record.settled,
                        );
                      },
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: colors.text3)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.03,
                  color: color,
                  fontFeatures: tabularFigures,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 3, bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 10.5, color: colors.text3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.text3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                color: valueColor ?? colors.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
