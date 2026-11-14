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
import '../../data/stats.dart';
import '../../state/app_controller.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';
import '../../ui/dialog.dart';

/// 工资面板：应得 / 已结算 / 按工作分组 / 批量结算 + 工作管理入口。
Future<void> showWagePanel(BuildContext context, String month) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => WagePanelSheet(month: month),
  );
}

class WagePanelSheet extends ConsumerWidget {
  const WagePanelSheet({super.key, required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final summary = getSettlementSummary(
      state.records,
      month,
      state.workProfiles,
    );
    final breakdown = getMonthWorkBreakdown(
      state.records,
      state.workProfiles,
      month,
    );
    final ratio = summary.total <= 0 ? 0.0 : summary.settled / summary.total;

    return SheetScaffold(
      title: '${formatMonthLabel(month)} 工资',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatAmount(summary.total),
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.04,
                  color: colors.income,
                  fontFeatures: tabularFigures,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '元应得',
                  style: TextStyle(fontSize: 12.5, color: colors.text2),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          ProgressBar(ratio: ratio, color: colors.income),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '已结算 ${formatAmount(summary.settled)}',
                style: TextStyle(fontSize: 12.5, color: colors.text2),
              ),
              const Spacer(),
              Text(
                '待结算 ${formatAmount(summary.pending)}',
                style: TextStyle(fontSize: 12.5, color: colors.text2),
              ),
            ],
          ),
          const SizedBox(height: Gaps.xl),
          if (breakdown.isEmpty)
            const EmptyState(title: '本月还没有可结算的工资')
          else
            for (final row in breakdown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            '${formatHoursValue(row.hours)} 小时',
                            style: TextStyle(fontSize: 12, color: colors.text2),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatAmount(row.pay),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: Gaps.xl),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: '全部标记已结算',
                  expand: true,
                  onPressed: summary.pending <= 0
                      ? null
                      : () {
                          controller.settleMonth(month, true);
                          Navigator.of(context).pop();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: '撤销本月结算',
                  expand: true,
                  onPressed: summary.settled <= 0
                      ? null
                      : () async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: '撤销本月全部结算？',
                            description: '已生成的工资收入账目会被移除，账本结余会同步变化。',
                            confirmLabel: '撤销结算',
                          );
                          if (confirmed != true || !context.mounted) return;
                          controller.settleMonth(month, false);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: GhostButton(
                  label: '工作与时薪',
                  icon: Icons.work_outline_rounded,
                  expand: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    showWorkManager(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 工作管理：增删改，删除时关联记录归回默认工作（保留时薪快照）。
Future<void> showWorkManager(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    dismissible: false,
    builder: (_) => const WorkManagerSheet(),
  );
}

class WorkManagerSheet extends ConsumerStatefulWidget {
  const WorkManagerSheet({super.key});

  @override
  ConsumerState<WorkManagerSheet> createState() => _WorkManagerSheetState();
}

class _WorkManagerSheetState extends ConsumerState<WorkManagerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _rate;

  /// 正在内联编辑的工作 id；null 表示没有。
  String? _editingId;
  late final TextEditingController _editName;
  late final TextEditingController _editRate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _rate = TextEditingController();
    _editName = TextEditingController();
    _editRate = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _editName.dispose();
    _editRate.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final parsed = parseRateInput(_rate.text);
    if (parsed is! RateInputOk) {
      _toast((parsed as RateInputError).message);
      return;
    }
    final ok = ref
        .read(appControllerProvider.notifier)
        .saveWorkProfile(
          WorkProfile(
            id: createWorkProfileId(),
            name: name,
            hourlyRate: parsed.rate,
          ),
        );
    if (!ok) {
      _toast('已有同名工作');
      return;
    }
    _name.clear();
    _rate.clear();
  }

  /// 进入编辑态：默认工作也允许改名与改时薪（只是不允许删除）。
  void _startEdit(WorkProfile profile) {
    setState(() {
      _editingId = profile.id;
      _editName.text = profile.name;
      _editRate.text = profile.hourlyRate > 0
          ? formatRate(profile.hourlyRate)
          : '';
    });
  }

