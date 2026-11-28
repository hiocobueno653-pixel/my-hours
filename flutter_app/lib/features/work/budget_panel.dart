import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme_tokens.dart';
import '../../data/ledger.dart';
import '../../data/models.dart';
import '../../data/profiles.dart';
import '../../state/app_controller.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';

/// 预算与目标。
Future<void> showBudgetPanel(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const BudgetPanelSheet(),
  );
}

class BudgetPanelSheet extends ConsumerStatefulWidget {
  const BudgetPanelSheet({super.key});

  @override
  ConsumerState<BudgetPanelSheet> createState() => _BudgetPanelSheetState();
}

class _BudgetPanelSheetState extends ConsumerState<BudgetPanelSheet> {
  late final TextEditingController _budget;
  late final TextEditingController _goal;
  String? _error;

  @override
  void initState() {
    super.initState();
    final targets = ref.read(budgetTargetsProvider);
    _budget = TextEditingController(
      text: targets.monthlyExpenseBudget > 0
          ? formatAmountInput(targets.monthlyExpenseBudget)
          : '',
    );
    _goal = TextEditingController(
      text: targets.monthlyIncomeGoal > 0
          ? formatAmountInput(targets.monthlyIncomeGoal)
          : '',
    );
  }

  @override
  void dispose() {
    _budget.dispose();
    _goal.dispose();
    super.dispose();
  }

  void _save() {
    if (ref.read(archiveReadOnlyProvider)) {
      setState(() => _error = '存档当前为只读，请先导入备份恢复');
      return;
    }
    final budget = parseBudgetInput(_budget.text);
    final goal = parseBudgetInput(_goal.text);
    if (budget is! BudgetInputOk) {
      setState(() => _error = '支出预算：${(budget as BudgetInputError).message}');
      return;
    }
    if (goal is! BudgetInputOk) {
      setState(() => _error = '收入目标：${(goal as BudgetInputError).message}');
      return;
    }
    ref
        .read(appControllerProvider.notifier)
        .saveBudgetTargets(
          BudgetTargets(
            monthlyExpenseBudget: budget.amount,
            monthlyIncomeGoal: goal.amount,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final targets = ref.watch(budgetTargetsProvider);
    final entries = ref.watch(entriesProvider);
    final month = ref.watch(selectedMonthProvider);
    final summary = getLedgerMonthSummary(entries, month);
    final expenseRatio = targets.monthlyExpenseBudget <= 0
        ? 0.0
        : summary.expense / targets.monthlyExpenseBudget;
    final incomeRatio = targets.monthlyIncomeGoal <= 0
        ? 0.0
        : summary.income / targets.monthlyIncomeGoal;

    return SheetScaffold(
      title: '预算与目标',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressBlock(
            label: '本月支出',
            current: summary.expense,
            target: targets.monthlyExpenseBudget,
            ratio: expenseRatio,
            color: colors.expense,
            overText: '已超预算',
            underText: '剩余',
          ),
          const SizedBox(height: Gaps.lg),
          _ProgressBlock(
            label: '本月收入',
            current: summary.income,
            target: targets.monthlyIncomeGoal,
            ratio: incomeRatio,
            color: colors.income,
            overText: '已达成',
            underText: '还差',
            invert: true,
          ),
          const SizedBox(height: Gaps.xl),
          FormRow(
            label: '每月支出预算',
            hint: '留空 = 不设置',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NumberField(
                  controller: _budget,
                  hintText: '0',
                  suffixText: '元',
                  fontSize: 18,
                ),
                const SizedBox(height: Gaps.sm),
                QuickChips(
                  values: const [1500, 3000, 5000, 8000],
                  onSelect: (value) => _budget.text = formatAmountInput(value),
                ),
              ],
            ),
          ),
          FormRow(
            label: '每月收入目标',
            hint: '留空 = 不设置',
            child: NumberField(
              controller: _goal,
              hintText: '0',
              suffixText: '元',
              fontSize: 18,
            ),
          ),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: colors.expense),
            ),
            const SizedBox(height: Gaps.sm),
          ],
          PrimaryButton(label: '保存', expand: true, onPressed: _save),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.label,
    required this.current,
    required this.target,
    required this.ratio,
    required this.color,
    required this.overText,
    required this.underText,
    this.invert = false,
  });

  final String label;
  final double current;
  final double target;
  final double ratio;
  final Color color;
  final String overText;
  final String underText;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reached = invert ? ratio >= 1 : ratio > 1;
    final remaining = (target - current).abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: colors.text2)),
            const Spacer(),
            Text(
              target <= 0
                  ? '未设置'
                  : (reached
                        ? '$overText ${formatAmount(remaining, withSymbol: true)}'
                        : '$underText ${formatAmount(remaining, withSymbol: true)}'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: reached ? color : colors.text2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(ratio: ratio, color: color, height: 8),
        const SizedBox(height: 4),
        Text(
          '${formatAmount(current, withSymbol: true)} / ${target <= 0 ? '—' : formatAmount(target, withSymbol: true)}',
          style: TextStyle(
            fontSize: 12,
            color: colors.text2,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}
