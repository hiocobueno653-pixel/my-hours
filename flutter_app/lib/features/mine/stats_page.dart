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
import '../../data/profiles.dart';
import '../../data/records.dart';
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

  List<WorkBreakdownRow> _yearWorkBreakdown(
    List<WorkDayRecord> records,
    List<WorkProfile> profiles,
    int year,
  ) {
    final prefix = '$year-';
    final map = <String, WorkBreakdownRow>{};
    for (final record in records) {
      if (!record.date.startsWith(prefix)) continue;
      final pay = recordPay(record, profiles);
      if (record.hours <= 0 && pay <= 0) continue;
      final id = record.workId ?? defaultWorkId;
      final name = workNameOf(record, profiles);
      final existing = map[id];
      map[id] = WorkBreakdownRow(
        workId: id,
        name: name,
        hours: roundMoney((existing?.hours ?? 0) + record.hours),
        pay: roundMoney((existing?.pay ?? 0) + pay),
      );
    }
    final list = map.values.toList()..sort((a, b) => b.hours.compareTo(a.hours));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
    final workBreakdown = _yearWorkBreakdown(
      state.records,
      state.workProfiles,
      _year,
    );
    final totalWorkDays = hoursTrend.fold<int>(
      0,
      (sum, point) => sum + point.workDays,
    );
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
                        child: Stack(
                          children: [
                            Positioned(
                              top: -48,
                              right: -28,
                              width: 190,
                              height: 190,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        colors.primary.withValues(alpha: 0.30),
                                        colors.primary.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                16,
                                18,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '全年${context.unit.quantity}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFFA8B5CE),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.baseline,
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              children: [
                                                Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: AnimatedNumericText(
                                                      value: summary.totalHours,
                                                      formatter: (v) =>
                                                          formatHoursValue(
                                                            v.toDouble(),
                                                          ),
                                                      style: const TextStyle(
                                                        fontSize: 44,
                                                        height: 0.98,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: -1.6,
                                                        color: Color(
                                                          0xFFF8FAFC,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  context.unit.short,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFFA8B5CE),
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
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF94A3B8),
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
                                  if (!kHoursOnly) ...[
                                    const SizedBox(height: 14),
                                    Divider(
                                      height: 1,
                                      thickness: 0.7,
                                      color: Colors.white.withValues(
                                        alpha: 0.11,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _YearMetric(
                                          label: '全年收入',
                                          numericValue: summary.totalIncome,
                                          formatter: (v) => formatAmount(
                                            v.toDouble(),
                                            withSymbol: true,
                                          ),
                                          unit: '',
                                          color: const Color(0xFF34D399),
                                          labelColor: const Color(0xFF94A3B8),
                                          compact: true,
                                        ),
                                        _YearMetric(
                                          label: '全年支出',
                                          numericValue: summary.totalExpense,
                                          formatter: (v) => formatAmount(
                                            v.toDouble(),
                                            withSymbol: true,
                                          ),
                                          unit: '',
                                          color: const Color(0xFFF87171),
                                          labelColor: const Color(0xFF94A3B8),
                                          compact: true,
                                        ),
                                        _YearMetric(
                                          label: '年度净结余',
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
                                              ? const Color(0xFFF8FAFC)
                                              : const Color(0xFFF87171),
                                          labelColor: const Color(0xFF94A3B8),
                                          compact: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
                            for (var i = 0; i < workBreakdown.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
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
                                                        color: colors
                                                            .chart[i %
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
                  actions: [
                    _YearSwitchPill(year: _year, onShift: _shiftYear),
                  ],
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
    final ratio =
        totalHours <= 0 ? 0.0 : (row.hours / totalHours).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            Text(
              '$percent% · ${formatHoursValue(row.hours)}$unitName'
              '${!kHoursOnly && row.pay > 0 ? ' · ${formatAmount(row.pay, withSymbol: true)}' : ''}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.text2,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ProgressBar(ratio: ratio, color: color, height: 4.5),
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
    Widget item(LedgerType type, String label) {
      final selected = value == type;
      return Pressable(
        onTap: () => onChanged(type),
        shape: Radii.pillShape,
        pressedScale: 0.95,
        child: AnimatedContainer(
          duration: motionDuration(
            Timings.fast,
            disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
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
      decoration: ShapeDecoration(
        color: colors.block,
        shape: Radii.pillShape,
      ),
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
    this.labelColor,
    this.compact = false,
  });

  final String label;
  final num numericValue;
  final String Function(num value) formatter;
  final String unit;
  final Color color;
  final Color? labelColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: labelColor ?? colors.text3,
            ),
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
    final barAccent = Color.lerp(colors.primary, Colors.white, 0.36)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$year · 12M',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: const Color(0xFF94A3B8),
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
                          ? Colors.white.withValues(alpha: 0.14)
                          : Color.lerp(
                              barAccent.withValues(alpha: 0.55),
                              barAccent,
                              ratio,
                            ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: value > 0 && ratio > 0.7
                          ? [
                              BoxShadow(
                                color: barAccent.withValues(alpha: 0.45),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
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
