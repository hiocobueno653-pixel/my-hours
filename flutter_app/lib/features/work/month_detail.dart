import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme_tokens.dart';
import '../../data/dates.dart';
import '../../data/records.dart';
import '../../state/app_controller.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';
import 'month_view.dart';
import '../../core/measure_unit.dart';

/// 月明细：当月每天一行，底部月总计。
Future<void> showMonthDetail(BuildContext context, String month) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => MonthDetailSheet(month: month),
  );
}

class MonthDetailSheet extends ConsumerWidget {
  const MonthDetailSheet({super.key, required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final records =
        getMonthRecords(state.records, month)
            .where(
              (record) =>
                  record.hours > 0 ||
                  record.remark.isNotEmpty ||
                  hasFixedPay(record),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final summary = getMonthSummary(state.records, month);
    final pay = getMonthPay(state.records, month, state.workProfiles);

    return SheetScaffold(
      title: '${formatMonthLabel(month)} 明细',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Gaps.lg),
            decoration: ShapeDecoration(
              color: colors.block,
              shape: Radii.shape(Radii.md),
            ),
            child: Row(
              children: [
                _Metric(
                  label: '总${context.unit.quantity}',
                  value: formatHoursValue(summary.totalHours),
                ),
                _Metric(label: '工作天数', value: '${summary.workDays}'),
                _Metric(label: '月工资', value: formatAmount(pay)),
              ],
            ),
          ),
          const SizedBox(height: Gaps.lg),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Gaps.xxl),
              child: EmptyState(title: '这个月还没有记录', description: '回到记工页点今天开始记。'),
            )
          else
            for (final record in records)
              Pressable(
                onTap: () async {
                  final edit = await showDayDetail(context, record);
                  if (edit == true && context.mounted) {
                    await showDayEditor(context, record.date, record: record);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: Text(
                          formatDateLabel(record.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.text2,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 54,
                        child: Text(
                          '${formatHoursValue(record.hours)}h',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          record.remark.isEmpty ? '—' : record.remark,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: colors.text2),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatAmount(recordPay(record, state.workProfiles)),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: colors.income,
                              fontFeatures: tabularFigures,
                            ),
                          ),
                        ),
                      ),
                      if (record.settled) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colors.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.text,
              letterSpacing: -0.02,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
