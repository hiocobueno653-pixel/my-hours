import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/models.dart';
import '../../data/stats.dart';
import '../../state/app_controller.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import '../charts/charts.dart';

/// 年度统计：全年工时/工资趋势、月度收支、分类占比。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  static const int _minYear = minSupportedYear;
  static const int _maxYear = maxSupportedYear;

  late int _year;
  LedgerType _categoryType = LedgerType.expense;

  @override
  void initState() {
    super.initState();
    // 用 parseMonthKey 而不是 split + int.parse：异常月份键会让后者抛异常。
    _year =
        parseMonthKey(ref.read(selectedMonthProvider))?.year ??
        DateTime.now().year;
  }

  void _shiftYear(int delta) {
    setState(() => _year = (_year + delta).clamp(_minYear, _maxYear).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final state = ref.watch(appControllerProvider);
    final hoursTrend = getYearHoursTrend(
      state.records,
      _year,
      state.workProfiles,
    );
    final ledgerTrend = getYearLedgerTrend(state.entries, _year);
    final summary = getYearSummary(
      state.records,
      state.entries,
      _year,
      state.workProfiles,
    );
    // 分类占比跟随年份：切到别的年份时用「同名月份 + 该年」，
    // 否则头部与趋势已切年，唯独占比还停在共享的 selectedMonth（另一个年份）。
    final selectedMonth = ref.watch(selectedMonthProvider);
    final categoryMonth =
        '$_year-${(parseMonthKey(selectedMonth)?.month ?? DateTime.now().month).toString().padLeft(2, '0')}';
    final allCategories = getMonthCategoryTotals(state.entries, categoryMonth);
    final categories = allCategories
        .where((row) => row.type == _categoryType)
        .toList();
    final categoryTotal = categories.fold<double>(
      0,
      (sum, row) => sum + row.total,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.only(
              top: PinnedSubHeader.totalHeight(context) + 8,
              bottom: 40,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _YearStepper(
                          icon: Icons.chevron_left_rounded,
                          label: '上一年',
                          onTap: () => _shiftYear(-1),
                        ),
                        Expanded(
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: motionDuration(
                                Timings.short,
                                disableAnimations: disable,
                              ),
                              switchInCurve: Curves2.out,
                              switchOutCurve: Curves2.inCurve,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.94,
                                      end: 1,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                '$_year 年',
                                key: ValueKey(_year),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: colors.text,
                                  fontFeatures: tabularFigures,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _YearStepper(
                          icon: Icons.chevron_right_rounded,
                          label: '下一年',
                          onTap: () => _shiftYear(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gaps.sm),
                    GlassCard(
                      child: Row(
                        children: [
                          _YearMetric(
                            label: '总工时',
                            value: formatHoursValue(summary.totalHours),
                            unit: 'h',
                            color: colors.accent,
                          ),
                          _YearMetric(
                            label: '总工资',
                            value: formatAmount(summary.totalPay),
                            unit: '元',
                            color: colors.income,
                          ),
                          _YearMetric(
                            label: '收支净额',
                            value: formatAmount(
                              summary.totalIncome - summary.totalExpense,
                            ),
                            unit: '元',
                            color: summary.totalIncome >= summary.totalExpense
                                ? colors.text
                                : colors.expense,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.md),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '全年工时趋势',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.text2,
                            ),
                          ),
                          const SizedBox(height: Gaps.sm),
                          TrendChart(
                            values: [
                              for (final point in hoursTrend) point.hours,
                            ],
                            labels: [
                              for (final point in hoursTrend)
                                '${int.parse(point.yearMonth.split('-')[1])}',
                            ],
                            color: colors.accent,
                            semanticLabel: '全年工时趋势',
                            seriesName: '工时',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.md),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '每月收支',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text2,
                                ),
                              ),
                              const Spacer(),
                              _Legend(color: colors.income, label: '收入'),
                              const SizedBox(width: Gaps.md),
                              _Legend(color: colors.expense, label: '支出'),
                            ],
                          ),
                          const SizedBox(height: Gaps.sm),
                          BarPairChart(
                            labels: [
                              for (final point in ledgerTrend)
                                '${int.parse(point.yearMonth.split('-')[1])}',
                            ],
                            seriesA: [for (final p in ledgerTrend) p.income],
                            seriesB: [for (final p in ledgerTrend) p.expense],
                            colorA: colors.income,
                            colorB: colors.expense,
                            valueFormatter: formatAmount,
                            semanticLabel: '每月收入与支出',
                            seriesAName: '收入',
                            seriesBName: '支出',
                            selectedIndex: ledgerTrend.indexWhere(
                              (point) => point.yearMonth == categoryMonth,
                            ),
                            onSelected: (index) {
                              if (index < 0 || index >= ledgerTrend.length) {
                                return;
                              }
                              ref
                                  .read(selectedMonthProvider.notifier)
                                  .setMonth(ledgerTrend[index].yearMonth);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.md),
                    SizedBox(
                      width: double.infinity,
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${formatMonthLabel(categoryMonth)} '
                                    '${_categoryType == LedgerType.expense ? '支出' : '收入'}分类',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text2,
                                    ),
                                  ),
                                ),
                                _CategoryTypeToggle(
                                  value: _categoryType,
                                  onChanged: (value) =>
                                      setState(() => _categoryType = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: Gaps.md),
                            if (categories.isEmpty)
                              Text(
                                '本月还没有${_categoryType == LedgerType.expense ? '支出' : '收入'}记录',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.text3,
                                ),
                              )
                            else ...[
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final donutSize = math.min(
                                    150.0,
                                    constraints.maxWidth * 0.42,
                                  );
                                  return Row(
                                    children: [
                                      DonutChart(
                                        size: donutSize,
                                        values: [
                                          for (final row in categories)
                                            row.total,
                                        ],
                                        colors: [
                                          for (
                                            var i = 0;
                                            i < categories.length;
                                            i++
                                          )
                                            colors.chart[i %
                                                colors.chart.length],
                                        ],
                                        labels: [
                                          for (final row in categories)
                                            row.name,
                                        ],
                                        semanticLabel:
                                            '${formatMonthLabel(categoryMonth)} '
                                            '${_categoryType == LedgerType.expense ? '支出' : '收入'}分类占比',
                                        centerValue: formatAmount(
                                          categoryTotal,
                                        ),
                                        centerLabel:
                                            _categoryType == LedgerType.expense
                                            ? '总支出'
                                            : '总收入',
                                      ),
                                      const SizedBox(width: Gaps.lg),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            for (
                                              var i = 0;
                                              i < categories.length;
                                              i++
                                            )
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 3,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colors.chart[i %
                                                                colors
                                                                    .chart
                                                                    .length],
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        categories[i].name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colors.text2,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      formatAmount(
                                                        categories[i].total,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colors.text3,
                                                        fontFeatures:
                                                            tabularFigures,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Gaps.xxl),
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
          child: PinnedSubHeader(title: '年度统计', onBack: widget.onBack),
        ),
      ],
    );
  }
}

