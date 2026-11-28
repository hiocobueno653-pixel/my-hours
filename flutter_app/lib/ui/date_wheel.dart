/// 自绘日期滚轮：年月日三列，替代 Material `showDatePicker`。
///
/// 为什么不用系统选择器：Material 的日期对话框是日历网格 + 完全不同的圆角/配色，
/// 在这个以「卡片 + 药丸 + 玻璃」为语言的应用里像另一个产品。滚轮也更适合单手。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/theme_tokens.dart';
import '../data/constants.dart';
import '../data/dates.dart';
import 'sheet.dart';
import 'widgets.dart';

/// 返回 `YYYY-MM-DD`；用户取消返回 null。
Future<String?> showDateWheel(
  BuildContext context, {
  required String initialDate,
  String? maxDate,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => _DateWheelSheet(initialDate: initialDate, maxDate: maxDate),
  );
}

class _DateWheelSheet extends StatefulWidget {
  const _DateWheelSheet({required this.initialDate, this.maxDate});

  final String initialDate;
  final String? maxDate;

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  static const _minYear = minSupportedYear;

  late final int _maxYear;
  late int _year;
  late int _month;
  late int _day;
  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    final maxParts = widget.maxDate?.split('-');
    _maxYear = maxParts != null && maxParts.length == 3
        ? (int.tryParse(maxParts[0]) ?? maxSupportedYear).clamp(
            _minYear,
            maxSupportedYear,
          )
        : maxSupportedYear;
    final parts = widget.initialDate.split('-').map(int.parse).toList();
    _year = parts[0].clamp(_minYear, _maxYear);
    _month = parts[1].clamp(1, 12);
    _day = parts[2].clamp(1, daysInMonth(_year, _month));
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _minYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _syncDay() {
    final maxDay = daysInMonth(_year, _month);
    if (_day <= maxDay) return;
    // 捕获目标值：postFrame 回调执行时 _day 可能已被下一次滚动改写
    final target = maxDay;
    _day = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dayCtrl.hasClients) return;
      _dayCtrl.jumpToItem(target - 1);
    });
  }

  String get _selectedDate =>
      '${_year.toString().padLeft(4, '0')}-'
      '${_month.toString().padLeft(2, '0')}-'
      '${_day.toString().padLeft(2, '0')}';

  void _confirm() {
    final maxDate = widget.maxDate;
    final value = maxDate != null && _selectedDate.compareTo(maxDate) > 0
        ? maxDate
        : _selectedDate;
    Navigator.of(context).pop(value);
  }

  void _jumpToday() {
    final today = todayISO();
    final parts = today.split('-').map(int.parse).toList();
    final nextYear = parts[0].clamp(_minYear, _maxYear);
    final nextMonth = parts[1].clamp(1, 12);
    final nextDay = parts[2].clamp(1, daysInMonth(nextYear, nextMonth));
    HapticFeedback.selectionClick();
    setState(() {
      _year = nextYear;
      _month = nextMonth;
      _day = nextDay;
    });
    _yearCtrl.jumpToItem(nextYear - _minYear);
    _monthCtrl.jumpToItem(nextMonth - 1);
    _dayCtrl.jumpToItem(nextDay - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxDay = daysInMonth(_year, _month);
    final today = todayISO();
    final canJumpToday =
        _selectedDate != today &&
        (widget.maxDate == null || today.compareTo(widget.maxDate!) <= 0);

    Widget column({
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int) label,
      required ValueChanged<int> onChanged,
    }) {
      return Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 40,
          diameterRatio: 1.6,
          squeeze: 1.05,
          looping: false,
          selectionOverlay: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: ShapeDecoration(
              color: colors.primaryContainer,
              shape: Radii.shape(Radii.sm),
            ),
          ),
          onSelectedItemChanged: (index) {
            HapticFeedback.selectionClick();
            onChanged(index);
          },
          children: [
            for (var i = 0; i < count; i++)
              Center(
                child: Text(
                  label(i),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SheetScaffold(
      title: '选择日期',
      maxHeightFactor: 0.72,
      actions: [
        if (canJumpToday) TextActionButton(label: '今天', onPressed: _jumpToday),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            child: Row(
              children: [
                column(
                  controller: _yearCtrl,
                  count: _maxYear - _minYear + 1,
                  label: (i) => '${_minYear + i} 年',
                  onChanged: (i) => setState(() {
                    _year = _minYear + i;
                    _syncDay();
                  }),
                ),
                column(
                  controller: _monthCtrl,
                  count: 12,
                  label: (i) => '${i + 1} 月',
                  onChanged: (i) => setState(() {
                    _month = i + 1;
                    _syncDay();
                  }),
                ),
                column(
                  controller: _dayCtrl,
                  count: maxDay,
                  label: (i) => '${i + 1} 日',
                  onChanged: (i) => setState(() => _day = i + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: '取消',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: Gaps.md),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: '确定',
                  expand: true,
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
