import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dashboard_layout.dart';
import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/models.dart';
import '../../data/profiles.dart';
import '../../data/records.dart';
import '../../state/app_controller.dart';
import '../../state/timer_controller.dart';
import '../../ui/dialog.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';
import 'wage_panel.dart';

/// 首页概览：今日一体工作台 + 紧凑双月指标卡。
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
    required this.ledgerSummary,
    required this.cards,
    required this.todayEntries,
    required this.monthPay,
    required this.settlement,
    required this.workdays,
    required this.onOpenLedger,
    required this.onOpenToday,
    required this.onQuickAmount,
    required this.onOpenMonthDetail,
    required this.onOpenWage,
    this.onOpenWorkManager,
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
  final LedgerMonthSummary ledgerSummary;
  final List<String> cards;
  final List<LedgerEntry> todayEntries;
  final double monthPay;
  final SettlementSummary settlement;
  final int workdays;
  final VoidCallback? onOpenLedger;
  final VoidCallback onOpenToday;
  final void Function(double value, {bool replace}) onQuickAmount;
  final VoidCallback onOpenMonthDetail;
  final VoidCallback onOpenWage;
  final VoidCallback? onOpenWorkManager;
  final String? deltaText;
  final Color? deltaColor;
  final bool showToday;

  @override
  Widget build(BuildContext context) {
    final canPair = MediaQuery.sizeOf(context).width >= 336;
    final visibleIds = <String>[
      for (final id in cards)
        if (!kHoursOnly ||
            (id != DashboardCardIds.ledgerBalance &&
                id != DashboardCardIds.todayLedger))
          id,
    ];
    final activeIds = visibleIds.isEmpty
        ? const [DashboardCardIds.monthQuantity, DashboardCardIds.monthSalary]
        : visibleIds;

    Widget buildMetricCard(String id) {
      return switch (id) {
        DashboardCardIds.monthSalary => _MonthSalaryCard(
          summary: summary,
          monthPay: monthPay,
          settlement: settlement,
          onTap: onOpenWage,
        ),
        DashboardCardIds.ledgerBalance => _MonthBalanceMiniCard(
          summary: ledgerSummary,
          onTap: onOpenLedger,
        ),
        DashboardCardIds.todayLedger => _TodayLedgerMiniCard(
          entryCount: entryCount,
          income: income,
          expense: expense,
          onTap: onOpenLedger,
        ),
        _ => _MonthHoursCard(
          summary: summary,
          workdays: workdays,
          deltaText: deltaText,
          deltaColor: deltaColor,
          onTap: onOpenMonthDetail,
        ),
      };
    }

    Widget buildFullWidthMetricStrip(String id) {
      if (id == DashboardCardIds.todayLedger) {
        return _TodayLedgerStrip(
          entryCount: entryCount,
          income: income,
          expense: expense,
          onTap: onOpenLedger,
        );
      }
      if (id == DashboardCardIds.ledgerBalance) {
        return _MonthBalanceStrip(
          summary: ledgerSummary,
          onTap: onOpenLedger,
        );
      }
      return buildMetricCard(id);
    }

    final metricWidgets = <Widget>[];
    if (canPair) {
      for (var i = 0; i < activeIds.length; i += 2) {
        if (i > 0) metricWidgets.add(const SizedBox(height: Gaps.cardGap));
        if (i + 1 < activeIds.length) {
          metricWidgets.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildMetricCard(activeIds[i])),
                  const SizedBox(width: Gaps.cardGap),
                  Expanded(child: buildMetricCard(activeIds[i + 1])),
                ],
              ),
            ),
          );
        } else {
          metricWidgets.add(buildFullWidthMetricStrip(activeIds[i]));
        }
      }
    } else {
      for (var i = 0; i < activeIds.length; i++) {
        if (i > 0) metricWidgets.add(const SizedBox(height: Gaps.cardGap));
        metricWidgets.add(buildMetricCard(activeIds[i]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showToday) ...[
          RepaintBoundary(
            child: _TodayWorkspaceCard(
              date: date,
              record: record,
              profiles: profiles,
              entryCount: entryCount,
              income: income,
              expense: expense,
              onOpenLedger: onOpenLedger,
              onOpenToday: onOpenToday,
              onQuickAmount: onQuickAmount,
              onOpenWorkManager:
                  onOpenWorkManager ?? () => showWorkManager(context),
            ),
          ),
          const SizedBox(height: Gaps.cardGap),
        ],
        ...metricWidgets,
      ],
    );
  }
}

