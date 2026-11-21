import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dashboard_layout.dart';
import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
import '../../core/motion.dart';
import '../../core/settings.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/models.dart';
import '../../data/profiles.dart';
import '../../data/records.dart';
import '../../state/app_controller.dart';
import '../../ui/dialog.dart';
import '../../ui/export_sheet.dart';
import '../../ui/glass_menu.dart';
import '../../ui/month_picker.dart';
import '../../ui/pinned_header.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import '../ledger/ledger_view.dart';
import 'budget_panel.dart';
import 'month_detail.dart';
import 'wage_panel.dart';
import 'work_bento_header.dart';

/// 工时主页：今日一体工作台 + 月汇总条 + 可交互月历 + 选中日就地详情。
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key, this.onOpenLedger});

  final void Function(String date)? onOpenLedger;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  int _calendarDirection = 1;
  bool _dayFlowOpen = false;
  String? _selectedDate;
  bool _editingLayout = false;

  void _changeMonth(String next, {int? direction}) {
    final current = ref.read(selectedMonthProvider);
    if (next == current) return;
    setState(() {
      _calendarDirection = direction ?? (next.compareTo(current) < 0 ? -1 : 1);
      _selectedDate = null;
    });
    ref.read(selectedMonthProvider.notifier).setMonth(next);
  }

  void _shiftMonth(int direction) {
    final current = ref.read(selectedMonthProvider);
    _changeMonth(shiftMonth(current, direction), direction: direction);
  }

  void _quickSaveToday(double value, {bool replace = false}) {
    final state = ref.read(appControllerProvider);
    final date = todayISO();
    final record = getRecordByDate(state.records, date);
    if (record?.settled == true) return;
    final nextHours = replace ? value : (record?.hours ?? 0) + value;
    ref
        .read(appControllerProvider.notifier)
        .saveDay(
          date,
          nextHours.clamp(0.0, maxDailyHours).toDouble(),
          record?.remark ?? '',
          workId: record?.workId,
          rate: record?.rate,
          fixedPay: record?.fixedPay,
          settled: false,
        );
    setState(() => _selectedDate = date);
  }

  Future<void> _openDay(String date, {bool directEdit = false}) async {
    if (_dayFlowOpen) return;
    _dayFlowOpen = true;
    try {
      final state = ref.read(appControllerProvider);
      final record = getRecordByDate(state.records, date);
      if (record == null || directEdit) {
        await showDayEditor(context, date, record: record);
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

  String _resolveSelectedDate(
    String month,
    String today,
    List<MonthDay> dates,
    Map<String, WorkDayRecord> recordsByDate,
  ) {
    final current = _selectedDate;
    if (current != null && current.startsWith('$month-')) return current;
    if (today.startsWith('$month-')) return today;
    if (recordsByDate.isNotEmpty) {
      final sorted = recordsByDate.keys.toList()..sort();
      return sorted.last;
    }
    return dates.isNotEmpty ? dates.first.date : today;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    AppSettings? settings;
    try {
      settings = ref.read(settingsProvider);
    } on Object {
      settings = null;
    }
    if (settings != null) {
      final listenable = settings;
      return ListenableBuilder(
        listenable: listenable,
        builder: (context, _) =>
            _buildContent(context, colors, listenable, listenable.dashboardCards),
      );
    }
    return _buildContent(context, colors, null, DashboardCardIds.defaults);
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    AppSettings? settings,
    List<String> dashboardCards,
  ) {
    final records = ref.watch(recordsProvider);
    final entries = ref.watch(entriesProvider);
    final profiles = ref.watch(workProfilesProvider);
    final month = ref.watch(selectedMonthProvider);
    final today = todayISO();
    final todayRecord = getRecordByDate(records, today);
    final summary = ref.watch(currentMonthWorkSummaryProvider);
    final monthWork = ref.watch(currentMonthWorkViewDataProvider);
    final monthLedger = ref.watch(currentMonthLedgerViewDataProvider);
    final monthPay = monthWork.monthPay;
    final settlement = monthWork.settlement;
    final monthDelta = monthWork.monthDelta;
    final ledgerSummary = monthLedger.summary;
    final todayEntries = month == currentMonthKey()
        ? (monthLedger.entriesByDate[today] ?? const <LedgerEntry>[])
        : [
            for (final entry in entries)
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
              '${formatHoursValue(monthDelta.delta.abs())} ${context.unit.name}'
              '（${monthDelta.percent >= 0 ? '+' : ''}${monthDelta.percent}%）';
    final dates = monthWork.dates;
    final workdays = monthWork.workdays;
    final underpaidDays = monthWork.underpaidDays;
    final recordsByDate = monthWork.recordsByDate;
    final entriesByDate = monthLedger.entriesByDate;
    final activeDate = _resolveSelectedDate(
      month,
      today,
      dates,
      recordsByDate,
    );
    final activeRecord = recordsByDate[activeDate];
    final activeEntries = entriesByDate[activeDate] ?? const <LedgerEntry>[];

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
                    if (month != currentMonthKey()) ...[
                      _PastMonthBanner(
                        month: month,
                        onTap: () => _changeMonth(currentMonthKey()),
                      ),
                      const SizedBox(height: Gaps.sm),
                    ],
                    if (_editingLayout && settings != null)
                      _DashboardLayoutEditor(
                        cards: dashboardCards,
                        labelOf: (id) => _dashboardCardLabel(context, id),
                        onChanged: (next) {
                          unawaited(settings.setDashboardCards(next));
                          if (mounted) setState(() {});
                        },
                        onDone: () => setState(() => _editingLayout = false),
                      )
                    else
                      RepaintBoundary(
                        child: WorkBentoHeader(
                      showToday: month == currentMonthKey(),
                      date: today,
                      record: todayRecord,
                      profiles: profiles,
                      income: todayIncome,
                      expense: todayExpense,
                      entryCount: todayEntries.length,
                      summary: summary,
                      ledgerSummary: ledgerSummary,
                      cards: dashboardCards,
                      todayEntries: todayEntries,
                      monthPay: monthPay,
                      settlement: settlement,
                      workdays: workdays,
                      onOpenLedger: kHoursOnly
                          ? null
                          : () => showLedgerEditor(context, presetDate: today),
                      onOpenToday: () => _openDay(today),
                      onQuickAmount: _quickSaveToday,
                      onOpenMonthDetail: () => showMonthDetail(context, month),
                      onOpenWage: () => showWagePanel(context, month),
                      onOpenWorkManager: () => showWorkManager(context),
                      deltaText: deltaText,
                      deltaColor: monthDelta != null && monthDelta.delta >= 0
                          ? colors.income
                          : colors.expense,
                    ),
                      ),
                    if (!kHoursOnly && underpaidDays > 0) ...[
                      const SizedBox(height: Gaps.cardGap),
                      _MissingRateHint(
                        days: underpaidDays,
                        onTap: () => showWorkManager(context),
                      ),
                    ],
                    const SizedBox(height: Gaps.cardGap),
                    RepaintBoundary(
                      child: _SwipeableCalendar(
                        month: month,
                        dates: dates,
                        records: recordsByDate,
                        entriesByDate: entriesByDate,
                        today: today,
                        selectedDate: activeDate,
                        direction: _calendarDirection,
                        onTapDate: (date) {
                          HapticFeedback.selectionClick();
                          if (date == activeDate) {
                            _openDay(date);
                          } else {
                            setState(() => _selectedDate = date);
                          }
                        },
                        onLongPressDate: (date, globalPos) =>
                            _showDayContextMenu(
                              context,
                              date: date,
                              record: recordsByDate[date],
                              globalPosition: globalPos,
                            ),
                        onOpenDetail: () => showMonthDetail(context, month),
                        onShift: _shiftMonth,
                      ),
                    ),
                    const SizedBox(height: Gaps.cardGap),
                    _SelectedDayCard(
                      date: activeDate,
                      isToday: activeDate == today,
                      record: activeRecord,
                      entries: activeEntries,
                      profiles: profiles,
                      onEdit: () => _openDay(activeDate, directEdit: true),
                      onDetail: activeRecord == null
                          ? null
                          : () => _openDay(activeDate),
                      onAddLedger: kHoursOnly
                          ? null
                          : () => showLedgerEditor(
                              context,
                              presetDate: activeDate,
                            ),
                    ),
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
            title: context.unit.quantity,
            animateTitle: true,
            titleHint: '长按切换计量单位',
            onTitleLongPress: settings == null
                ? null
                : (pos) => _showUnitMenu(context, settings, pos),
            actions: [
              if (_editingLayout)
                Pressable(
                  onTap: () => setState(() => _editingLayout = false),
                  shape: Radii.pillShape,
                  pressedScale: 0.94,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: colors.primary,
                      shape: Radii.pillShape,
                    ),
                    child: Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                )
              else ...[
              MonthSwitchPill(
                month: month,
                onChanged: _changeMonth,
                onPick: () async {
                  final picked = await showMonthPicker(
                    context,
                    initialMonth: month,
                  );
                  if (picked != null && context.mounted) {
                    _changeMonth(picked);
                  }
                },
              ),
              GlassMenuButton(
                tooltip: '更多操作',
                items: [
                  GlassMenuAction(
                    label: '导出本月数据',
                    icon: Icons.download_rounded,
                    onSelected: () => showExportSheet(
                      context,
                      month: month,
                      records: records,
                      entries: entries,
                      includeLedger: !kHoursOnly,
                    ),
                  ),
                  if (!kHoursOnly)
                    GlassMenuAction(
                      label: '快速记一笔账',
                      icon: Icons.add_card_rounded,
                      onSelected: () =>
                          showLedgerEditor(context, presetDate: activeDate),
                    ),
                  GlassMenuAction(
                    label: '工作与${context.unit.rateName}',
                    icon: Icons.work_outline_rounded,
                    dividerBefore: true,
                    sectionTitle: '快捷管理',
                    onSelected: () => showWorkManager(context),
                  ),
                  if (!kHoursOnly) ...[
                    GlassMenuAction(
                      label: '工资结算明细',
                      icon: Icons.payments_outlined,
                      onSelected: () => showWagePanel(context, month),
                    ),
                    GlassMenuAction(
                      label: '预算与月目标',
                      icon: Icons.track_changes_rounded,
                      onSelected: () => showBudgetPanel(context),
                    ),
                  ],
                  if (settings != null)
                    GlassMenuAction(
                      label: '首页指标卡',
                      subtitle: '已启用 ${dashboardCards.length} 项',
                      icon: Icons.dashboard_customize_outlined,
                      dividerBefore: true,
                      children: [
                        GlassMenuAction(
                          label: '编辑顺序与卡片',
                          icon: Icons.drag_indicator_rounded,
                          onSelected: () =>
                              setState(() => _editingLayout = true),
                        ),
                        for (final cardId in DashboardCardIds.all)
                          if (!kHoursOnly ||
                              (cardId != DashboardCardIds.ledgerBalance &&
                                  cardId != DashboardCardIds.todayLedger))
                            GlassMenuAction(
                              label: _dashboardCardLabel(context, cardId),
                              selected: dashboardCards.contains(cardId),
                              onSelected: () {
                                final next = List<String>.of(dashboardCards);
                                if (next.contains(cardId)) {
                                  if (next.length > 1) next.remove(cardId);
                                } else {
                                  next.add(cardId);
                                }
                                unawaited(settings.setDashboardCards(next));
                                if (mounted) setState(() {});
                              },
                            ),
                      ],
                    ),
                ],
              ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showUnitMenu(
    BuildContext context,
    AppSettings settings,
    Offset globalPosition,
  ) {
    final current = settings.measureUnit;
    unawaited(showDropletGlassMenu(
      context,
      anchorOffset: globalPosition,
      preferRightAlign: false,
      items: [
        for (var i = 0; i < MeasureUnit.presets.length; i++)
          GlassMenuAction(
            label:
                '${MeasureUnit.presets[i].quantity}（${MeasureUnit.presets[i].name}）',
            sectionTitle: i == 0 ? '切换计量单位' : null,
            selected: MeasureUnit.presets[i].id == current.id,
            onSelected: () {
              unawaited(settings.setMeasureUnit(MeasureUnit.presets[i]));
            },
          ),
      ],
    ));
  }

  String _dashboardCardLabel(BuildContext context, String cardId) {
    return switch (cardId) {
      DashboardCardIds.monthQuantity => '本月${context.unit.quantity}',
      DashboardCardIds.monthSalary => '本月工资',
      DashboardCardIds.ledgerBalance => '本月结余',
      DashboardCardIds.todayLedger => '今日账目',
      _ => cardId,
    };
  }

  void _showDayContextMenu(
    BuildContext context, {
    required String date,
    required WorkDayRecord? record,
    required Offset globalPosition,
  }) {
    if (date.compareTo(todayISO()) > 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _selectedDate = date);
    final settled = record?.settled == true;
    final items = <GlassMenuAction>[
      if (record == null)
        GlassMenuAction(
          label: '一键记 8${context.unit.short}',
          icon: Icons.bolt_rounded,
          onSelected: () {
            ref.read(appControllerProvider.notifier).saveDay(date, 8, '');
          },
        ),
      if (record != null)
        GlassMenuAction(
          label: '查看详情',
          icon: Icons.visibility_outlined,
          onSelected: () => _openDay(date),
        ),
      GlassMenuAction(
        label: record == null ? '记一笔${context.unit.quantity}' : '编辑记录',
        icon: Icons.edit_outlined,
        onSelected: () => _openDay(date, directEdit: true),
      ),
      if (!kHoursOnly && record != null && record.hours > 0)
        GlassMenuAction(
          label: settled ? '撤销结算' : '标记已结算',
          icon: settled
              ? Icons.undo_rounded
              : Icons.check_circle_outline_rounded,
          onSelected: () {
            ref
                .read(appControllerProvider.notifier)
                .setRecordSettled(date, !settled);
          },
        ),
      if (!kHoursOnly)
        GlassMenuAction(
          label: '记一笔账',
          icon: Icons.add_card_rounded,
          onSelected: () => showLedgerEditor(context, presetDate: date),
        ),
      if (record != null)
        GlassMenuAction(
          label: '删除记录',
          icon: Icons.delete_outline_rounded,
          danger: true,
          dividerBefore: true,
          onSelected: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: '删除 ${formatDateLabel(date)} 的记录？',
              description: '已结算的工资账目也会一并移除。',
              confirmLabel: '删除',
              danger: true,
            );
            if (confirmed == true && mounted) {
              ref.read(appControllerProvider.notifier).deleteDay(date);
            }
          },
        ),
    ];
    unawaited(
      showDropletGlassMenu(
        context,
        anchorOffset: globalPosition,
        panelWidth: 204,
        preferRightAlign:
            globalPosition.dx > MediaQuery.sizeOf(context).width * 0.48,
        items: items,
      ),
    );
  }
}

class _PastMonthBanner extends StatelessWidget {
  const _PastMonthBanner({required this.month, required this.onTap});

  final String month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isFuture = month.compareTo(currentMonthKey()) > 0;
    return GlassCard(
      flat: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Icon(
            isFuture ? Icons.event_outlined : Icons.history_rounded,
            size: 17,
            color: colors.text2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFuture
                  ? '正在查看 ${formatMonthLabel(month)} 未来月份'
                  : '正在查看 ${formatMonthLabel(month)} 历史记录',
              style: TextStyle(fontSize: 13, color: colors.text2),
            ),
          ),
          Pressable(
            onTap: onTap,
            shape: Radii.shape(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: colors.primaryContainer,
                shape: Radii.shape(8),
              ),
              child: Text(
                '回到本月',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingRateHint extends StatelessWidget {
  const _MissingRateHint({required this.days, required this.onTap});

  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      shape: Radii.shape(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: ShapeDecoration(
          color: colors.warningSoft,
          shape: Radii.shape(Radii.md).copyWith(
            side: BorderSide(color: colors.warning.withValues(alpha: 0.25)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 17, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '有 $days 天${context.unit.quantity}未设${context.unit.rateName}，暂无法计入工资',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ),
            Text(
              '去设置',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.warning,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: colors.warning),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.date,
    required this.isToday,
    required this.record,
    required this.entries,
    required this.profiles,
    required this.onEdit,
    required this.onDetail,
    required this.onAddLedger,
  });

  final String date;
  final bool isToday;
  final WorkDayRecord? record;
  final List<LedgerEntry> entries;
  final List<WorkProfile> profiles;
  final VoidCallback onEdit;
  final VoidCallback? onDetail;
  final VoidCallback? onAddLedger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final parsed = DateTime.tryParse(date);
    final weekday = parsed == null ? '' : '周${weekdayName(parsed.weekday % 7)}';
    final pay = record == null ? 0.0 : recordPay(record!, profiles);
    final settled = record?.settled == true;
    final workName = record == null ? '' : workNameOf(record!, profiles);
    final isFuture = date.compareTo(todayISO()) > 0;

    var netLedger = 0.0;
    for (final entry in entries) {
      netLedger += entry.type == LedgerType.income ? entry.amount : -entry.amount;
    }

    return GlassCard(
      onTap: isFuture ? null : (onDetail ?? onEdit),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${formatDateLabel(date)} $weekday',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: ShapeDecoration(
                    color: colors.primaryContainer,
                    shape: Radii.shape(6),
                  ),
                  child: Text(
                    '今天',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              if (settled) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: ShapeDecoration(
                    color: colors.incomeSoft,
                    shape: Radii.shape(6),
                  ),
                  child: Text(
                    '已结算',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: colors.income,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!isFuture) ...[
                if (onAddLedger != null)
                  _InlineAction(
                    label: '记账',
                    icon: Icons.add_rounded,
                    onTap: onAddLedger!,
                  ),
                const SizedBox(width: 4),
                _InlineAction(
                  label: record == null ? '记录' : '编辑',
                  icon: record == null
                      ? Icons.add_task_rounded
                      : Icons.edit_outlined,
                  primary: record == null,
                  onTap: onEdit,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (isFuture)
            Text(
              '未来日期暂不可录入${context.unit.quantity}',
              style: TextStyle(fontSize: 12.5, color: colors.text3),
            )
          else if (record == null && entries.isEmpty)
            Text(
              '这一天还没有${context.unit.quantity}或账目，点右上角或再点一次日历即可快速录入。',
              style: TextStyle(fontSize: 12.5, color: colors.text3),
            )
          else ...[
            Row(
              children: [
                if (record != null)
                  Expanded(
                    child: Text(
                      record!.hours == 0
                          ? '休息日'
                          : '${formatHoursValue(record!.hours)} ${context.unit.name}'
                                '${!kHoursOnly && pay > 0 ? ' · ${formatAmount(pay, withSymbol: true)}' : ''}'
                                '${workName.isNotEmpty ? ' · $workName' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.text,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      '未记录${context.unit.quantity}',
                      style: TextStyle(fontSize: 12.5, color: colors.text3),
                    ),
                  ),
                if (entries.isNotEmpty)
                  Text(
                    '账目 ${entries.length} 笔 (${netLedger >= 0 ? '+' : ''}${formatAmount(netLedger, withSymbol: true)})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: netLedger >= 0 ? colors.income : colors.expense,
                      fontFeatures: tabularFigures,
                    ),
                  ),
              ],
            ),
            if (record != null && record!.remark.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                record!.remark,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.text2),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = Radii.pillShape;
    return Pressable(
      onTap: onTap,
      shape: shape,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: ShapeDecoration(
          color: primary ? colors.primaryContainer : colors.block,
          shape: shape,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: primary ? colors.onPrimaryContainer : colors.text2,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary ? colors.onPrimaryContainer : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeableCalendar extends StatefulWidget {
  const _SwipeableCalendar({
    required this.month,
    required this.dates,
    required this.records,
    required this.entriesByDate,
    required this.today,
    required this.selectedDate,
    required this.direction,
    required this.onTapDate,
    required this.onLongPressDate,
    required this.onOpenDetail,
    required this.onShift,
  });

  final String month;
  final List<MonthDay> dates;
  final Map<String, WorkDayRecord> records;
  final Map<String, List<LedgerEntry>> entriesByDate;
  final String today;
  final String selectedDate;
  final int direction;
  final ValueChanged<String> onTapDate;
  final void Function(String date, Offset globalPosition) onLongPressDate;
  final VoidCallback onOpenDetail;
  final ValueChanged<int> onShift;

  @override
  State<_SwipeableCalendar> createState() => _SwipeableCalendarState();
}

class _SwipeableCalendarState extends State<_SwipeableCalendar>
    with SingleTickerProviderStateMixin {
  double _dragDx = 0;
  bool _dragging = false;
  _SwipeableCalendar? _outgoing;
  int _slideDirection = 1;
  late final AnimationController _slideController =
      AnimationController(
        vsync: this,
        duration: Timings.slow,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _outgoing = null);
        }
      });

  @override
  void didUpdateWidget(covariant _SwipeableCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month == widget.month) return;
    _outgoing = oldWidget;
    _slideDirection = widget.direction;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _outgoing = null;
      _slideController.value = 1;
    } else {
      _slideController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _startDrag(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _dragDx = 0;
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() => _dragDx += details.delta.dx);
  }

  void _endDrag(DragEndDetails details) {
    if (!_dragging) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final velocity = details.velocity.pixelsPerSecond.dx.clamp(-1000.0, 1000.0);
    final projected = _dragDx + velocity * 0.10;
    final threshold = width * 0.14 < 48 ? 48.0 : width * 0.14;
    if (projected.abs() >= threshold) {
      final direction = projected < 0 ? 1 : -1;
      HapticFeedback.selectionClick();
      setState(() {
        _dragging = false;
        _dragDx = 0;
      });
      widget.onShift(direction);
      return;
    }
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
  }

  void _cancelDrag() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final currentCard = _CalendarCard(
      month: widget.month,
      dates: widget.dates,
      records: widget.records,
      entriesByDate: widget.entriesByDate,
      today: widget.today,
      selectedDate: widget.selectedDate,
      onTapDate: widget.onTapDate,
      onLongPressDate: widget.onLongPressDate,
      onOpenDetail: widget.onOpenDetail,
    );
    final outgoing = _outgoing;
    final content = outgoing == null
        ? currentCard
        : AnimatedBuilder(
            animation: _slideController,
            builder: (context, _) {
              final progress = Curves2.out.transform(_slideController.value);
              final travel = MediaQuery.sizeOf(context).width * 0.16;
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  Opacity(
                    opacity: 1 - progress,
                    child: Transform.translate(
                      offset: Offset(-_slideDirection * travel * progress, 0),
                      child: _CalendarCard(
                        month: outgoing.month,
                        dates: outgoing.dates,
                        records: outgoing.records,
                        entriesByDate: outgoing.entriesByDate,
                        today: outgoing.today,
                        selectedDate: outgoing.selectedDate,
                        onTapDate: outgoing.onTapDate,
                        onLongPressDate: outgoing.onLongPressDate,
                        onOpenDetail: outgoing.onOpenDetail,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 0.65 + 0.35 * progress,
                    child: Transform.translate(
                      offset: Offset(
                        _slideDirection * travel * (1 - progress),
                        0,
                      ),
                      child: currentCard,
                    ),
                  ),
                ],
              );
            },
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: disable ? null : _startDrag,
      onHorizontalDragUpdate: disable ? null : _updateDrag,
      onHorizontalDragEnd: disable ? null : _endDrag,
      onHorizontalDragCancel: disable ? null : _cancelDrag,
      child: AnimatedContainer(
        duration: _dragging || disable
            ? Duration.zero
            : Timings.base,
        curve: Curves2.out,
        transform: Matrix4.translationValues(_dragDx * 0.55, 0, 0),
        child: ClipRect(
          child: AnimatedSize(
            duration: motionDuration(Timings.base, disableAnimations: disable),
            curve: Curves2.out,
            alignment: Alignment.topCenter,
            child: content,
          ),
        ),
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
    required this.selectedDate,
    required this.onTapDate,
    required this.onLongPressDate,
    required this.onOpenDetail,
  });

  final String month;
  final List<MonthDay> dates;
  final Map<String, WorkDayRecord> records;
  final Map<String, List<LedgerEntry>> entriesByDate;
  final String today;
  final String selectedDate;
  final ValueChanged<String> onTapDate;
  final void Function(String date, Offset globalPosition) onLongPressDate;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final leadingBlanks = dates.isEmpty ? 0 : (dates.first.weekday + 6) % 7;
    final recordedCount = records.values.where((r) => r.hours > 0).length;
    return GlassCard(
      radius: Radii.hero,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '本月日历',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: ShapeDecoration(
                  color: colors.primaryContainer.withValues(
                    alpha: colors.isDark ? 0.65 : 0.85,
                  ),
                  shape: Radii.pillShape,
                ),
                child: Text(
                  '已记 $recordedCount 天',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
              const Spacer(),
              Pressable(
                onTap: onOpenDetail,
                shape: Radii.pillShape,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '月明细',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.text3,
                      ),
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
              mainAxisSpacing: 4,
              crossAxisSpacing: 3,
              mainAxisExtent: 46 * textScale,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = dates[index - leadingBlanks];
              return _CalendarCell(
                day: day,
                record: records[day.date],
                entries: entriesByDate[day.date] ?? const [],
                isToday: day.date == today,
                isSelected: day.date == selectedDate,
                isFuture: day.date.compareTo(today) > 0,
                isWeekend: day.weekday == 0 || day.weekday == 6,
                onTap: () => onTapDate(day.date),
                onLongPress: (pos) => onLongPressDate(day.date, pos),
              );
            },
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: colors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!kHoursOnly) ...[
                _CalendarLegendDot(color: colors.income, label: '收入'),
                const SizedBox(width: 10),
                _CalendarLegendDot(color: colors.expense, label: '支出'),
                const SizedBox(width: 10),
              ],
              _CalendarLegendDot(
                color: colors.income,
                label: '已结算',
                pill: true,
              ),
              const SizedBox(width: 10),
              _CalendarLegendDot(
                color: colors.warning,
                label: '加班',
                pill: true,
                fillColor: colors.warningSoft,
              ),
              const Spacer(),
              Text(
                '长按快捷记录',
                style: TextStyle(fontSize: 11, color: colors.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  const _CalendarLegendDot({
    required this.color,
    required this.label,
    this.pill = false,
    this.fillColor,
  });

  final Color color;
  final String label;
  final bool pill;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pill)
          Container(
            width: 12,
            height: 8,
            decoration: BoxDecoration(
              color: fillColor ?? colors.incomeSoft,
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          )
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: colors.text3)),
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
    required this.isSelected,
    required this.isFuture,
    required this.isWeekend,
    required this.onTap,
    required this.onLongPress,
  });

  final MonthDay day;
  final WorkDayRecord? record;
  final List<LedgerEntry> entries;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final bool isWeekend;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasRecord = record != null;
    final hours = record?.hours ?? 0;
    final isRest = hasRecord && hours == 0;
    final isSettled = record?.settled == true;
    final isOvertime = hours > 8;

    var income = 0.0;
    var expense = 0.0;
    for (final entry in entries) {
      if (entry.type == LedgerType.income) {
        income += entry.amount;
      } else {
        expense += entry.amount;
      }
    }

    final cellBg = isSelected
        ? colors.primary
        : isSettled
        ? colors.incomeSoft.withValues(alpha: colors.isDark ? 0.65 : 0.80)
        : isOvertime
        ? colors.warningSoft.withValues(alpha: colors.isDark ? 0.68 : 0.86)
        : isToday
        ? colors.primaryContainer.withValues(alpha: colors.isDark ? 0.55 : 0.62)
        : Colors.transparent;

    final borderSide = isToday && !isSelected
        ? BorderSide(color: colors.primary.withValues(alpha: 0.55), width: 1.2)
        : isSelected
        ? BorderSide(
            color: Colors.white.withValues(alpha: colors.isDark ? 0.22 : 0.45),
            width: 1.0,
          )
        : isSettled && !isSelected
        ? BorderSide(color: colors.income.withValues(alpha: 0.20), width: 0.8)
        : isOvertime && !isSelected
        ? BorderSide(color: colors.warning.withValues(alpha: 0.22), width: 0.8)
        : BorderSide.none;

    final dayColor = isSelected
        ? colors.onPrimary
        : isToday
        ? colors.primary
        : isFuture
        ? colors.text3.withValues(alpha: 0.52)
        : isWeekend
        ? colors.text2
        : colors.text;

    final hoursColor = isSelected
        ? colors.onPrimary.withValues(alpha: 0.92)
        : isRest
        ? colors.text3
        : isSettled
        ? colors.income
        : isOvertime
        ? colors.warning
        : colors.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${day.day}日',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPressStart: isFuture
            ? null
            : (details) => onLongPress(details.globalPosition),
        child: Pressable(
          onTap: onTap,
          haptic: false,
          shape: Radii.shape(14),
          pressedScale: 0.92,
          child: AnimatedContainer(
            duration: motionDuration(
              Timings.micro,
              disableAnimations:
                  MediaQuery.maybeDisableAnimationsOf(context) ?? false,
            ),
            curve: Curves2.out,
            decoration: ShapeDecoration(
              color: isSelected ? null : cellBg,
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(
                          colors.primary,
                          Colors.white,
                          colors.isDark ? 0.08 : 0.14,
                        )!,
                        colors.primary,
                      ],
                    )
                  : null,
              shape: Radii.shape(14).copyWith(side: borderSide),
              shadows: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.1,
                    fontWeight: (isToday || isSelected)
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: dayColor,
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (hasRecord || !isFuture) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 13,
                    child: hasRecord
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isRest
                                  ? '休'
                                  : '${formatHoursValue(hours)}${context.unit.short}',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                                color: hoursColor,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          )
                        : Center(
                            child: Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: colors.outline.withValues(
                                  alpha: colors.isDark ? 0.28 : 0.34,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                  ),
                ],
                if (income > 0 || expense > 0) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (income > 0)
                          _CellDot(
                            color: isSelected
                                ? colors.onPrimary.withValues(alpha: 0.90)
                                : colors.income,
                          ),
                        if (expense > 0)
                          _CellDot(
                            color: isSelected
                                ? colors.onPrimary.withValues(alpha: 0.72)
                                : colors.expense,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// FlClash 风格首页卡片原位编辑区：轻摇摆（3.6s 周期 ±0.7° / 1.25dp）、
/// 拖动抬起 1.03× 缩放 + 阴影、角落移除徽标与底部可添加卡池。
class _DashboardLayoutEditor extends StatefulWidget {
  const _DashboardLayoutEditor({
    required this.cards,
    required this.labelOf,
    required this.onChanged,
    required this.onDone,
  });

  final List<String> cards;
  final String Function(String id) labelOf;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onDone;

  @override
  State<_DashboardLayoutEditor> createState() => _DashboardLayoutEditorState();
}

class _DashboardLayoutEditorState extends State<_DashboardLayoutEditor>
    with SingleTickerProviderStateMixin {
  static const _swaysPerLoop = [6, 7, 5];
  static const _swayPhaseStep = 1.7;
  static const _swayTurn = 0.7 * math.pi / 180;
  static const _swayBob = 1.25;
  static const _liftGrowth = 0.03;

  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: Timings.toast * 9,
  );
  bool _tickerEnabled = true;
  bool _disable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_disable || !_tickerEnabled) {
      _sway.stop();
    } else if (!_sway.isAnimating) {
      _sway.repeat();
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  IconData _iconOf(String cardId) => switch (cardId) {
    DashboardCardIds.monthSalary => Icons.payments_outlined,
    DashboardCardIds.ledgerBalance => Icons.account_balance_wallet_outlined,
    DashboardCardIds.todayLedger => Icons.receipt_long_outlined,
    _ => Icons.schedule_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final available = [
      for (final id in DashboardCardIds.all)
        if (!widget.cards.contains(id) &&
            (!kHoursOnly ||
                (id != DashboardCardIds.ledgerBalance &&
                    id != DashboardCardIds.todayLedger)))
          id,
    ];

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '编辑首页指标卡',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Text(
                '拖动排序',
                style: TextStyle(fontSize: 11.5, color: colors.text3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: widget.cards.length,
            onReorderItem: (oldIndex, newIndex) {
              HapticFeedback.selectionClick();
              final next = List<String>.of(widget.cards);
              final item = next.removeAt(oldIndex);
              next.insert(newIndex, item);
              widget.onChanged(next);
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, inner) {
                  final t = Curves2.out.transform(animation.value);
                  return Transform.scale(
                    scale: 1.0 + _liftGrowth * t,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: Radii.shape(Radii.md),
                        shadows: [
                          for (final shadow in context.floatingShadows)
                            shadow.copyWith(
                              color: shadow.color.withValues(
                                alpha: shadow.color.a * t,
                              ),
                            ),
                        ],
                      ),
                      child: inner,
                    ),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final id = widget.cards[index];
              final canRemove = widget.cards.length > 1;
              final row = Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(
                  color: colors.block,
                  shape: Radii.shape(Radii.md),
                ),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: colors.text3,
                        ),
                      ),
                    ),
                    Icon(_iconOf(id), size: 17, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.labelOf(id),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                    if (canRemove)
                      Pressable(
                        onTap: () {
                          final next = List<String>.of(widget.cards)
                            ..remove(id);
                          widget.onChanged(next);
                        },
                        shape: const CircleBorder(),
                        pressedScale: 0.90,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: colors.expenseSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 16,
                            color: colors.expense,
                          ),
                        ),
                      ),
                  ],
                ),
              );
              return RepaintBoundary(
                key: ValueKey('edit-card-$id'),
                child: _disable
                    ? row
                    : AnimatedBuilder(
                        animation: _sway,
                        child: row,
                        builder: (context, child) {
                          final swings =
                              _swaysPerLoop[index % _swaysPerLoop.length];
                          final turn =
                              _sway.value * 2 * math.pi * swings +
                              index * _swayPhaseStep;
                          return Transform.translate(
                            offset: Offset(0, math.cos(turn) * _swayBob),
                            child: Transform.rotate(
                              angle: math.sin(turn) * _swayTurn,
                              child: child,
                            ),
                          );
                        },
                      ),
              );
            },
          ),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '可添加卡片',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.text3,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in available)
                  Pressable(
                    onTap: () => widget.onChanged([...widget.cards, id]),
                    shape: Radii.pillShape,
                    pressedScale: 0.94,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: ShapeDecoration(
                        color: colors.primaryContainer,
                        shape: Radii.pillShape,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 15,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.labelOf(id),
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
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CellDot extends StatelessWidget {
  const _CellDot({required this.color});

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
    _hours.addListener(_onDraftInput);
    _fixedPay.addListener(_onDraftInput);
  }

  void _onDraftInput() {
    if (mounted) setState(() {});
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
    _hours.removeListener(_onDraftInput);
    _fixedPay.removeListener(_onDraftInput);
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
      title: '${formatDateLabel(_date)} ${context.unit.quantity}',
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
            label: context.unit.quantity,
            child: NumberField(
              controller: _hours,
              hintText: '0',
              suffixText: context.unit.name,
              autofocus: _record == null,
              onSubmitted: (_) => _remarkFocus.requestFocus(),
            ),
          ),
          QuickChips(
            values: context.unit.editorSteps,
            selected: _previewHours,
            labelOf: (value) => value == 0
                ? '休息'
                : '${formatHoursValue(value)}${context.unit.short}',
            onSelect: (value) {
              setState(() => _hours.text = formatHoursValue(value));
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
          if (!kHoursOnly) ...[
            FormRow(
              label: '工作',
              hint: '${context.unit.rateName}决定自动工资',
              child: Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                children: [
                  for (final profile in state.workProfiles)
                    Pressable(
                      onTap: () => setState(() => _workId = profile.id),
                      shape: Radii.shape(Radii.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: ShapeDecoration(
                          color: (_workId ?? defaultWorkId) == profile.id
                              ? colors.primaryContainer
                              : colors.block,
                          shape: Radii.shape(Radii.sm).copyWith(
                            side: BorderSide(
                              color: (_workId ?? defaultWorkId) == profile.id
                                  ? colors.primary.withValues(alpha: 0.35)
                                  : colors.cardBorder,
                            ),
                          ),
                        ),
                        child: Text(
                          '${profile.name}${profile.hourlyRate > 0 ? ' · ¥${formatRate(profile.hourlyRate)}/${context.unit.rateShort}' : ''}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: (_workId ?? defaultWorkId) == profile.id
                                ? FontWeight.w600
                                : FontWeight.w500,
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
              hint: '留空 = ${context.unit.quantity} × ${context.unit.rateName}',
              child: NumberField(
                controller: _fixedPay,
                hintText: '自动',
                suffixText: '元',
                fontSize: 18,
              ),
            ),
          ],
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
          if (!kHoursOnly) ...[
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
                    style: TextStyle(fontSize: 12.5, color: colors.text2),
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
          ],
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
          shape: Radii.shape(10),
          pressedScale: 0.92,
          child: Opacity(
            opacity: enabled ? 1 : 0.35,
            child: Container(
              width: 38,
              height: 36,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: colors.block,
                shape: Radii.shape(10),
              ),
              child: Icon(icon, size: 19, color: colors.text2),
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
                  label: context.unit.quantity,
                  value: formatHoursValue(record.hours),
                  unit: context.unit.name,
                  color: colors.primary,
                  tint: colors.primaryContainer.withValues(
                    alpha: colors.isDark ? 0.45 : 0.72,
                  ),
                ),
              ),
              if (!kHoursOnly) ...[
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: _DetailMetric(
                    label: '工资',
                    value: formatAmount(pay, withSymbol: true),
                    unit: '',
                    color: colors.income,
                    tint: colors.incomeSoft.withValues(
                      alpha: colors.isDark ? 0.50 : 0.78,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Gaps.lg),
          if (!kHoursOnly || record.remark.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: ShapeDecoration(
                color: colors.block.withValues(
                  alpha: colors.isDark ? 0.52 : 0.62,
                ),
                shape: Radii.shape(Radii.md),
              ),
              child: Column(
                children: [
                  if (!kHoursOnly) ...[
                    _DetailRow(label: '工作', value: work.name),
                    Divider(height: 1, color: colors.divider),
                    _DetailRow(
                      label: '有效${context.unit.rateName}',
                      value:
                          '¥${formatRate(effectiveRate(record, state.workProfiles))}'
                          '/${context.unit.rateShort}',
                    ),
                    if (hasFixedPay(record)) ...[
                      Divider(height: 1, color: colors.divider),
                      _DetailRow(
                        label: '自定义日薪',
                        value: formatAmount(record.fixedPay!, withSymbol: true),
                      ),
                    ],
                    Divider(height: 1, color: colors.divider),
                    _DetailRow(
                      label: '结算',
                      value: record.settled
                          ? (pay > 0 ? '已结算' : '已结算（¥0）')
                          : '未结算',
                      valueColor: record.settled ? colors.income : colors.text2,
                    ),
                  ],
                  if (record.remark.isNotEmpty) ...[
                    if (!kHoursOnly) Divider(height: 1, color: colors.divider),
                    _DetailRow(label: '备注', value: record.remark),
                  ],
                ],
              ),
            ),
          const SizedBox(height: Gaps.xl),
          Row(
            children: [
              if (!kHoursOnly) ...[
                Expanded(
                  child: GhostButton(
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
              ],
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
            expand: true,
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
                    content: const Text('已删除 · 可撤销'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: '撤销',
                      onPressed: () {
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
    required this.tint,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: ShapeDecoration(
        color: tint,
        shape: Radii.shape(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colors.text2,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: color,
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.text2,
                      ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? colors.text,
                height: 1.4,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