  void _cancelEdit() {
    setState(() => _editingId = null);
  }

  void _saveEdit(WorkProfile profile) {
    final name = _editName.text.trim();
    if (name.isEmpty) {
      _toast('工作名称不能为空');
      return;
    }
    final parsed = parseRateInput(_editRate.text);
    if (parsed is! RateInputOk) {
      _toast((parsed as RateInputError).message);
      return;
    }
    final ok = ref
        .read(appControllerProvider.notifier)
        .saveWorkProfile(profile.copyWith(name: name, hourlyRate: parsed.rate));
    if (!ok) {
      _toast('已有同名工作');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _editingId = null);
  }

  Future<void> _deleteProfile(WorkProfile profile) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除「${profile.name}」？',
      description: '关联记录会归回默认工作，历史时薪快照保留。',
      confirmLabel: '删除',
      danger: true,
    );
    if (confirmed == true && mounted) {
      ref.read(appControllerProvider.notifier).deleteWorkProfile(profile.id);
      setState(() => _editingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    return SheetScaffold(
      title: '工作与时薪',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每条记录会保存当时的时薪快照；之后改时薪不影响历史工资。'
            '点任意一行可改名称与时薪。',
            style: TextStyle(fontSize: 12.5, color: colors.text2, height: 1.6),
          ),
          const SizedBox(height: Gaps.lg),
          for (final profile in state.workProfiles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _editingId == profile.id
                  ? _editBlock(profile)
                  : _profileRow(profile),
            ),
          const SizedBox(height: Gaps.xl),
          Text(
            '新增工作',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text2,
            ),
          ),
          const SizedBox(height: Gaps.sm),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _name,
                  maxLength: maxWorkNameLength,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '名称',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '时薪',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              GhostButton(label: '添加', onPressed: _add),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileRow(WorkProfile profile) {
    final colors = context.colors;
    final isDefault = profile.id == defaultWorkId;
    return Pressable(
      onTap: () => _startEdit(profile),
      shape: Radii.shape(Radii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '编辑${profile.name}',
                onTap: () => _startEdit(profile),
                excludeSemantics: true,
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                  ),
                ),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  profile.hourlyRate > 0
                      ? '${formatAmount(profile.hourlyRate)} 元/时'
                      : '未设时薪',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: profile.hourlyRate > 0 ? colors.text2 : colors.text3,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18, color: colors.text3),
            if (isDefault)
              const SizedBox(width: 40)
            else
              Semantics(
                button: true,
                label: '删除${profile.name}',
                onTap: () => _deleteProfile(profile),
                excludeSemantics: true,
                child: Pressable(
                  onTap: () => _deleteProfile(profile),
                  pressedScale: 0.90,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.text3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editBlock(WorkProfile profile) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: ShapeDecoration(
        color: colors.block,
        shape: Radii.shape(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _editName,
                  autofocus: true,
                  maxLength: maxWorkNameLength,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '名称',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _editRate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '时薪',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveEdit(profile),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            profile.id == defaultWorkId
                ? '默认工作不可删除；改时薪只影响未结算记录'
                : '改时薪只影响未结算记录，已结算保留旧价',
            style: TextStyle(fontSize: 11.5, color: colors.text3, height: 1.4),
          ),
          const SizedBox(height: Gaps.sm),
          Row(
            children: [
              if (profile.id != defaultWorkId) ...[
                GhostButton(
                  label: '删除',
                  danger: true,
                  onPressed: () => _deleteProfile(profile),
                ),
                const SizedBox(width: Gaps.sm),
              ],
              const Spacer(),
              GhostButton(label: '取消', onPressed: _cancelEdit),
              const SizedBox(width: Gaps.sm),
              PrimaryButton(label: '保存', onPressed: () => _saveEdit(profile)),
            ],
          ),
        ],
      ),
    );
  }
}