class _TodayWorkspaceCard extends ConsumerStatefulWidget {
  const _TodayWorkspaceCard({
    required this.date,
    required this.record,
    required this.profiles,
    required this.entryCount,
    required this.income,
    required this.expense,
    required this.onOpenLedger,
    required this.onOpenToday,
    required this.onQuickAmount,
    required this.onOpenWorkManager,
  });

  final String date;
  final WorkDayRecord? record;
  final List<WorkProfile> profiles;
  final int entryCount;
  final double income;
  final double expense;
  final VoidCallback? onOpenLedger;
  final VoidCallback onOpenToday;
  final void Function(double value, {bool replace}) onQuickAmount;
  final VoidCallback onOpenWorkManager;

  @override
  ConsumerState<_TodayWorkspaceCard> createState() =>
      _TodayWorkspaceCardState();
}

class _TodayWorkspaceCardState extends ConsumerState<_TodayWorkspaceCard> {
  void _startOrResume() {
    HapticFeedback.mediumImpact();
    final current = ref.read(timerProvider);
    if (current != null) {
      ref.read(timerProvider.notifier).resume();
    } else {
      ref.read(timerProvider.notifier).start(date: widget.date);
    }
  }

  void _pause() {
    HapticFeedback.selectionClick();
    ref.read(timerProvider.notifier).pause();
  }

