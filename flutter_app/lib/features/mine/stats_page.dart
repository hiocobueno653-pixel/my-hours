import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
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

/// 统计页：可作为一级 Tab（onBack == null）或二级页面（onBack != null）。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key, this.onBack});

  final VoidCallback? onBack;

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
    final yearStats = ref.watch(yearStatsProvider(_year));
    final entries = ref.watch(entriesProvider);
    final hoursTrend = yearStats.hoursTrend;
    final ledgerTrend = yearStats.ledgerTrend;
    final summary = yearStats.summary;
    final workBreakdown = yearStats.workBreakdown;
    final totalWorkDays = yearStats.totalWorkDays;
    final selectedMonth = ref.watch(selectedMonthProvider);
    final categoryMonth =
        '$_year-${(parseMonthKey(selectedMonth)?.month ?? DateTime.now().month).toString().padLeft(2, '0')}';
    final allCategories = getMonthCategoryTotals(entries, categoryMonth);
    final categories = allCategories
        .where((row) => row.type == _categoryType)
        .toList();
    final categoryTotal = categories.fold<double>(
      0,
      (sum, row) => sum + row.total,
    );
    final isSubpage = widget.onBack != null;
    final headerHeight = isSubpage
        ? PinnedSubHeader.totalHeight(context)
        : PinnedHeader.totalHeight(context);

    final body = Stack(
      children: [
        Positioned.fill(
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              top: headerHeight + 12,
              bottom: isSubpage ? 28 : pageBottomInset(context),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isSubpage) ...[
                      Align(
                        alignment: Alignment.center,
                        child: _YearSwitchPill(
                          year: _year,
                          onShift: _shiftYear,
                        ),
                      ),
                      const SizedBox(height: Gaps.md),
                    ],
                    Container(
                      decoration: studioHeroDecoration(
                        colors,
                        radius: Radii.hero,
                      ),
                      child: ClipPath(
                        clipper: ShapeBorderClipper(
                          shape: Radii.shape(Radii.hero),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                16,
                                18,
                                14,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '全年${context.unit.quantity}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: colors.text2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: AnimatedNumericText(
                                                  value: summary.totalHours,
                                                  formatter: (v) =>
                                                      formatHoursValue(
                                                        v.toDouble(),
                                                      ),
                                                  style: TextStyle(
                                                    fontSize: 42,
                                                    height: 0.98,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: -1.5,
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              context.unit.short,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                                color: colors.text3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '出勤 $totalWorkDays 天'
                                          '${!kHoursOnly && summary.totalPay > 0 ? ' · 工资 ${formatAmount(summary.totalPay, withSymbol: true)}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: colors.text2,
                                            fontFeatures: tabularFigures,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _YearActivityMatrix(
                                    values: [
                                      for (final point in hoursTrend)
                                        point.hours,
                                    ],
                                    year: _year,
                                  ),
                                ],
                              ),
                            ),
                            if (!kHoursOnly) ...[
                              Divider(
                                height: 1,
                                thickness: 0.7,
                                color: colors.divider,
                              ),
                              ColoredBox(
                                color: colors.heroWell,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    12,
                                    18,
                                    13,
                                  ),
                                  child: Row(
                                    children: [
                                      _YearMetric(
                                        label: '全年收入',
                                        dotColor: colors.income,
                                        numericValue: summary.totalIncome,
                                        formatter: (v) => formatAmount(
                                          v.toDouble(),
                                          withSymbol: true,
                                        ),
                                        unit: '',
                                        color: colors.text,
                                        labelColor: colors.text3,
                                        compact: true,
                                      ),
                                      _YearMetric(
                                        label: '全年支出',
                                        dotColor: colors.expense,
                                        numericValue: summary.totalExpense,
                                        formatter: (v) => formatAmount(
                                          v.toDouble(),
                                          withSymbol: true,
                                        ),
                                        unit: '',
                                        color: colors.text,
                                        labelColor: colors.text3,
                                        compact: true,
                                      ),
                                      _YearMetric(
                                        label: '年度净结余',
                                        dotColor: colors.primary,
                                        numericValue:
                                            summary.totalIncome -
                                            summary.totalExpense,
                                        formatter: (v) => formatAmount(
                                          v.toDouble(),
                                          withSymbol: true,
                                        ),
                                        unit: '',
                                        color:
                                            summary.totalIncome >=
                                                summary.totalExpense
                                            ? colors.text
                                            : colors.expense,
                                        labelColor: colors.text3,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Gaps.cardGap),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.show_chart_rounded,
                                color: colors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '每月${context.unit.quantity}趋势',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Gaps.md),
                          TrendChart(
                            values: [
                              for (final point in hoursTrend) point.hours,
                            ],
                            labels: [
                              for (final point in hoursTrend)
                                '${int.parse(point.yearMonth.split('-')[1])}',
                            ],
                            color: colors.primary,
                            semanticLabel: '全年${context.unit.quantity}趋势',
                            seriesName: context.unit.quantity,
                          ),
                        ],
                      ),
                    ),
                    if (workBreakdown.isNotEmpty) ...[
                      const SizedBox(height: Gaps.cardGap),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.pie_chart_outline_rounded,
                                  color: colors.chart[1],
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '按工作构成（$_year 年）',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Gaps.md),
                            _StackedShareBar(
                              values: [
                                for (final row in workBreakdown) row.hours,
                              ],
                              colors: [
                                for (var i = 0; i < workBreakdown.length; i++)
                                  colors.chart[i % colors.chart.length],
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < workBreakdown.length; i++) ...[
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    thickness: 0.6,
                                    color: colors.divider,
                                  ),
                                ),
                              _WorkBreakdownBar(
                                row: workBreakdown[i],
                                totalHours: summary.totalHours,
                                unitName: context.unit.short,
                                color: colors.chart[i % colors.chart.length],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (!kHoursOnly) ...[
                      const SizedBox(height: Gaps.cardGap),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bar_chart_rounded,
                                  color: colors.income,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '每月收支对比',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                                const Spacer(),
                                _Legend(color: colors.income, label: '收入'),
                                const SizedBox(width: Gaps.md),
                                _Legend(color: colors.expense, label: '支出'),
                              ],
                            ),
                            const SizedBox(height: Gaps.md),
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
                      const SizedBox(height: Gaps.cardGap),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.donut_large_rounded,
                                  color: _categoryType == LedgerType.expense
                                      ? colors.expense
                                      : colors.income,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${formatMonthLabel(categoryMonth)} '
                                    '${_categoryType == LedgerType.expense ? '支出' : '收入'}分类',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
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
                                '该月还没有${_categoryType == LedgerType.expense ? '支出' : '收入'}记录',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.text3,
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final donutSize = math.min(
                                    138.0,
                                    constraints.maxWidth * 0.40,
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
                                          withSymbol: true,
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
                                                      vertical: 3.5,
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
                                                          fontSize: 12.5,
                                                          color: colors.text,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      formatAmount(
                                                        categories[i].total,
                                                        withSymbol: true,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: colors.text,
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
                        ),
                      ),
                    ],
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
          child: isSubpage
              ? PinnedSubHeader(title: '年度统计', onBack: widget.onBack!)
              : PinnedHeader(
                  title: '统计',
                  actions: [_YearSwitchPill(year: _year, onShift: _shiftYear)],
                ),
        ),
      ],
    );
    if (isSubpage) {
      return Scaffold(backgroundColor: colors.page, body: body);
    }
    return body;
  }
}

