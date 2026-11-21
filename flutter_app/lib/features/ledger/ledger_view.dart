import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/ledger.dart';
import '../../data/models.dart';
import '../../data/records.dart';
import '../../data/wage_entries.dart';
import '../../state/app_controller.dart';
import '../../ui/date_wheel.dart';
import '../../ui/dialog.dart';
import '../../ui/export_sheet.dart';
import '../../ui/glass_menu.dart';
import '../../ui/month_picker.dart';
import '../../ui/pinned_header.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';
import '../work/budget_panel.dart';
import 'category_manager.dart';

/// 账本页：月份切换与工时页统一 + 收支汇总 + 预算进度 + 按日分组流水。
class LedgerView extends ConsumerStatefulWidget {
  const LedgerView({super.key});

  @override
  ConsumerState<LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends ConsumerState<LedgerView> {
  final TextEditingController _search = TextEditingController();
  LedgerEntry? _undoEntry;
  Timer? _undoTimer;
  Timer? _searchTimer;
  bool _searching = false;
  bool _fabExpanded = true;
  String _searchQuery = '';
  String _categoryFilter = '';

  @override
  void dispose() {
    _search.dispose();
    _undoTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  void _showUndo(LedgerEntry entry) {
    setState(() => _undoEntry = entry);
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _undoEntry = null);
    });
  }

  bool _isManagedEntry(LedgerEntry entry) {
    final date = entry.workDate ?? entry.date;
    return isValidDateISO(date) && entry.id == getWageEntryId(date);
  }

  void _hintManagedEntry() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('这笔工资由结算自动生成，直接改会被下次对账覆盖；要调整请撤销该日结算'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _revokeSettlement(LedgerEntry entry) async {
    final date =
        entry.workDate ??
        (entry.id.startsWith(wageEntryIdPrefix)
            ? entry.id.substring(wageEntryIdPrefix.length)
            : '');
    if (!isValidDateISO(date)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('这笔工资账目缺少有效日期，无法撤销结算'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '撤销 ${formatDateLabel(date)} 的结算？',
      description: '会取消这一天的结算状态，并移除这笔工资收入。',
      confirmLabel: '撤销结算',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    ref.read(appControllerProvider.notifier).setRecordSettled(date, false);
    await HapticFeedback.selectionClick();
  }

  Future<void> _confirmDeleteEntry(LedgerEntry entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除这条账目？',
      description: '删除后 6 秒内可撤销。',
      confirmLabel: '删除',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final removed = ref
        .read(appControllerProvider.notifier)
        .deleteLedgerEntry(entry.id);
    if (removed != null) _showUndo(removed);
  }

  void _showEntryContextMenu(
    BuildContext context, {
    required LedgerEntry entry,
    required bool managed,
    required Offset globalPosition,
  }) {
    HapticFeedback.mediumImpact();
    final items = managed
        ? <GlassMenuAction>[
            GlassMenuAction(
              label: '查看同步说明',
              icon: Icons.info_outline_rounded,
              onSelected: _hintManagedEntry,
            ),
            GlassMenuAction(
              label: '撤销该日结算',
              icon: Icons.undo_rounded,
              danger: true,
              dividerBefore: true,
              onSelected: () => unawaited(_revokeSettlement(entry)),
            ),
          ]
        : <GlassMenuAction>[
            GlassMenuAction(
              label: '编辑账目',
              icon: Icons.edit_outlined,
              onSelected: () => showLedgerEditor(context, entry: entry),
            ),
            GlassMenuAction(
              label: '再记一笔同分类',
              icon: Icons.control_point_duplicate_rounded,
              onSelected: () => showLedgerEditor(
                context,
                presetType: entry.type,
                presetCategory: entry.category,
              ),
            ),
            GlassMenuAction(
              label: '删除账目',
              icon: Icons.delete_outline_rounded,
              danger: true,
              dividerBefore: true,
              onSelected: () => unawaited(_confirmDeleteEntry(entry)),
            ),
          ];
    unawaited(
      showDropletGlassMenu(
        context,
        anchorOffset: globalPosition,
        panelWidth: 184,
        preferRightAlign:
            globalPosition.dx > MediaQuery.sizeOf(context).width * 0.48,
        items: items,
      ),
    );
  }

  Widget _entryRow(LedgerEntry entry, List<WorkDayRecord> records) {
    final managed = _isManagedEntry(entry);
    return _EntryRow(
      entry: entry,
      managed: managed,
      deleteLabel: managed ? '撤销该日结算' : '删除',
      linkedHours: entry.workDate == null
          ? null
          : getRecordByDate(records, entry.workDate!)?.hours,
      onTap: managed
          ? _hintManagedEntry
          : () => showLedgerEditor(context, entry: entry),
      onLongPressStart: (details) => _showEntryContextMenu(
        context,
        entry: entry,
        managed: managed,
        globalPosition: details.globalPosition,
      ),
      onDelete: managed
          ? () {
              unawaited(_revokeSettlement(entry));
            }
          : () {
              unawaited(_confirmDeleteEntry(entry));
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final month = ref.watch(selectedMonthProvider);
    ref.listen<String>(selectedMonthProvider, (previous, next) {
      if (previous != next && _categoryFilter.isNotEmpty) {
        setState(() => _categoryFilter = '');
      }
    });
    final summary = getLedgerMonthSummary(state.entries, month);
    final budget = ref.watch(budgetTargetsProvider).monthlyExpenseBudget;
    final keyword = _searchQuery;
    final baseEntries = getLedgerMonthEntries(state.entries, month);
    final filteredByCategory = baseEntries.where((entry) {
      if (_categoryFilter.isEmpty) return true;
      if (_categoryFilter.startsWith('type:')) {
        return entry.type ==
            parseLedgerType(_categoryFilter.substring('type:'.length));
      }
      if (_categoryFilter.startsWith('cat:')) {
        final rest = _categoryFilter.substring('cat:'.length);
        final split = rest.indexOf(':');
        if (split <= 0) return true;
        final type = parseLedgerType(rest.substring(0, split));
        final name = rest.substring(split + 1);
        return entry.type == type && entry.category == name;
      }
      return true;
    });
    final monthEntries = filteredByCategory.where((entry) {
      if (keyword.isEmpty) return true;
      final normalizedKeyword = keyword.toLowerCase();
      final dateKeyword = keyword.replaceAll('-', '');
      return entry.category.toLowerCase().contains(normalizedKeyword) ||
          entry.remark.toLowerCase().contains(normalizedKeyword) ||
          entry.date.replaceAll('-', '').contains(dateKeyword) ||
          formatAmount(entry.amount).contains(keyword);
    }).toList();

    final seenCategories = <String>{};
    final categoryChips =
        <({String key, String label, LedgerType? type})>[];
    for (final entry in baseEntries) {
      final key = 'cat:${ledgerTypeValue(entry.type)}:${entry.category}';
      if (seenCategories.add(key)) {
        categoryChips.add((
          key: key,
          label: entry.category,
          type: entry.type,
        ));
      }
    }
    final filterChips = <({String key, String label, LedgerType? type})>[
      (key: '', label: '全部', type: null),
      (key: 'type:expense', label: '支出', type: null),
      (key: 'type:income', label: '收入', type: null),
      ...categoryChips,
    ];

    final today = todayISO();
    final yesterday = shiftDate(today, -1);
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

    // 按日期分组（保留原本的倒序）
    final groupedDates = <String>[];
    final entriesByDate = <String, List<LedgerEntry>>{};
    for (final entry in monthEntries) {
      if (!entriesByDate.containsKey(entry.date)) {
        groupedDates.add(entry.date);
        entriesByDate[entry.date] = [];
      }
      entriesByDate[entry.date]!.add(entry);
    }

    final wide = MediaQuery.sizeOf(context).width >= 720;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fabBottom = wide
        ? bottomPad + 20.0
        : math.max(86.0, bottomPad + 82.0);

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;
              if (notification.direction == ScrollDirection.reverse &&
                  _fabExpanded) {
                setState(() => _fabExpanded = false);
              } else if (notification.direction == ScrollDirection.forward &&
                  !_fabExpanded) {
                setState(() => _fabExpanded = true);
              }
              return false;
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    Gaps.lg,
                    MorphingSearchHeader.totalHeight(context) + 12,
                    Gaps.lg,
                    Gaps.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RepaintBoundary(
                          child: _BalanceSummaryCard(
                            month: month,
                            summary: summary,
                            budget: budget,
                            entryCount: baseEntries.length,
                            todayCount: todayEntries.length,
                            todayIncome: todayIncome,
                            todayExpense: todayExpense,
                            onOpenBudget: () => showBudgetPanel(context),
                          ),
                        ),
                        const SizedBox(height: Gaps.cardGap),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < filterChips.length;
                                index++
                              ) ...[
                                if (index == 3)
                                  Container(
                                    width: 1,
                                    height: 16,
                                    margin: const EdgeInsets.only(right: 8),
                                    color: context.colors.divider,
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _FilterChipPill(
                                    label: filterChips[index].label,
                                    icon: filterChips[index].type == null
                                        ? null
                                        : _categoryVisual(
                                            filterChips[index].label,
                                            filterChips[index].type ==
                                                LedgerType.income,
                                            context.colors,
                                          ).icon,
                                    selected:
                                        _categoryFilter == filterChips[index].key,
                                    onTap: () => setState(
                                      () => _categoryFilter =
                                          filterChips[index].key,
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
                if (monthEntries.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Gaps.lg,
                      0,
                      Gaps.lg,
                      pageBottomInset(context) + 76,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: GlassCard(
                        child: EmptyState(
                          title: baseEntries.isEmpty
                              ? '${formatMonthLabel(month)} 还没有账目'
                              : '没有匹配的账目',
                          description: baseEntries.isEmpty
                              ? '记录日常开销、外快或从${context.unit.quantity}页结算工资。'
                              : '换个关键词或筛选条件试试。',
                          action: baseEntries.isEmpty
                              ? PrimaryButton(
                                  label: '记一笔',
                                  icon: Icons.add_rounded,
                                  onPressed: () => showLedgerEditor(context),
                                )
                              : GhostButton(
                                  label: '清除筛选',
                                  onPressed: () {
                                    _searchTimer?.cancel();
                                    _search.clear();
                                    setState(() {
                                      _categoryFilter = '';
                                      _searchQuery = '';
                                      _searching = false;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Gaps.lg,
                      0,
                      Gaps.lg,
                      pageBottomInset(context) + 76,
                    ),
                    sliver: SliverList.builder(
                      itemCount: groupedDates.length,
                      itemBuilder: (context, index) {
                        final date = groupedDates[index];
                        return _DateGroupSection(
                          date: date,
                          today: today,
                          yesterday: yesterday,
                          entries: entriesByDate[date]!,
                          isFirst: index == 0,
                          isLast: index == groupedDates.length - 1,
                          buildRow: (entry) => _entryRow(entry, state.records),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: fabBottom + 56,
          child: IgnorePointer(
            ignoring: _undoEntry == null,
            child: AnimatedSwitcher(
              duration: motionDuration(
                Timings.base,
                disableAnimations: disable,
              ),
              reverseDuration: motionDuration(
                Timings.fast,
                disableAnimations: disable,
              ),
              switchInCurve: Curves2.out,
              switchOutCurve: Curves2.out,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.32),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _undoEntry == null
                  ? const SizedBox.shrink(key: ValueKey('undo-empty'))
                  : UndoBar(
                      key: ValueKey('undo-${_undoEntry!.id}'),
                      message:
                          '已删除 ${_undoEntry!.category} ${formatAmount(_undoEntry!.amount, withSymbol: true)}',
                      onUndo: () {
                        _undoTimer?.cancel();
                        ref
                            .read(appControllerProvider.notifier)
                            .saveLedgerEntry(_undoEntry!);
                        setState(() => _undoEntry = null);
                      },
                    ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: fabBottom,
          child: _AddLedgerFab(
            expanded: _fabExpanded,
            onTap: () => showLedgerEditor(context),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: MorphingSearchHeader(
            title: '账本',
            searching: _searching,
            controller: _search,
            hintText: '搜索分类、备注、金额或日期',
            onSearchingChanged: (value) => setState(() => _searching = value),
            onQueryChanged: _onSearchChanged,
            onClearQuery: () {
              _searchTimer?.cancel();
              _search.clear();
              setState(() => _searchQuery = '');
            },
            middleAction: MonthSwitchPill(
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
            trailingAction: GlassMenuButton(
              tooltip: '更多操作',
              items: [
                GlassMenuAction(
                  label: '导出本月账本',
                  icon: Icons.download_rounded,
                  onSelected: () => showExportSheet(
                    context,
                    month: month,
                    records: state.records,
                    entries: state.entries,
                  ),
                ),
                GlassMenuAction(
                  label: '回到本月',
                  icon: Icons.today_rounded,
                  onSelected: () => ref
                      .read(selectedMonthProvider.notifier)
                      .setMonth(currentMonthKey()),
                ),
                GlassMenuAction(
                  label: '分类管理',
                  icon: Icons.sell_outlined,
                  dividerBefore: true,
                  sectionTitle: '快捷管理',
                  onSelected: () => showCategoryManager(context),
                ),
                GlassMenuAction(
                  label: '预算设置',
                  icon: Icons.track_changes_rounded,
                  onSelected: () => showBudgetPanel(context),
                ),
                if (_categoryFilter.isNotEmpty || _searchQuery.isNotEmpty)
                  GlassMenuAction(
                    label: '清除筛选',
                    icon: Icons.filter_alt_off_rounded,
                    dividerBefore: true,
                    onSelected: () => setState(() {
                      _searchTimer?.cancel();
                      _categoryFilter = '';
                      _search.clear();
                      _searchQuery = '';
                      _searching = false;
                    }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({
    required this.month,
    required this.summary,
    required this.budget,
    required this.entryCount,
    required this.todayCount,
    required this.todayIncome,
    required this.todayExpense,
    required this.onOpenBudget,
  });

  final String month;
  final LedgerMonthSummary summary;
  final double budget;
  final int entryCount;
  final int todayCount;
  final double todayIncome;
  final double todayExpense;
  final VoidCallback onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrent = month == currentMonthKey();
    final ratio = budget > 0 ? (summary.expense / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = budget > 0 && summary.expense > budget;
    final budgetColor = overBudget
        ? colors.expense
        : ratio >= 0.8
        ? colors.warning
        : colors.primary;

    final statusText = isCurrent
        ? (todayCount == 0
              ? '今日暂无账目'
              : '今日 $todayCount 笔'
                    '${todayIncome > 0 ? ' · +${formatAmount(todayIncome, withSymbol: true)}' : ''}'
                    '${todayExpense > 0 ? ' · -${formatAmount(todayExpense, withSymbol: true)}' : ''}')
        : '共 $entryCount 笔账目';

    return GlassCard(
      radius: Radii.hero,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isCurrent ? '本月结余' : '当月结余',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: colors.text2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colors.text3,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  summary.balance < 0 ? '-¥' : '¥',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    color: summary.balance < 0 ? colors.expense : colors.text2,
                  ),
                ),
                const SizedBox(width: 2),
                AnimatedNumericText(
                  value: summary.balance.abs(),
                  formatter: (value) =>
                      formatAmount(value.toDouble(), withSymbol: false),
                  style: TextStyle(
                    fontSize: 42,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.6,
                    color: summary.balance >= 0 ? colors.text : colors.expense,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CashflowRatioBar(
            income: summary.income,
            expense: summary.expense,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SideMetric(
                    label: '本月收入',
                    value: summary.income,
                    color: colors.income,
                  ),
                ),
                Container(
                  width: 0.7,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  color: colors.divider,
                ),
                Expanded(
                  child: _SideMetric(
                    label: '本月支出',
                    value: summary.expense,
                    color: colors.expense,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.7, color: colors.divider),
          const SizedBox(height: 10),
          Pressable(
            onTap: onOpenBudget,
            shape: Radii.shape(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: budget > 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              overBudget
                                  ? '已超预算 ${formatAmount(summary.expense - budget, withSymbol: true)}'
                                  : '支出预算已用 ${((summary.expense / budget) * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: overBudget
                                    ? colors.expense
                                    : colors.text2,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${formatAmount(summary.expense, withSymbol: true)} / ${formatAmount(budget, withSymbol: true)}',
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
                          ratio: ratio,
                          color: budgetColor,
                          height: 3.5,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.track_changes_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '设置本月支出预算与收入目标',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: colors.primary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: colors.primary,
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

/// 收支双段比例条：一眼读懂本月流入与流出结构，零数据时保持克制细轨。
class _CashflowRatioBar extends StatelessWidget {
  const _CashflowRatioBar({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = income + expense;
    if (total <= 0) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: colors.block,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    final incomeFlex = (income / total * 1000).round().clamp(0, 1000);
    final expenseFlex = (expense / total * 1000).round().clamp(0, 1000);
    return SizedBox(
      height: 7,
      child: Row(
        children: [
          if (incomeFlex > 0)
            Expanded(
              flex: incomeFlex,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.income,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          if (incomeFlex > 0 && expenseFlex > 0) const SizedBox(width: 4),
          if (expenseFlex > 0)
            Expanded(
              flex: expenseFlex,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.expense,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideMetric extends StatelessWidget {
  const _SideMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valueColor = value == 0 ? colors.text3 : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: colors.text3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedNumericText(
            value: value,
            formatter: (v) => formatAmount(v.toDouble(), withSymbol: true),
            style: TextStyle(
              fontSize: 17,
              height: 1.15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.pillShape,
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: motionDuration(
            Timings.micro,
            disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
          ),
          curve: Curves2.out,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: ShapeDecoration(
            color: selected ? colors.heroHighlight : colors.card,
            shape: Radii.pillShape.copyWith(
              side: selected
                  ? BorderSide.none
                  : BorderSide(
                      color: colors.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFF0F172A).withValues(alpha: 0.065),
                      width: 0.75,
                    ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : colors.text2,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: TypeScale.label,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : colors.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateGroupSection extends StatelessWidget {
  const _DateGroupSection({
    required this.date,
    required this.today,
    required this.yesterday,
    required this.entries,
    required this.isFirst,
    required this.isLast,
    required this.buildRow,
  });

  final String date;
  final String today;
  final String yesterday;
  final List<LedgerEntry> entries;
  final bool isFirst;
  final bool isLast;
  final Widget Function(LedgerEntry entry) buildRow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final parsed = DateTime.tryParse(date);
    final weekday = parsed == null ? '' : '周${weekdayName(parsed.weekday % 7)}';
    final relativeTag = date == today
        ? '今天'
        : date == yesterday
        ? '昨天'
        : null;
    var dayIncome = 0.0;
    var dayExpense = 0.0;
    for (final entry in entries) {
      if (entry.type == LedgerType.income) {
        dayIncome += entry.amount;
      } else {
        dayExpense += entry.amount;
      }
    }
    final summaryParts = <String>[
      if (dayIncome > 0) '收 ${formatAmount(dayIncome, withSymbol: true)}',
      if (dayExpense > 0) '支 ${formatAmount(dayExpense, withSymbol: true)}',
    ];

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 2 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                if (relativeTag != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.5,
                      vertical: 2,
                    ),
                    decoration: ShapeDecoration(
                      color: date == today ? colors.primary : colors.block,
                      shape: Radii.shape(6),
                    ),
                    child: Text(
                      relativeTag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: date == today ? colors.onPrimary : colors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${formatDateLabel(date)} · $weekday',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text2,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Text(
                  summaryParts.join(' · '),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: colors.text3,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            radius: Radii.card,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      indent: 48,
                      color: colors.divider,
                    ),
                  buildRow(entries[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color color}) _categoryVisual(
  String category,
  bool isIncome,
  AppColors colors,
) {
  final label = category.trim();
  if (isIncome) {
    if (label == '工资' || label.contains('薪') || label.contains('工资')) {
      return (icon: Icons.account_balance_wallet_rounded, color: colors.income);
    }
    if (label == '奖金' || label.contains('奖') || label.contains('红包')) {
      return (icon: Icons.emoji_events_rounded, color: colors.warning);
    }
    if (label == '兼职' || label.contains('兼职') || label.contains('外快')) {
      return (icon: Icons.work_outline_rounded, color: colors.primary);
    }
    if (label == '报销' || label.contains('报销') || label.contains('退')) {
      return (icon: Icons.receipt_long_rounded, color: const Color(0xFF5856D6));
    }
    return (icon: Icons.savings_outlined, color: colors.income);
  }
  if (label == '餐饮' ||
      label.contains('饭') ||
      label.contains('餐') ||
      label.contains('吃') ||
      label.contains('外卖') ||
      label.contains('咖啡') ||
      label.contains('奶茶')) {
    return (icon: Icons.restaurant_rounded, color: const Color(0xFFFF9500));
  }
  if (label == '交通' ||
      label.contains('车') ||
      label.contains('地铁') ||
      label.contains('公交') ||
      label.contains('油') ||
      label.contains('机票') ||
      label.contains('出行')) {
    return (icon: Icons.directions_transit_rounded, color: colors.primary);
  }
  if (label == '购物' ||
      label.contains('买') ||
      label.contains('购') ||
      label.contains('衣') ||
      label.contains('鞋') ||
      label.contains('数码')) {
    return (icon: Icons.shopping_bag_outlined, color: const Color(0xFFEC4899));
  }
  if (label == '居住' ||
      label == '居家' ||
      label.contains('房') ||
      label.contains('水电') ||
      label.contains('租') ||
      label.contains('居')) {
    return (icon: Icons.home_outlined, color: const Color(0xFF5856D6));
  }
  if (label == '医疗' ||
      label.contains('医') ||
      label.contains('药') ||
      label.contains('健康')) {
    return (
      icon: Icons.medical_services_outlined,
      color: colors.expense,
    );
  }
  if (label == '学习' ||
      label.contains('书') ||
      label.contains('课') ||
      label.contains('学')) {
    return (icon: Icons.menu_book_rounded, color: const Color(0xFF0EA5E9));
  }
  if (label == '娱乐' ||
      label.contains('影') ||
      label.contains('游') ||
      label.contains('玩') ||
      label.contains('娱')) {
    return (icon: Icons.sports_esports_rounded, color: const Color(0xFFAF52DE));
  }
  return (icon: Icons.local_offer_outlined, color: colors.text2);
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.linkedHours,
    required this.onTap,
    required this.onLongPressStart,
    required this.onDelete,
    this.managed = false,
    this.deleteLabel = '删除',
  });

  final LedgerEntry entry;
  final double? linkedHours;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final VoidCallback onDelete;
  final bool managed;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isIncome = entry.type == LedgerType.income;
    final visual = _categoryVisual(entry.category, isIncome, colors);
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gaps.md),
        child: Icon(
          managed ? Icons.undo_rounded : Icons.delete_outline_rounded,
          color: managed ? colors.text2 : colors.expense,
        ),
      ),
      child: Semantics(
        button: true,
        label:
            '${entry.category}，${isIncome ? '收入' : '支出'} '
            '${formatAmount(entry.amount)}，${formatDateLabel(entry.date)}'
            '${managed ? '，由结算自动生成' : ''}',
        onTap: onTap,
        customSemanticsActions: {
          CustomSemanticsAction(label: deleteLabel): onDelete,
        },
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: onLongPressStart,
          child: Pressable(
            onTap: onTap,
            shape: Radii.shape(Radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: ShapeDecoration(
                      color: visual.color.withValues(
                        alpha: colors.isDark ? 0.18 : 0.10,
                      ),
                      shape: Radii.shape(10),
                    ),
                    child: Icon(
                      visual.icon,
                      size: 18,
                      color: visual.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                            ),
                            if (managed) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: ShapeDecoration(
                                  color: colors.block,
                                  shape: Radii.shape(5),
                                ),
                                child: Text(
                                  '结算同步',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: colors.text3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (entry.remark.isNotEmpty || linkedHours != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (entry.remark.isNotEmpty) entry.remark,
                              if (linkedHours != null)
                                '关联 ${formatHoursValue(linkedHours!)} ${context.unit.name}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: colors.text3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: isIncome ? '+¥' : '-¥',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: (isIncome ? colors.income : colors.expense)
                                .withValues(alpha: 0.80),
                          ),
                        ),
                        TextSpan(
                          text: formatAmount(entry.amount, withSymbol: false),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isIncome ? colors.income : colors.expense,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLedgerFab extends StatelessWidget {
  const _AddLedgerFab({required this.onTap, this.expanded = true});

  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      label: '记一笔',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.pillShape,
        pressedScale: 0.94,
        child: Container(
          height: 44,
          padding: EdgeInsets.only(
            left: expanded ? 13 : 12,
            right: expanded ? 16 : 12,
          ),
          decoration: ShapeDecoration(
            color: colors.primary,
            shape: Radii.pillShape,
            shadows: [
              BoxShadow(
                color: colors.primary.withValues(
                  alpha: colors.isDark ? 0.42 : 0.32,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(
                  alpha: colors.isDark ? 0.24 : 0.08,
                ),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: motionDuration(Timings.fast, disableAnimations: disable),
            curve: Curves2.out,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 19.5,
                  color: colors.onPrimary,
                ),
                AnimatedSwitcher(
                  duration: motionDuration(
                    Timings.fast,
                    disableAnimations: disable,
                  ),
                  switchInCurve: Curves2.out,
                  switchOutCurve: Curves2.out,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: expanded
                      ? Padding(
                          key: const ValueKey('fab-label'),
                          padding: const EdgeInsets.only(left: 5),
                          child: Text(
                            '记一笔',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.onPrimary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('fab-compact')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 编辑器

Future<void> showLedgerEditor(
  BuildContext context, {
  LedgerEntry? entry,
  String? presetDate,
  LedgerType? presetType,
  String? presetCategory,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(archiveReadOnlyProvider)) {
    showArchiveReadOnlyMessage(context);
    return Future<void>.value();
  }
  return showAppSheet<void>(
    context: context,
    dismissible: false,
    builder: (_) => LedgerEditorSheet(
      entry: entry,
      presetDate: presetDate,
      presetType: presetType,
      presetCategory: presetCategory,
    ),
  );
}

class LedgerEditorSheet extends ConsumerStatefulWidget {
  const LedgerEditorSheet({
    super.key,
    this.entry,
    this.presetDate,
    this.presetType,
    this.presetCategory,
  });

  final LedgerEntry? entry;
  final String? presetDate;
  final LedgerType? presetType;
  final String? presetCategory;

  @override
  ConsumerState<LedgerEditorSheet> createState() => _LedgerEditorSheetState();
}

class _LedgerEditorSheetState extends ConsumerState<LedgerEditorSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _remark;
  late LedgerType _type;
  late String _date;
  late String _category;
  String? _error;
  bool _submitted = false;

  late final String _initialAmount;
  late final String _initialRemark;
  late final LedgerType _initialType;
  late final String _initialDate;
  late final String _initialCategory;

  bool get _isDirty =>
      _amount.text != _initialAmount ||
      _remark.text != _initialRemark ||
      _type != _initialType ||
      _date != _initialDate ||
      _category != _initialCategory;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _initialType = entry?.type ?? widget.presetType ?? LedgerType.expense;
    _initialDate = entry?.date ?? widget.presetDate ?? todayISO();
    _initialCategory =
        entry?.category ??
        widget.presetCategory ??
        defaultCategoriesOf(_initialType).first;
    _initialAmount = entry == null ? '' : formatAmountInput(entry.amount);
    _initialRemark = entry?.remark ?? '';
    _type = _initialType;
    _date = _initialDate;
    _category = _initialCategory;
    _amount = TextEditingController(text: _initialAmount);
    _remark = TextEditingController(text: _initialRemark);
  }

  @override
  void dispose() {
    _amount.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = parseAmountInput(_amount.text);
    if (parsed is! AmountInputOk) {
      setState(() => _error = (parsed as AmountInputError).message);
      return;
    }
    final entry = LedgerEntry(
      id: widget.entry?.id ?? createLedgerEntryId(),
      date: _date,
      type: _type,
      amount: parsed.amount,
      category: _category,
      remark: _remark.text.trim(),
      workDate: widget.entry?.workDate,
    );
    ref.read(appControllerProvider.notifier).saveLedgerEntry(entry);
    final targetMonth = _date.substring(0, 7);
    final selectedMonth = ref.read(selectedMonthProvider);
    if (targetMonth != selectedMonth) {
      ref.read(selectedMonthProvider.notifier).setMonth(targetMonth);
      final messenger = ScaffoldMessenger.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('已保存到 ${formatMonthLabel(targetMonth)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
    HapticFeedback.mediumImpact();
    _submitted = true;
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDateWheel(
      context,
      initialDate: _date,
      maxDate: todayISO(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final categories = getAvailableLedgerCategories(
      _type,
      state.customCategories,
      extraCategory: widget.entry?.category,
    );
    return SheetScaffold(
      title: widget.entry == null ? '记一笔' : '编辑账目',
      guard: () => _isDirty && !_submitted,
      actions: [TextActionButton(label: '保存', onPressed: _save)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Segmented<LedgerType>(
            values: const [LedgerType.expense, LedgerType.income],
            selected: _type,
            accentActive: true,
            labelOf: (type) => type == LedgerType.expense ? '支出' : '收入',
            onChanged: (type) => setState(() {
              _type = type;
              _category = defaultCategoriesOf(type).first;
            }),
          ),
          const SizedBox(height: Gaps.lg),
          NumberField(
            controller: _amount,
            hintText: '0.00',
            suffixText: '元',
            autofocus: widget.entry == null,
            fontSize: 30,
          ),
          const SizedBox(height: Gaps.md),
          QuickChips(
            values: const [10, 20, 50, 100, 200, 500],
            onSelect: (value) {
              _amount.text = formatAmountInput(value);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: Gaps.sm),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: colors.expense),
            ),
          ],
          const SizedBox(height: Gaps.xl),
          FormRow(
            label: '分类',
            child: Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                for (final category in categories) ...[
                  Pressable(
                    onTap: () => setState(() => _category = category),
                    shape: Radii.pillShape,
                    pressedScale: 0.96,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: ShapeDecoration(
                        color: _category == category
                            ? colors.primary
                            : colors.block,
                        shape: Radii.pillShape,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryVisual(
                              category,
                              _type == LedgerType.income,
                              colors,
                            ).icon,
                            size: 14,
                            color: _category == category
                                ? colors.onPrimary
                                : colors.text2,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _category == category
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _category == category
                                  ? colors.onPrimary
                                  : colors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          FormRow(
            label: '日期',
            child: GhostButton(
              label: formatDateLabel(_date),
              icon: Icons.calendar_today_rounded,
              onPressed: _pickDate,
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
                maxLength: maxLedgerRemarkLength,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: '写点什么',
                ),
              ),
            ),
          ),
          PrimaryButton(label: '保存', expand: true, onPressed: _save),
        ],
      ),
    );
  }
}