  Future<void> _discardTimer() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '放弃本次计时？',
      description: '这段时间不会写入任何记录。',
      confirmLabel: '放弃',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    ref.read(timerProvider.notifier).discard();
  }

  void _stop() {
    HapticFeedback.mediumImpact();
    final timer = ref.read(timerProvider);
    if (timer == null) return;
    final date = timer.date;
    if (ref.read(archiveReadOnlyProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('存档当前为只读，计时未写入。请先恢复可用备份'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final record = getRecordByDate(
      ref.read(appControllerProvider).records,
      date,
    );
    if (record?.settled == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('该日已结算，请先撤销结算再结束计时'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final timerController = ref.read(timerProvider.notifier);
    final hours = timer.hours;
    if (hours <= 0) {
      timerController.discard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('计时不足 1 分钟，未写入记录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final currentHours = record?.hours ?? 0;
    final remaining = (maxDailyHours - currentHours)
        .clamp(0.0, maxDailyHours)
        .toDouble();
    if (remaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('这一天已达到每日记录上限，请先调整原记录或放弃本次计时'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final writtenHours = hours > remaining ? remaining : hours;
    final controller = ref.read(appControllerProvider.notifier);
    controller.saveDay(
      date,
      currentHours + writtenHours,
      record?.remark ?? '',
      workId: record?.workId,
      rate: record?.rate,
      fixedPay: record?.fixedPay,
    );
    controller.flushPendingPersist();
    timerController.discard();
    if (writtenHours < hours && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已达到每日记录上限，超出部分未写入'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quickSteps = context.unit.quickSteps;
    final current = widget.record;
    final pay = current == null ? 0.0 : recordPay(current, widget.profiles);
    final settled = current?.settled == true;
    final canQuickEdit = !settled;
    final activeProfile =
        getWorkById(widget.profiles, current?.workId) ??
        getWorkById(widget.profiles, defaultWorkId) ??
        (widget.profiles.isEmpty ? null : widget.profiles.first);
    final activeRate = current != null
        ? effectiveRate(current, widget.profiles)
        : (activeProfile?.hourlyRate ?? 0);

    final timer = ref.watch(timerProvider);
    final timerDate = timer?.date ?? widget.date;
    final timerSettled = ref.watch(
      appControllerProvider.select(
        (state) => getRecordByDate(state.records, timerDate)?.settled ?? false,
      ),
    );
    final readOnly = ref.watch(archiveReadOnlyProvider);
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final running = timer?.running ?? false;
    final active = timer != null;
    final crossDay = timer != null && timer.date != widget.date;
    final canFinish = timer != null && !readOnly && !timerSettled;
    final timerDisabled = timer == null && (readOnly || settled);

    final dateLabel =
        '今天 · 周${weekdayName(DateTime.parse(widget.date).weekday % 7)}';
    final statusText = active
        ? (running ? '计时中' : '已暂停')
        : settled
        ? '已结算'
        : current == null
        ? '待记录'
        : current.hours > 0
        ? '已记录'
        : '休息';
    final statusColor = active
        ? (running ? colors.primary : colors.warning)
        : settled
        ? colors.income
        : current == null
        ? colors.text3
        : colors.primary;
    final statusBg = active
        ? (running ? colors.primaryContainer : colors.warningSoft)
        : settled
        ? colors.incomeSoft
        : current == null
        ? colors.block
        : colors.primaryContainer;

    return GlassCard(
      key: const ValueKey('today-bento-card'),
      radius: Radii.hero,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text2,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: motionDuration(
                        Timings.fast,
                        disableAnimations: disable,
                      ),
                      curve: Curves2.soft,
                      padding: active
                          ? const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            )
                          : EdgeInsets.zero,
                      decoration: active
                          ? ShapeDecoration(
                              color: statusBg,
                              shape: Radii.pillShape,
                            )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LiveStatusDot(
                            color: statusColor,
                            pulsing: active && running,
                          ),
                          const SizedBox(width: 4),
                          AnimatedSwitcher(
                            duration: motionDuration(
                              Timings.fast,
                              disableAnimations: disable,
                            ),
                            switchInCurve: Curves2.out,
                            switchOutCurve: Curves2.out,
                            child: Text(
                              statusText,
                              key: ValueKey(statusText),
                              style: TextStyle(
                                color: active ? statusColor : colors.text3,
                                fontSize: 11.5,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (crossDay) ...[
                      const SizedBox(width: 6),
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
                          '跨日',
                          style: TextStyle(
                            color: colors.warning,
                            fontSize: TypeScale.micro,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!kHoursOnly && activeProfile != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 168),
                  child: Pressable(
                    onTap: widget.onOpenWorkManager,
                    shape: Radii.shape(8),
                    child: Container(
                      padding: activeRate <= 0
                          ? const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                      decoration: activeRate <= 0
                          ? ShapeDecoration(
                              color: colors.primaryContainer,
                              shape: Radii.shape(8),
                            )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeRate <= 0
                                  ? '设置${context.unit.rateName}'
                                  : '${activeProfile.name} · ¥${formatRate(activeRate)}/${context.unit.rateShort}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: activeRate <= 0
                                    ? colors.onPrimaryContainer
                                    : colors.text3,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                          const SizedBox(width: 1),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: activeRate <= 0
                                ? colors.onPrimaryContainer
                                : colors.text3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Pressable(
                  onTap: widget.onOpenToday,
                  shape: Radii.shape(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: AnimatedSwitcher(
                      duration: motionDuration(
                        Timings.base,
                        disableAnimations: disable,
                      ),
                      switchInCurve: Curves2.out,
                      switchOutCurve: Curves2.out,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previousChildren, ?currentChild],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: active
                          ? KeyedSubtree(
                              key: const ValueKey('today-readout-timer'),
                              child: _LiveTimerReadout(
                                timer: timer,
                                currentHours: current?.hours ?? 0,
                                activeRate: activeRate,
                                crossDay: crossDay,
                              ),
                            )
                          : Column(
                              key: const ValueKey('today-readout-hours'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    if (current == null)
                                      Text(
                                        '—',
                                        style: TextStyle(
                                          color: colors.text3,
                                          fontSize: 36,
                                          height: 1.02,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      AnimatedNumericText(
                                        value: current.hours,
                                        formatter: (value) =>
                                            formatHoursValue(value.toDouble()),
                                        style: TextStyle(
                                          color: colors.text,
                                          fontSize: 36,
                                          height: 1.02,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                    const SizedBox(width: 5),
                                    Text(
                                      context.unit.name,
                                      style: TextStyle(
                                        color: colors.text3,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!kHoursOnly) ...[
                                  const SizedBox(height: 5),
                                  AnimatedNumericText(
                                    value: pay,
                                    formatter: (value) =>
                                        '今日工资 ${formatAmount(value.toDouble(), withSymbol: true)}',
                                    style: TextStyle(
                                      color: pay > 0
                                          ? colors.income
                                          : colors.text3,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSize(
                duration: motionDuration(
                  Timings.base,
                  disableAnimations: disable,
                ),
                curve: Curves2.out,
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: motionDuration(
                    Timings.base,
                    disableAnimations: disable,
                  ),
                  switchInCurve: Curves2.out,
                  switchOutCurve: Curves2.out,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.centerRight,
                    children: [...previousChildren, ?currentChild],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.94,
                        end: 1.0,
                      ).animate(animation),
                      alignment: Alignment.centerRight,
                      child: child,
                    ),
                  ),
                  child: !active
                      ? _TimerCompactButton(
                          key: ValueKey('timer-idle-$timerDisabled-$readOnly'),
                          label: timerDisabled
                              ? (readOnly ? '只读' : '已锁定')
                              : '开始计时',
                          icon: timerDisabled
                              ? Icons.lock_outline_rounded
                              : Icons.play_arrow_rounded,
                          primary: !timerDisabled,
                          disabled: timerDisabled,
                          onTap: timerDisabled ? null : _startOrResume,
                        )
                      : Row(
                          key: const ValueKey('timer-active-controls'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TimerCompactButton(
                              label: canFinish ? '完成' : '放弃',
                              icon: canFinish
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              primary: false,
                              positive: canFinish,
                              onTap: canFinish ? _stop : _discardTimer,
                            ),
                            const SizedBox(width: 6),
                            _TimerCompactButton(
                              label: running ? '暂停' : '继续',
                              icon: running
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              primary: true,
                              onTap: running ? _pause : _startOrResume,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.7, color: colors.divider),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < quickSteps.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _QuickStepChip(
                          label:
                              '${i == quickSteps.length - 1 ? '' : '＋'}'
                              '${formatHoursValue(quickSteps[i])}'
                              '${context.unit.short}',
                          enabled: canQuickEdit,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onQuickAmount(
                              quickSteps[i],
                              replace: i == quickSteps.length - 1,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (!kHoursOnly && widget.onOpenLedger != null) ...[
                _ToolbarMiniAction(
                  icon: Icons.add_rounded,
                  label: widget.entryCount > 0
                      ? '账目 ${widget.entryCount}'
                      : '记账',
                  onTap: widget.onOpenLedger!,
                ),
                const SizedBox(width: 6),
              ],
              _ToolbarMiniAction(
                icon: Icons.edit_outlined,
                label: '编辑',
                onTap: widget.onOpenToday,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 独立计时读数子组件：仅在计时运行期间每秒自刷新，彻底隔离主卡与背景玻璃层的重绘。
class _LiveTimerReadout extends StatefulWidget {
  const _LiveTimerReadout({
    required this.timer,
    required this.currentHours,
    required this.activeRate,
    required this.crossDay,
  });

  final ActiveTimer timer;
  final double currentHours;
  final double activeRate;
  final bool crossDay;

  @override
  State<_LiveTimerReadout> createState() => _LiveTimerReadoutState();
}

class _LiveTimerReadoutState extends State<_LiveTimerReadout> {
  Timer? _ticker;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == enabled) return;
    _tickerEnabled = enabled;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _LiveTimerReadout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final needed = widget.timer.running && _tickerEnabled;
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
    final timer = widget.timer;
    final running = timer.running;
    final liveEstimate = widget.activeRate > 0
        ? roundMoney(timer.hours * widget.activeRate)
        : 0.0;
    final metaParts = <String>[
      if (widget.currentHours > 0)
        '已记 ${formatHoursValue(widget.currentHours)}${context.unit.short}',
      if (!kHoursOnly && liveEstimate > 0)
        '本次约 ${formatAmount(liveEstimate, withSymbol: true)}',
      if (widget.crossDay) '归属 ${formatDateLabel(timer.date)}',
    ];
    final subText = metaParts.isEmpty
        ? (running ? '正在记录工作时间' : '计时已暂停')
        : metaParts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          child: RollingDigitsText(
            text: _clock(timer.elapsed),
            style: TextStyle(
              color: running ? colors.primary : colors.text,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text2,
            fontSize: 12,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// 状态指示点：计时运行时带柔和的脉冲光晕，隐藏页签与关闭动效时自动静止。
class _LiveStatusDot extends StatefulWidget {
  const _LiveStatusDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_LiveStatusDot> createState() => _LiveStatusDotState();
}

class _LiveStatusDotState extends State<_LiveStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Timings.toast * 4,
  );
  bool _tickerEnabled = true;
  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _LiveStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulsing != widget.pulsing) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldRun = widget.pulsing && _tickerEnabled && !_disableAnimations;
    if (shouldRun) {
      if (!_pulse.isAnimating) {
        _pulse.repeat();
      }
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing || _disableAnimations) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return SizedBox(
      width: 10,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves2.out.transform(_pulse.value);
              return Opacity(
                opacity: ((1 - t) * 0.55).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.9 * t,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCompactButton extends StatelessWidget {
  const _TimerCompactButton({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    this.positive = false,
    this.disabled = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final bool positive;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bg = disabled
        ? colors.block
        : primary
        ? colors.primary
        : positive
        ? colors.incomeSoft
        : colors.block;
    final fg = disabled
        ? colors.text3
        : primary
        ? colors.onPrimary
        : positive
        ? colors.income
        : colors.text2;
    final shape = Radii.shape(Radii.md);
    return Pressable(
      onTap: onTap,
      haptic: false,
      shape: shape,
      pressedScale: 0.94,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: ShapeDecoration(
          color: bg,
          shape: shape,
          shadows: primary && !disabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(
                      alpha: colors.isDark ? 0.26 : 0.10,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: motionDuration(Timings.fast, disableAnimations: disable),
              switchInCurve: Curves2.out,
              switchOutCurve: Curves2.out,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey('$label-${icon.codePoint}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
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

class _QuickStepChip extends StatelessWidget {
  const _QuickStepChip({
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
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shape = Radii.shape(9);
    return AnimatedOpacity(
      duration: motionDuration(Timings.instant, disableAnimations: disable),
      curve: Curves2.soft,
      opacity: enabled ? 1 : 0.45,
      child: Pressable(
        onTap: enabled ? onTap : null,
        haptic: false,
        shape: shape,
        pressedScale: 0.94,
        child: Container(
          constraints: const BoxConstraints(minWidth: 42, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: colors.block.withValues(alpha: colors.isDark ? 0.85 : 0.78),
            shape: shape,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFeatures: tabularFigures,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarMiniAction extends StatelessWidget {
  const _ToolbarMiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      shape: Radii.shape(9),
      pressedScale: 0.94,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: Radii.shape(9).copyWith(
            side: BorderSide(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFF0F172A).withValues(alpha: 0.08),
              width: 0.75,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: colors.text2),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHoursCard extends StatelessWidget {
  const _MonthHoursCard({
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
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                '本月${context.unit.quantity}',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14.5, color: colors.text3),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedNumericText(
                    value: summary.totalHours,
                    formatter: (value) => formatHoursValue(value.toDouble()),
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 23,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                context.unit.short,
                style: TextStyle(fontSize: 11.5, color: colors.text3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(ratio: progress, color: colors.primary, height: 3),
          const SizedBox(height: 6),
          Text(
            '${summary.workDays}天 · 日均 ${formatHoursValue(summary.averageHours)}${context.unit.short}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text3,
              fontSize: 11,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSalaryCard extends StatelessWidget {
  const _MonthSalaryCard({
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
    final allSettled =
        !kHoursOnly && settlement.total > 0 && settlement.pending <= 0;
    final settleRatio = settlement.total <= 0
        ? 0.0
        : (settlement.settled / settlement.total).clamp(0.0, 1.0);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                kHoursOnly
                    ? Icons.event_available_rounded
                    : Icons.payments_outlined,
                size: 14,
                color: colors.income,
              ),
              const SizedBox(width: 5),
              Text(
                kHoursOnly ? '本月出勤' : '本月工资',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14.5, color: colors.text3),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedNumericText(
              value: kHoursOnly ? summary.workDays : monthPay,
              formatter: (value) => kHoursOnly
                  ? '${value.toInt()} 天'
                  : formatAmount(value.toDouble(), withSymbol: true),
              style: TextStyle(
                color: kHoursOnly
                    ? colors.income
                    : (monthPay > 0 ? colors.income : colors.text),
                fontSize: 23,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!kHoursOnly) ...[
            ProgressBar(ratio: settleRatio, color: colors.income, height: 3),
            const SizedBox(height: 6),
          ] else
            const Spacer(),
          Text(
            kHoursOnly
                ? '工作日出勤 ${summary.workDays} 天'
                : allSettled
                ? '已全部结算入账'
                : '待结算 ${formatAmount(settlement.pending, withSymbol: true)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: allSettled ? colors.income : colors.text3,
              fontSize: 11,
              fontWeight: allSettled ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBalanceMiniCard extends StatelessWidget {
  const _MonthBalanceMiniCard({
    required this.summary,
    required this.onTap,
  });

  final LedgerMonthSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final net = summary.balance;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 14,
                color: colors.chart[1],
              ),
              const SizedBox(width: 5),
              Text(
                '本月结余',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14.5, color: colors.text3),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatAmount(net, withSymbol: true),
              style: TextStyle(
                color: net < 0 ? colors.expense : colors.text,
                fontSize: 23,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '收 ${formatAmount(summary.income, withSymbol: true)} · 支 ${formatAmount(summary.expense, withSymbol: true)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text3,
              fontSize: 11,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayLedgerMiniCard extends StatelessWidget {
  const _TodayLedgerMiniCard({
    required this.entryCount,
    required this.income,
    required this.expense,
    required this.onTap,
  });

  final int entryCount;
  final double income;
  final double expense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 14,
                color: colors.warning,
              ),
              const SizedBox(width: 5),
              Text(
                '今日账目',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14.5, color: colors.text3),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            entryCount == 0 ? '暂无收支' : '$entryCount 笔',
            style: TextStyle(
              color: entryCount == 0 ? colors.text3 : colors.text,
              fontSize: 21,
              height: 1.05,
              fontWeight: FontWeight.w700,
              fontFeatures: tabularFigures,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entryCount == 0
                ? '轻点快捷记一笔'
                : '收 ${formatAmount(income, withSymbol: true)} · 支 ${formatAmount(expense, withSymbol: true)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text3,
              fontSize: 11,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单独占整行时的紧凑今日账目条：不挤压下方日历首屏。
class _TodayLedgerStrip extends StatelessWidget {
  const _TodayLedgerStrip({
    required this.entryCount,
    required this.income,
    required this.expense,
    required this.onTap,
  });

  final int entryCount;
  final double income;
  final double expense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = entryCount == 0
        ? '暂无收支 · 轻点记一笔'
        : '$entryCount 笔 · 收 ${formatAmount(income, withSymbol: true)} · 支 ${formatAmount(expense, withSymbol: true)}';
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 16,
            color: colors.text2,
          ),
          const SizedBox(width: 8),
          Text(
            '今日账目',
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: entryCount == 0 ? colors.text3 : colors.text2,
                fontSize: 12.5,
                fontWeight: entryCount == 0 ? FontWeight.w400 : FontWeight.w600,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: colors.text3),
        ],
      ),
    );
  }
}

/// 单独占整行时的紧凑本月结余条。
class _MonthBalanceStrip extends StatelessWidget {
  const _MonthBalanceStrip({
    required this.summary,
    required this.onTap,
  });

  final LedgerMonthSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final net = summary.balance;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 16,
            color: colors.text2,
          ),
          const SizedBox(width: 8),
          Text(
            '本月结余',
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${formatAmount(net, withSymbol: true)} · 收 ${formatAmount(summary.income, withSymbol: true)} / 支 ${formatAmount(summary.expense, withSymbol: true)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: net < 0 ? colors.expense : colors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: colors.text3),
        ],
      ),
    );
  }
}
