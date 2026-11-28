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
                if (!kHoursOnly)
                  _Metric(
                    label: '月工资',
                    value: formatAmount(pay, withSymbol: true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gaps.lg),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gaps.xxl),
              child: EmptyState(
                title: '这个月还没有记录',
                description: '回到${context.unit.quantity}页点今天开始记录。',
              ),
            )
          else
            Container(
              decoration: ShapeDecoration(
                color: colors.block.withValues(
                  alpha: colors.isDark ? 0.56 : 0.62,
                ),
                shape: Radii.shape(Radii.lg),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < records.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: colors.divider,
                      ),
                    Pressable(
                      onTap: () async {
                        final edit = await showDayDetail(context, records[i]);
                        if (edit == true && context.mounted) {
                          await showDayEditor(
                            context,
                            records[i].date,
                            record: records[i],
                          );
                        }
                      },
                      shape: Radii.shape(Radii.md),
                      pressedScale: 0.985,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 58,
                              child: Text(
                                formatDateLabel(records[i].date),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.text2,
                                  fontFeatures: tabularFigures,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 58,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${formatHoursValue(records[i].hours)}'
                                  '${context.unit.short}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: records[i].hours > 8
                                        ? colors.warning
                                        : colors.text,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                records[i].remark.isEmpty
                                    ? '—'
                                    : records[i].remark,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.text2,
                                ),
                              ),
                            ),
                            if (!kHoursOnly)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 108,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    formatAmount(
                                      recordPay(records[i], state.workProfiles),
                                      withSymbol: true,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: colors.income,
                                      fontFeatures: tabularFigures,
                                    ),
                                  ),
                                ),
                              ),
                            if (records[i].settled) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14.5,
                                color: colors.income,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
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
              letterSpacing: 0,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
