import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/motion.dart';
import '../core/theme_tokens.dart';
import '../data/constants.dart';
import '../data/dates.dart';
import 'sheet.dart';
import 'widgets.dart';

/// 月份选择弹层：年份切换 + 12 个月网格。
Future<String?> showMonthPicker(
  BuildContext context, {
  required String initialMonth,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => _MonthPickerSheet(initialMonth: initialMonth),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initialMonth});

  final String initialMonth;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  /// 年份可选范围。与 `date_wheel.dart` 的年份范围保持一致：
  /// 不设边界时连续点「下一年」会出现 5 位年份，`parseMonthKey` 失配后
  /// 日历直接空白、箭头静默回落到本月；3 位年份还会让 `month_view`
  /// 的 `substring(0, 4)` 抛 FormatException 打挂整页。
  static const int _minYear = minSupportedYear;
  static const int _maxYear = maxSupportedYear;

  late int _year;

  @override
  void initState() {
    super.initState();
    final parsed = parseMonthKey(widget.initialMonth);
    _year = (parsed?.year ?? DateTime.now().year)
        .clamp(_minYear, _maxYear)
        .toInt();
  }

  void _shiftYear(int delta) {
    setState(() => _year = (_year + delta).clamp(_minYear, _maxYear).toInt());
  }

  String _key(int month) =>
      '${_year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    final colorDuration = motionDuration(
      const Duration(milliseconds: 180),
      disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
    final years = [
      for (var year = now.year - 2; year <= now.year + 2; year++) year,
    ];

    return SheetScaffold(
      title: '选择月份',
      maxHeightFactor: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BarActionButton(
                icon: Icons.chevron_left_rounded,
                tooltip: '上一年',
                bright: true,
                onTap: () => _shiftYear(-1),
              ),
              Expanded(
                child: Text(
                  '$_year 年',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
              BarActionButton(
                icon: Icons.chevron_right_rounded,
                tooltip: '下一年',
                bright: true,
                onTap: () => _shiftYear(1),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              for (var month = 1; month <= 12; month++)
                Pressable(
                  onTap: () => Navigator.of(context).pop(_key(month)),
                  shape: Radii.shape(Radii.md),
                  child: AnimatedContainer(
                    duration: colorDuration,
                    curve: Curves2.out,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: _key(month) == widget.initialMonth
                          ? colors.primary
                          : colors.block,
                      shape: Radii.shape(Radii.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: colorDuration,
                          curve: Curves2.out,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _key(month) == widget.initialMonth
                                ? colors.onPrimary
                                : colors.text,
                          ),
                          child: Text('$month 月'),
                        ),
                        if (_year == now.year && month == now.month) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _key(month) == widget.initialMonth
                                  ? colors.onPrimary
                                  : colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gaps.lg),
          Text(
            '快速切换年份',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text2,
            ),
          ),
          const SizedBox(height: Gaps.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final year in years)
                Pressable(
                  onTap: () => setState(() => _year = year),
                  shape: Radii.pillShape,
                  child: AnimatedContainer(
                    duration: colorDuration,
                    curve: Curves2.out,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: ShapeDecoration(
                      color: year == _year
                          ? colors.primaryContainer
                          : colors.block,
                      shape: Radii.pillShape,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: colorDuration,
                      curve: Curves2.out,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: year == _year
                            ? colors.onPrimaryContainer
                            : colors.text2,
                        fontFeatures: tabularFigures,
                      ),
                      child: Text('$year'),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
        ],
      ),
    );
  }
}