class _CategoryTypeToggle extends StatelessWidget {
  const _CategoryTypeToggle({required this.value, required this.onChanged});

  final LedgerType value;
  final ValueChanged<LedgerType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget item(LedgerType type, String label) {
      final selected = value == type;
      return Pressable(
        onTap: () => onChanged(type),
        shape: Radii.pillShape,
        child: AnimatedContainer(
          duration: motionDuration(
            const Duration(milliseconds: 180),
            disableAnimations: disable,
          ),
          curve: Curves2.out,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: selected ? colors.primary : Colors.transparent,
            shape: Radii.pillShape,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.onPrimary : colors.text2,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: colors.inset, shape: Radii.pillShape),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(LedgerType.expense, '支出'),
          item(LedgerType.income, '收入'),
        ],
      ),
    );
  }
}

/// 年份步进按钮：圆形块面，与年份文字之间由 `Expanded` 自动留白。
///
/// 之前是贴着文字的 44×44 圆角方块，两个灰块夹住年份、没有呼吸空间，
/// 小屏上看起来像压在「年」字上。
class _YearStepper extends StatelessWidget {
  const _YearStepper({
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
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: const CircleBorder(),
        pressedScale: 0.90,
        child: Container(
          // 44dp 是移动端最小触控尺寸；40 会让单次点击的可达性下降。
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            // 用 inset 而不是 block：浅色主题下 block 与 page 同为 #EFEDF0，
            // 按钮会整个隐形，只剩图标浮在页底上。
            color: colors.inset,
            shape: const CircleBorder(),
          ),
          child: Icon(icon, size: 20, color: colors.text2),
        ),
      ),
    );
  }
}

class _YearMetric extends StatelessWidget {
  const _YearMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.text2)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02,
                    color: color,
                    fontFeatures: tabularFigures,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 1),
                  child: Text(
                    unit,
                    style: TextStyle(fontSize: TypeScale.micro, color: colors.text2),
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: colors.text2)),
      ],
    );
  }
}
