import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluid_glass/fluid_glass.dart';

import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/ledger.dart';
import '../../data/models.dart';
import '../../data/records.dart';
import '../../data/wage_entries.dart';
import '../../state/app_controller.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import '../../ui/date_wheel.dart';
import '../../ui/dialog.dart';
import '../../ui/export_sheet.dart';
import '../../ui/glass_menu.dart';
import '../../ui/month_picker.dart';
import '../../ui/pinned_header.dart';
import 'category_manager.dart';

/// 记账页：月份 + 收支汇总 + 搜索 + 明细列表。
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

  /// 系统生成的工资账目（`wage-<date>`）：账本里只读。
  ///
  /// 它的金额来自结算那一刻的 `recordPay`，而 `syncWageEntries` 不会更新
  /// 既有条目的金额。允许直接改金额/分类，会让工资面板的"已结算"与账本
  /// 收入永久分叉；允许删除，则下次对账又悄悄把它建回来。
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
      onDelete: managed
          ? () {
              unawaited(_revokeSettlement(entry));
            }
          : () async {
              final confirmed = await showConfirmDialog(
                context,
                title: '删除这条账目？',
                description: '删除后 6 秒内可撤销。',
                confirmLabel: '删除',
                danger: true,
              );
              if (confirmed != true) return;
              if (!context.mounted) return;
              final removed = ref
                  .read(appControllerProvider.notifier)
                  .deleteLedgerEntry(entry.id);
              if (removed != null) _showUndo(removed);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final month = ref.watch(selectedMonthProvider);
    // 切月复位分类筛选：否则旧分类的 chip 会一直高亮，而新月份没有该分类
    // 账目时列表为空，容易被读成「本月数据丢了」。
    ref.listen<String>(selectedMonthProvider, (previous, next) {
      if (previous != next && _categoryFilter.isNotEmpty) {
        setState(() => _categoryFilter = '');
      }
    });
    final summary = getLedgerMonthSummary(state.entries, month);
    final budget = ref.watch(budgetTargetsProvider).monthlyExpenseBudget;
    final overBudget = budget > 0 && summary.expense > budget;
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
    final categoryChips = <({String key, String label})>[];
    for (final entry in baseEntries) {
      final key = 'cat:${ledgerTypeValue(entry.type)}:${entry.category}';
      if (seenCategories.add(key)) {
        categoryChips.add((key: key, label: entry.category));
      }
    }
    final filterChips = <({String key, String label})>[
      (key: '', label: '全部'),
      if (!kHoursOnly) ...[
        (key: 'type:income', label: '收入'),
        (key: 'type:expense', label: '支出'),
      ],
      ...categoryChips,
    ];
    final today = todayISO();
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

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    _BalanceCard(
                      month: month,
                      summary: summary,
                      todayCount: todayEntries.length,
                      todayIncome: todayIncome,
                      todayExpense: todayExpense,
                      onChanged: (value) => ref
                          .read(selectedMonthProvider.notifier)
                          .setMonth(value),
                      onPick: () async {
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
                    ),
                    if (overBudget) ...[
                      const SizedBox(height: Gaps.md),
                      _OverBudgetBar(expense: summary.expense, budget: budget),
                    ],
                    if (filterChips.length > 3) ...[
                      const SizedBox(height: Gaps.md),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final chip in filterChips)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Semantics(
                                  button: true,
                                  selected: _categoryFilter == chip.key,
                                  label: chip.label,
                                  onTap: () => setState(
                                    () => _categoryFilter = chip.key,
                                  ),
                                  excludeSemantics: true,
                                  child: Pressable(
                                    onTap: () => setState(
                                      () => _categoryFilter = chip.key,
                                    ),
                                    shape: Radii.pillShape,
                                    child: AnimatedContainer(
                                      duration: motionDuration(
                                        const Duration(milliseconds: 200),
                                        disableAnimations:
                                            MediaQuery.maybeDisableAnimationsOf(
                                              context,
                                            ) ??
                                            false,
                                      ),
                                      curve: Curves2.out,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 8.5,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: _categoryFilter == chip.key
                                            ? colors.primaryContainer
                                            : colors.isDark
                                            ? colors.block
                                            : colors.inset,
                                        shape: Radii.pillShape,
                                      ),
                                      child: AnimatedDefaultTextStyle(
                                        duration: motionDuration(
                                          const Duration(milliseconds: 200),
                                          disableAnimations:
                                              MediaQuery.maybeDisableAnimationsOf(
                                                context,
                                              ) ??
                                              false,
                                        ),
                                        curve: Curves2.out,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: _categoryFilter == chip.key
                                              ? colors.onPrimaryContainer
                                              : colors.text2,
                                        ),
                                        child: Text(chip.label),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Gaps.md),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: ShapeDecoration(
                        // block 与浅色 page 同值；放在页面上的输入框必须用
                        // inset，否则会完全融进背景。
                        color: colors.isDark ? colors.block : colors.inset,
                        shape: Radii.shape(Radii.md),
                      ),
                      child: TextField(
                        controller: _search,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        autocorrect: false,
                        style: TextStyle(fontSize: 14, color: colors.text),
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          hintText: '搜索分类、备注、日期、金额',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: colors.text2,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: colors.text2,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 34,
                          ),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : Tooltip(
                                  message: '清除搜索',
                                  child: Pressable(
                                    onTap: () {
                                      _searchTimer?.cancel();
                                      _search.clear();
                                      _searchQuery = '';
                                      FocusScope.of(context).unfocus();
                                      setState(() {});
                                    },
                                    shape: Radii.pillShape,
                                    pressedScale: 0.90,
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: colors.text3,
                                      ),
                                    ),
                                  ),
                                ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Gaps.md),
                    if (monthEntries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gaps.xxl),
                        child: EmptyState(
                          title: keyword.isEmpty ? '这个月还没有账目' : '没有匹配的账目',
                          description: keyword.isEmpty
                              ? (_categoryFilter.isEmpty
                                    ? '点右上角 + 开始记录。'
                                    : '这个分类下还没有账目。')
                              : '换个关键词或分类试试。',
                        ),
                      )
                    else
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: Gaps.sm,
                          horizontal: Gaps.md,
                        ),
                        child: Column(
                          children: [
                            for (final entry in monthEntries)
                              _entryRow(entry, state.records),
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
        if (_undoEntry != null)
          Positioned(
            top: PinnedHeader.totalHeight(context) + 8,
            left: 0,
            right: 0,
            child: UndoBar(
              message:
                  '已删除 ${_undoEntry!.category} ${formatAmount(_undoEntry!.amount)}',
              onUndo: () {
                _undoTimer?.cancel();
                ref
                    .read(appControllerProvider.notifier)
                    .saveLedgerEntry(_undoEntry!);
                setState(() => _undoEntry = null);
              },
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PinnedHeader(
            title: '记账',
            actions: [
              BarActionButton(
                icon: Icons.add_rounded,
                tooltip: '记一笔',
                bright: true,
                onTap: () => showLedgerEditor(context),
              ),
              GlassMenuButton(
                items: [
                  LiquidMenuItem(
                    label: '分类管理',
                    icon: Icons.sell_outlined,
                    onSelected: () => showCategoryManager(context),
                  ),
                  LiquidMenuItem(
                    label: '回到本月',
                    icon: Icons.today_rounded,
                    onSelected: () => ref
                        .read(selectedMonthProvider.notifier)
                        .setMonth(currentMonthKey()),
                  ),
                  LiquidMenuItem(
                    label: '清除筛选',
                    icon: Icons.filter_alt_off_rounded,
                    onSelected: () => setState(() {
                      _searchTimer?.cancel();
                      _categoryFilter = '';
                      _search.clear();
                      _searchQuery = '';
                    }),
                  ),
                ],
              ),
              BarActionButton(
                icon: Icons.download_rounded,
                tooltip: '导出本月账本',
                bright: true,
                onTap: () => showExportSheet(
                  context,
                  month: month,
                  records: state.records,
                  entries: state.entries,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverBudgetBar extends StatelessWidget {
  const _OverBudgetBar({required this.expense, required this.budget});

  final double expense;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final over = expense - budget;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: colors.warningSoft,
        shape: Radii.shape(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本月支出已超预算 ${formatAmount(over)} 元（预算 ${formatAmount(budget)} 元）',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: colors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.month,
    required this.summary,
    required this.todayCount,
    required this.todayIncome,
    required this.todayExpense,
    required this.onChanged,
    required this.onPick,
  });

  final String month;
  final LedgerMonthSummary summary;
  final int todayCount;
  final double todayIncome;
  final double todayExpense;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pressable(
                onTap: onPick,
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
              const Spacer(),
              Semantics(
                button: true,
                label: '上个月',
                onTap: () => onChanged(shiftMonth(month, -1)),
                excludeSemantics: true,
                child: Pressable(
                  onTap: () => onChanged(shiftMonth(month, -1)),
                  shape: Radii.shape(12),
                  child: SizedBox(
                    width: 44,
                    height: 40,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 20,
                      color: colors.text3,
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: '下个月',
                onTap: () => onChanged(shiftMonth(month, 1)),
                excludeSemantics: true,
                child: Pressable(
                  onTap: () => onChanged(shiftMonth(month, 1)),
                  shape: Radii.shape(12),
                  child: SizedBox(
                    width: 44,
                    height: 40,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.text3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          Text(
            month == currentMonthKey() ? '本月结余' : '当月结余',
            style: TextStyle(
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w500,
              color: colors.text3,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatAmount(summary.balance),
              style: TextStyle(
                fontSize: TypeScale.display,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.03,
                color: summary.balance >= 0 ? colors.text : colors.expense,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: Gaps.md),
          // 收入 / 支出等宽双栏，中间一条 1px 细线做分隔：
          // 原来两个指标左对齐挤在一起，金额位数一变就对不齐。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _SideMetric(
                  label: '收入',
                  value: summary.income,
                  color: colors.income,
                ),
              ),
              Container(width: 1, height: 32, color: colors.cardBorder),
              const SizedBox(width: Gaps.lg),
              Expanded(
                child: _SideMetric(
                  label: '支出',
                  value: summary.expense,
                  color: colors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            // 历史月份里「今天 N 笔」是另一套时间语境（记工页修过同一问题）：
            // 标题写 2026年10月、副标题写今天，会让人以为本月账目丢了。
            month != currentMonthKey()
                ? '正在查看 ${formatMonthLabel(month)}'
                : todayCount == 0
                ? '今天还没有账目'
                : '今天 $todayCount 笔'
                      '${todayIncome > 0 ? ' · +${formatAmount(todayIncome)}' : ''}'
                      '${todayExpense > 0 ? ' · -${formatAmount(todayExpense)}' : ''}',
            style: TextStyle(fontSize: 12, color: colors.text2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.micro,
            fontWeight: FontWeight.w500,
            color: colors.text3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          formatAmount(value),
          style: TextStyle(
            fontSize: TypeScale.body,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02,
            color: color,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.linkedHours,
    required this.onTap,
    required this.onDelete,
    this.managed = false,
    this.deleteLabel = '删除',
  });

  final LedgerEntry entry;
  final double? linkedHours;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// 系统生成的工资账目（`wage-<date>`）：不可编辑，只能撤销对应结算。
  final bool managed;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isIncome = entry.type == LedgerType.income;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gaps.lg),
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
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: ShapeDecoration(
                    color: colors.block,
                    shape: Radii.shape(12),
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 18,
                    color: isIncome ? colors.income : colors.expense,
                  ),
                ),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.category,
                        style: TextStyle(
                          fontSize: TypeScale.title,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                      Text(
                        [
                          formatDateLabel(entry.date),
                          if (entry.remark.isNotEmpty) entry.remark,
                          if (linkedHours != null)
                            '${formatHoursValue(linkedHours!)}小时',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: colors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 115),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${isIncome ? '+' : '-'}${formatAmount(entry.amount)}',
                      style: TextStyle(
                        fontSize: TypeScale.title,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.02,
                        color: isIncome ? colors.income : colors.expense,
                        fontFeatures: tabularFigures,
                      ),
                    ),
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

// ---------------------------------------------------------------- 编辑器

Future<void> showLedgerEditor(
  BuildContext context, {
  LedgerEntry? entry,
  String? presetDate,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(archiveReadOnlyProvider)) {
    showArchiveReadOnlyMessage(context);
    return Future<void>.value();
  }
  return showAppSheet<void>(
    context: context,
    dismissible: false,
    builder: (_) => LedgerEditorSheet(entry: entry, presetDate: presetDate),
  );
}

class LedgerEditorSheet extends ConsumerStatefulWidget {
  const LedgerEditorSheet({super.key, this.entry, this.presetDate});

  final LedgerEntry? entry;
  final String? presetDate;

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

  // 初始快照 + 值比较。用 controller listener 置 dirty 会被「光标移动」误触发。
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
    _initialType = entry?.type ?? LedgerType.expense;
    _initialDate = entry?.date ?? widget.presetDate ?? todayISO();
    _initialCategory = entry?.category ?? defaultExpenseCategories.first;
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
      setState(() {
        _date = picked;
      });
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
                for (final category in categories)
                  Pressable(
                    onTap: () => setState(() {
                      _category = category;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: ShapeDecoration(
                        color: _category == category
                            ? colors.primaryContainer
                            : colors.block,
                        shape: Radii.pillShape,
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _category == category
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