class _WorkBreakdownBar extends StatelessWidget {
  const _WorkBreakdownBar({
    required this.row,
    required this.totalHours,
    required this.unitName,
    required this.color,
  });

  final WorkBreakdownRow row;
  final double totalHours;
  final String unitName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ratio = totalHours <= 0
        ? 0.0
        : (row.hours / totalHours).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
          decoration: ShapeDecoration(
            color: colors.block,
            shape: Radii.shape(6),
          ),
          child: Text(
            '$percent%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.text2,
              fontFeatures: tabularFigures,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatHoursValue(row.hours)}$unitName'
          '${!kHoursOnly && row.pay > 0 ? ' · ${formatAmount(row.pay, withSymbol: true)}' : ''}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.text,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// 整段工作构成比例条：直观呈现年度各工作的工时占比。
class _StackedShareBar extends StatelessWidget {
  const _StackedShareBar({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return Container(
        height: 7,
        decoration: BoxDecoration(
          color: context.colors.block,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    return SizedBox(
      height: 7,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            if (values[i] > 0)
              Expanded(
                flex: math.max(1, (values[i] / total * 1000).round()),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ],
      ),
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
    Widget item(LedgerType type, String label) {
      final selected = value == type;
      return Pressable(
        onTap: () => onChanged(type),
        shape: Radii.pillShape,
        pressedScale: 0.95,
        child: AnimatedContainer(
          duration: motionDuration(
            Timings.fast,
            disableAnimations:
                MediaQuery.maybeDisableAnimationsOf(context) ?? false,
          ),
          curve: Curves2.out,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: ShapeDecoration(
            color: selected ? colors.primary : Colors.transparent,
            shape: Radii.pillShape,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.onPrimary : colors.text2,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: colors.block, shape: Radii.pillShape),
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

class _YearSwitchPill extends StatelessWidget {
  const _YearSwitchPill({required this.year, required this.onShift});

  final int year;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget step(IconData icon, String label, int delta) {
      return Semantics(
        button: true,
        label: label,
        onTap: () => onShift(delta),
        excludeSemantics: true,
        child: Pressable(
          onTap: () => onShift(delta),
          shape: Radii.pillShape,
          pressedScale: 0.92,
          child: SizedBox(
            width: 32,
            height: 40,
            child: Icon(icon, size: 18, color: colors.text2),
          ),
        ),
      );
    }

    return HeaderGlassSurface(
      height: 40,
      radius: Radii.pill,
      bright: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(Icons.chevron_left_rounded, '上一年', -1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedSwitcher(
              duration: motionDuration(
                Timings.fast,
                disableAnimations: disable,
              ),
              switchInCurve: Curves2.out,
              switchOutCurve: Curves2.out,
              child: Text(
                '$year 年',
                key: ValueKey(year),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ),
          step(Icons.chevron_right_rounded, '下一年', 1),
        ],
      ),
    );
  }
}

class _YearMetric extends StatelessWidget {
  const _YearMetric({
    required this.label,
    required this.numericValue,
    required this.formatter,
    required this.unit,
    required this.color,
    this.dotColor,
    this.labelColor,
    this.compact = false,
  });

  final String label;
  final num numericValue;
  final String Function(num value) formatter;
  final String unit;
  final Color color;
  final Color? dotColor;
  final Color? labelColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: labelColor ?? colors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedNumericText(
                    value: numericValue,
                    formatter: formatter,
                    style: TextStyle(
                      fontSize: compact ? 16 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 11, color: colors.text3)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 12 个月垂直微光律动条：像精密音频电平一样呈现全年投入节律，单月数据同样利落。
class _YearActivityMatrix extends StatelessWidget {
  const _YearActivityMatrix({required this.values, required this.year});

  final List<double> values;
  final int year;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var maxVal = 0.0;
    for (final v in values) {
      if (v > maxVal) maxVal = v;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$year · 12M',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: colors.text3,
            fontFeatures: tabularFigures,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 12; i++) ...[
                if (i > 0) const SizedBox(width: 3.5),
                () {
                  final value = i < values.length ? values[i] : 0.0;
                  final ratio = maxVal > 0
                      ? (value / maxVal).clamp(0.0, 1.0)
                      : 0.0;
                  final h = value <= 0 ? 7.0 : (10.0 + ratio * 26.0);
                  return Container(
                    width: 5.5,
                    height: h,
                    decoration: BoxDecoration(
                      color: value <= 0
                          ? colors.block
                          : Color.lerp(
                              colors.primary.withValues(alpha: 0.38),
                              colors.primary,
                              ratio,
                            ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }(),
              ],
            ],
          ),
        ),
      ],
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: colors.text2)),
      ],
    );
  }
}
