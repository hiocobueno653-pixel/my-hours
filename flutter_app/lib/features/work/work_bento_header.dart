import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/models.dart';
import '../../data/records.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';

/// 首页首屏的 1+2 Bento 概览：今日状态 + 本月工时 + 本月工资/出勤。
class WorkBentoHeader extends StatelessWidget {
  const WorkBentoHeader({
    super.key,
    required this.date,
    required this.record,
    required this.profiles,
    required this.income,
    required this.expense,
    required this.entryCount,
    required this.summary,
    required this.monthPay,
    required this.settlement,
    required this.workdays,
    required this.onOpenLedger,
    required this.onOpenToday,
    required this.onQuickHours,
    required this.onOpenMonthDetail,
    required this.onOpenWage,
    this.deltaText,
    this.deltaColor,
  });

  final String date;
  final WorkDayRecord? record;
  final List<WorkProfile> profiles;
  final double income;
  final double expense;
  final int entryCount;
  final MonthSummary summary;
  final double monthPay;
  final SettlementSummary settlement;
  final int workdays;
  final VoidCallback? onOpenLedger;
  final VoidCallback onOpenToday;
  final ValueChanged<double> onQuickHours;
  final VoidCallback onOpenMonthDetail;
  final VoidCallback onOpenWage;
  final String? deltaText;
  final Color? deltaColor;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350 || textScale > 1.14;
        final today = _TodayBentoCard(
          date: date,
          record: record,
          profiles: profiles,
          income: income,
          expense: expense,
          entryCount: entryCount,
          onOpenLedger: onOpenLedger,
          onOpenToday: onOpenToday,
          onQuickHours: onQuickHours,
        );
        final hours = _MonthHoursBentoCard(
          summary: summary,
          workdays: workdays,
          deltaText: deltaText,
          deltaColor: deltaColor,
          onTap: onOpenMonthDetail,
        );
        final salary = _MonthSalaryBentoCard(
          summary: summary,
          monthPay: monthPay,
          settlement: settlement,
          onTap: onOpenWage,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              today,
              const SizedBox(height: Gaps.sm),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: hours),
                    const SizedBox(width: Gaps.sm),
                    Expanded(child: salary),
                  ],
                ),
              ),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: today),
              const SizedBox(width: Gaps.sm),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: hours),
                    const SizedBox(height: Gaps.sm),
                    Expanded(child: salary),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayBentoCard extends StatelessWidget {
  const _TodayBentoCard({
    required this.date,
    required this.record,
    required this.profiles,
    required this.income,
    required this.expense,
    required this.entryCount,
    required this.onOpenLedger,
    required this.onOpenToday,
    required this.onQuickHours,
  });

  final String date;
  final WorkDayRecord? record;
  final List<WorkProfile> profiles;
  final double income;
  final double expense;
  final int entryCount;
  final VoidCallback? onOpenLedger;
  final VoidCallback onOpenToday;
  final ValueChanged<double> onQuickHours;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = record;
    final pay = current == null ? 0.0 : recordPay(current, profiles);
    final settled = current?.settled == true;
    final canQuickEdit = !settled;
    final dateLabel = '今天 · 周${weekdayName(DateTime.parse(date).weekday % 7)}';
    final statusText = settled
        ? '已结算'
        : current == null
        ? '待记录'
        : current.hours > 0
        ? '已记录'
        : '休息';
    final statusColor = settled
        ? colors.warning
        : current == null
        ? colors.text3
        : colors.primary;
    final statusBackground = settled
        ? colors.warningSoft
        : current == null
        ? colors.inset
        : colors.primaryContainer;

    return GlassCard(
      key: const ValueKey('today-bento-card'),
      onTap: onOpenToday,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text3,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onOpenLedger != null)
                Pressable(
                  onTap: onOpenLedger,
                  shape: const CircleBorder(),
                  pressedScale: 0.92,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: colors.text2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: ShapeDecoration(
                  color: statusBackground,
                  shape: Radii.pillShape,
                ),
                child: Text(
                  formatDateLabel(date),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (current == null)
                        Text(
                          '—',
                          style: TextStyle(
                            color: colors.text2,
                            fontSize: 31,
                            height: 1,
                            fontWeight: FontWeight.w300,
                          ),
                        )
                      else
                        AnimatedNumericText(
                          value: current.hours,
                          formatter: (value) =>
                              formatHoursValue(value.toDouble()),
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 31,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.04,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3, bottom: 3),
                        child: Text(
                          '小时',
                          style: TextStyle(fontSize: 10.5, color: colors.text3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!kHoursOnly) ...[
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedNumericText(
                        value: pay,
                        formatter: (value) => formatAmount(value.toDouble()),
                        style: TextStyle(
                          color: colors.income,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02,
                        ),
                      ),
                    ),
                    Text(
                      '今日工资',
                      style: TextStyle(fontSize: 9, color: colors.text3),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _QuickHoursChip(
                label: '＋0.5h',
                enabled: canQuickEdit,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onQuickHours(0.5);
                },
              ),
              const SizedBox(width: 5),
              _QuickHoursChip(
                label: '＋1h',
                enabled: canQuickEdit,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onQuickHours(1);
                },
              ),
              const SizedBox(width: 5),
              _QuickHoursChip(
                label: '8h',
                enabled: canQuickEdit,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onQuickHours(8);
                },
              ),
            ],
          ),
          if (!kHoursOnly) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entryCount == 0 ? '今天还没有账目' : '今天 $entryCount 笔账目',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: colors.text3),
                  ),
                ),
                if (income > 0)
                  Text(
                    '+${formatAmount(income)}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: colors.income,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                if (income > 0 && expense > 0)
                  Text(' · ', style: TextStyle(color: colors.text3)),
                if (expense > 0)
                  Text(
                    '-${formatAmount(expense)}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: colors.expense,
                      fontFeatures: tabularFigures,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickHoursChip extends StatelessWidget {
  const _QuickHoursChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Pressable(
          onTap: enabled ? onTap : null,
          haptic: false,
          shape: Radii.pillShape,
          pressedScale: 0.96,
          child: Container(
            height: 28,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: colors.inset,
              shape: Radii.pillShape,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: TextStyle(
                color: colors.text2,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHoursBentoCard extends StatelessWidget {
  const _MonthHoursBentoCard({
    required this.summary,
    required this.workdays,
    required this.onTap,
    this.deltaText,
    this.deltaColor,
  });

  final MonthSummary summary;
  final int workdays;
  final VoidCallback onTap;
  final String? deltaText;
  final Color? deltaColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = workdays <= 0
        ? 0.0
        : (summary.workDays / workdays).clamp(0.0, 1.0);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月工时',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14, color: colors.text3),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedNumericText(
                  value: summary.totalHours,
                  formatter: (value) => formatHoursValue(value.toDouble()),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.03,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    'h',
                    style: TextStyle(fontSize: 10, color: colors.text3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.workDays}天 · 日均 ${formatHoursValue(summary.averageHours)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text2,
              fontSize: 9.5,
              fontFeatures: tabularFigures,
            ),
          ),
          const Spacer(),
          ProgressBar(ratio: progress, color: colors.primary, height: 3),
          if (deltaText != null) ...[
            const SizedBox(height: 3),
            Text(
              deltaText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: deltaColor ?? colors.text3,
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthSalaryBentoCard extends StatelessWidget {
  const _MonthSalaryBentoCard({
    required this.summary,
    required this.monthPay,
    required this.settlement,
    required this.onTap,
  });

  final MonthSummary summary;
  final double monthPay;
  final SettlementSummary settlement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                kHoursOnly ? '本月出勤' : '本月工资',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14, color: colors.text3),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedNumericText(
                  value: kHoursOnly ? summary.workDays : monthPay,
                  formatter: (value) => kHoursOnly
                      ? value.toInt().toString()
                      : formatAmount(value.toDouble()),
                  style: TextStyle(
                    color: kHoursOnly ? colors.income : colors.warning,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.03,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    kHoursOnly ? '天' : '元',
                    style: TextStyle(fontSize: 9.5, color: colors.text3),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            kHoursOnly
                ? '日均 ${formatHoursValue(summary.averageHours)} 小时'
                : '待结算 ${formatAmount(settlement.pending)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text2,
              fontSize: 9.5,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
