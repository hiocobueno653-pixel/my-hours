import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/theme_tokens.dart';
import '../../data/dates.dart';
import '../../data/models.dart';
import '../../data/records.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';
import '../../core/measure_unit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_controller.dart';
import '../../state/timer_controller.dart';
import '../../core/motion.dart';

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
    this.showToday = true,
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

  /// 历史月份传 false：只保留「本月工时 / 本月工资」两张卡。
  ///
  /// 原来非当前月整块 Bento 被一条提示条替换，切月份时上半屏会「唰一下
  /// 空了」。现在结构不变，只是少了「今天」那张——用户仍然看得到所选
  /// 月份的数字，视线上是内容缩放而不是整块消失。
  final bool showToday;

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
        // 三层信息错峰落定：今日卡 → 月工时 → 月工资，70ms 一档。
        // 错峰 0 / 40 / 80ms（R25：一个容器只做一次入场，总长压在 300ms 内）。
        Widget reveal(int index, Widget child) => RevealOnMount(
          delay: Duration(milliseconds: 40 * index),
          child: child,
        );
        if (!showToday) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: reveal(0, hours)),
                const SizedBox(width: Gaps.sm),
                Expanded(child: reveal(1, salary)),
              ],
            ),
          );
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              reveal(0, today),
              const SizedBox(height: Gaps.sm),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: reveal(1, hours)),
                    const SizedBox(width: Gaps.sm),
                    Expanded(child: reveal(2, salary)),
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
              Expanded(flex: 11, child: reveal(0, today)),
              const SizedBox(width: Gaps.sm),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: reveal(1, hours)),
                    const SizedBox(height: Gaps.sm),
                    Expanded(child: reveal(2, salary)),
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
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
                    color: colors.text2,
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
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
              // 状态点与状态文字合成一颗胶囊。原来「点 + 字 + 右侧日期胶囊」
              // 三件事挤一行，而日期和顶部的「今天 · 周六」是重复信息。
              Container(
                padding: const EdgeInsets.fromLTRB(7, 2.5, 8, 2.5),
                decoration: ShapeDecoration(
                  color: statusBackground,
                  shape: Radii.pillShape,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: TypeScale.micro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (settled)
                Text(
                  '工资已入账',
                  style: TextStyle(
                    fontSize: TypeScale.micro,
                    color: colors.text3,
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
                            color: colors.text3,
                            fontSize: TypeScale.display,
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
                            fontSize: TypeScale.display,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.035,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3, bottom: 3),
                        child: Text(
                          context.unit.name,
                          style: TextStyle(
                            fontSize: TypeScale.micro,
                            color: colors.text3,
                          ),
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
                          fontSize: TypeScale.title,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02,
                        ),
                      ),
                    ),
                    Text(
                      '今日工资',
                      style: TextStyle(
                        fontSize: TypeScale.micro,
                        color: colors.text3,
                      ),
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
          const SizedBox(height: 7),
          _TimerBar(date: date),
          if (!kHoursOnly) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entryCount == 0 ? '今天还没有账目' : '今天 $entryCount 笔账目',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: TypeScale.micro,
                      color: colors.text3,
                    ),
                  ),
                ),
                if (income > 0)
                  Text(
                    '+${formatAmount(income)}',
                    style: TextStyle(
                      fontSize: TypeScale.micro,
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
                      fontSize: TypeScale.micro,
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
            height: 30,
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
                fontSize: TypeScale.label,
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月${context.unit.quantity}',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: TypeScale.micro,
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
                    fontSize: TypeScale.metric,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.03,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    'h',
                    style: TextStyle(fontSize: TypeScale.micro, color: colors.text3),
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
              fontSize: TypeScale.micro,
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
                fontSize: TypeScale.micro,
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                kHoursOnly ? '本月出勤' : '本月工资',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: TypeScale.micro,
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
                    fontSize: TypeScale.metric,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.03,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    kHoursOnly ? '天' : '元',
                    style: TextStyle(fontSize: TypeScale.micro, color: colors.text3),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            kHoursOnly
                ? '日均 ${formatHoursValue(summary.averageHours)} ${context.unit.name}'
                : '待结算 ${formatAmount(settlement.pending)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text2,
              fontSize: TypeScale.micro,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}


/// 计时条：开始 / 暂停 / 停止，停止时把折合时长写回当天记录。
///
/// 秒级刷新只在内存里做，落盘只发生在开始、暂停、停止三个时刻——
/// 否则每秒一次磁盘写会把这个页面拖垮。
class _TimerBar extends ConsumerStatefulWidget {
  const _TimerBar({required this.date});

  final String date;

  @override
  ConsumerState<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends ConsumerState<_TimerBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final timer = ref.read(timerProvider);
      if (timer != null && timer.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    ref.read(timerProvider.notifier).start(date: widget.date);
  }

  void _pause() {
    HapticFeedback.selectionClick();
    ref.read(timerProvider.notifier).pause();
  }

  void _stop() {
    HapticFeedback.mediumImpact();
    final hours = ref.read(timerProvider.notifier).stopAndClear();
    if (hours <= 0) return;
    final controller = ref.read(appControllerProvider.notifier);
    final state = ref.read(appControllerProvider);
    final record = getRecordByDate(state.records, widget.date);
    controller.saveDay(
      widget.date,
      (record?.hours ?? 0) + hours,
      record?.remark ?? '',
      workId: record?.workId,
      rate: record?.rate,
      fixedPay: record?.fixedPay,
    );
  }

  String _clock(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timer = ref.watch(timerProvider);
    // 只认今天的计时：别的日子的计时不该出现在这里。
    final mine = timer != null && timer.date == widget.date ? timer : null;
    final running = mine?.running ?? false;
    final elapsed = mine?.elapsed ?? Duration.zero;
    final active = mine != null && elapsed.inSeconds > 0;

    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: running ? colors.primary : colors.text3,
        ),
        const SizedBox(width: 6),
        // 计时中：大一号、主色、等宽——数字每 10 秒才在胶囊上刷新一次，
        // 但界面里是逐秒跳的，字宽不变才不会左右抖。
        AnimatedDefaultTextStyle(
          duration: Timings.fast,
          style: TextStyle(
            fontSize: active ? TypeScale.body : TypeScale.label,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: active ? -0.01 : 0,
            color: running
                ? colors.primary
                : (active ? colors.text : colors.text3),
            fontFeatures: tabularFigures,
          ),
          child: Text(active ? _clock(elapsed) : '计时'),
        ),
        const Spacer(),
        _TimerAction(
          label: active ? '结束' : '开始',
          primary: !active,
          onTap: active ? _stop : _start,
        ),
        if (running) ...[
          const SizedBox(width: 6),
          _TimerAction(label: '暂停', primary: false, onTap: _pause),
        ] else if (mine != null && active) ...[
          const SizedBox(width: 6),
          _TimerAction(label: '继续', primary: false, onTap: _start),
        ],
      ],
    );
  }
}

class _TimerAction extends StatelessWidget {
  const _TimerAction({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: false,
      shape: Radii.pillShape,
      pressedScale: 0.94,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: primary ? colors.primaryContainer : colors.inset,
          shape: Radii.pillShape,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.micro,
            fontWeight: FontWeight.w600,
            color: primary ? colors.onPrimaryContainer : colors.text2,
          ),
        ),
      ),
    );
  }
}
