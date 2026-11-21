/// 图表：全部 `CustomPainter` 自绘，零第三方图表库。
///
/// 平滑折线的算法借自 `E:/蒸馏/prism_ui/lib/line_chart.dart` 的手法
/// （Catmull-Rom 斜率夹取 + 三次贝塞尔 + 面积填充），但这里带坐标轴与月份标签，
/// 因为年度趋势需要刻度，而那个实现只是流式 sparkline。
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';

List<double> _lerpSeries(List<double> from, List<double> to, double t) {
  final count = to.length;
  if (count == 0) return const [];
  return List<double>.generate(count, (index) {
    final start = index < from.length ? from[index] : 0.0;
    final end = to[index];
    return start + (end - start) * t;
  });
}

/// 双序列柱状图（收入/支出）。
class BarPairChart extends StatefulWidget {
  const BarPairChart({
    super.key,
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
    this.height = 160,
    this.valueFormatter,
    this.semanticLabel,
    this.seriesAName = '系列 A',
    this.seriesBName = '系列 B',
    this.selectedIndex,
    this.onSelected,
  });

  final List<String> labels;
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA;
  final Color colorB;
  final double height;
  final String Function(double)? valueFormatter;
  final String? semanticLabel;
  final String seriesAName;
  final String seriesBName;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  State<BarPairChart> createState() => _BarPairChartState();
}

class _BarPairChartState extends State<BarPairChart>
    with TickerProviderStateMixin {
  late final AnimationController _dataController = AnimationController(
    vsync: this,
    duration: Timings.slow,
  );
  late final AnimationController _selectController = AnimationController(
    vsync: this,
    duration: Timings.fast,
    value: 1,
  );
  late List<double> _fromA = List<double>.filled(widget.seriesA.length, 0);
  late List<double> _fromB = List<double>.filled(widget.seriesB.length, 0);
  double? _fromSelected;
  double? _toSelected;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _fromSelected = widget.selectedIndex?.toDouble();
    _toSelected = widget.selectedIndex?.toDouble();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      if (disable) {
        _fromA = List<double>.of(widget.seriesA);
        _fromB = List<double>.of(widget.seriesB);
        _dataController.value = 1;
      } else {
        _dataController.forward(from: 0);
      }
    } else if (disable) {
      _dataController.value = 1;
      _selectController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant BarPairChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!listEquals(oldWidget.seriesA, widget.seriesA) ||
        !listEquals(oldWidget.seriesB, widget.seriesB)) {
      final t = Curves2.out.transform(_dataController.value);
      _fromA = _lerpSeries(_fromA, oldWidget.seriesA, t);
      _fromB = _lerpSeries(_fromB, oldWidget.seriesB, t);
      if (disable) {
        _fromA = List<double>.of(widget.seriesA);
        _fromB = List<double>.of(widget.seriesB);
        _dataController.value = 1;
      } else {
        _dataController.forward(from: 0);
      }
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final next = widget.selectedIndex?.toDouble();
      if (disable || _toSelected == null || next == null) {
        _fromSelected = next;
        _toSelected = next;
        _selectController.value = 1;
      } else {
        final current = _currentSelectedSlot() ?? _toSelected!;
        _fromSelected = current;
        _toSelected = next;
        _selectController.forward(from: 0);
      }
    }
  }

  double? _currentSelectedSlot() {
    final target = _toSelected;
    if (target == null) return null;
    final start = _fromSelected ?? target;
    final t = Curves2.out.transform(_selectController.value);
    return start + (target - start) * t;
  }

  @override
  void dispose() {
    _dataController.dispose();
    _selectController.dispose();
    super.dispose();
  }

  String get _semanticText {
    final prefix = widget.semanticLabel ?? '柱状图';
    final formatter = widget.valueFormatter ?? (value) => _compactNumber(value);
    final parts = <String>[];
    for (var i = 0; i < widget.labels.length; i++) {
      final a = i < widget.seriesA.length ? formatter(widget.seriesA[i]) : '0';
      final b = i < widget.seriesB.length ? formatter(widget.seriesB[i]) : '0';
      parts.add(
        '${widget.labels[i]}：${widget.seriesAName} $a，${widget.seriesBName} $b',
      );
    }
    return parts.isEmpty ? '$prefix，暂无数据' : '$prefix。${parts.join('；')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      hint: widget.onSelected == null ? null : '轻点柱子切换月份',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fontFamily = DefaultTextStyle.of(context).style.fontFamily;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onSelected == null || widget.labels.isEmpty
                ? null
                : (details) {
                    final slot = constraints.maxWidth / widget.labels.length;
                    if (slot <= 0) return;
                    final index = (details.localPosition.dx / slot)
                        .floor()
                        .clamp(0, widget.labels.length - 1)
                        .toInt();
                    HapticFeedback.selectionClick();
                    widget.onSelected!(index);
                  },
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _dataController,
                  _selectController,
                ]),
                builder: (context, _) {
                  final t = Curves2.out.transform(_dataController.value);
                  final animatedA = _lerpSeries(_fromA, widget.seriesA, t);
                  final animatedB = _lerpSeries(_fromB, widget.seriesB, t);
                  final targetMax = [
                    ...widget.seriesA,
                    ...widget.seriesB,
                  ].fold<double>(0, (m, v) => math.max(m, v));
                  final animatedMax = [
                    ...animatedA,
                    ...animatedB,
                    targetMax,
                  ].fold<double>(0, (m, v) => math.max(m, v));
                  return CustomPaint(
                    isComplex: true,
                    willChange:
                        _dataController.isAnimating ||
                        _selectController.isAnimating,
                    painter: _BarPairPainter(
                      labels: widget.labels,
                      seriesA: animatedA,
                      seriesB: animatedB,
                      scaleMax: animatedMax,
                      labelMax: targetMax,
                      colorA: widget.colorA,
                      colorB: widget.colorB,
                      gridColor: colors.divider,
                      labelColor: colors.text3,
                      selectedIndex: widget.selectedIndex,
                      selectedSlot: _currentSelectedSlot(),
                      highlightColor: colors.primary.withValues(
                        alpha: colors.isDark ? 0.12 : 0.07,
                      ),
                      selectedLabelColor: colors.primary,
                      fontFamily: fontFamily,
                    ),
                    child: SizedBox(
                      height: widget.height,
                      width: double.infinity,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

String _compactNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

class _BarPairPainter extends CustomPainter {
  _BarPairPainter({
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.scaleMax,
    required this.labelMax,
    required this.colorA,
    required this.colorB,
    required this.gridColor,
    required this.labelColor,
    required this.selectedIndex,
    required this.selectedSlot,
    required this.highlightColor,
    required this.selectedLabelColor,
    this.fontFamily,
  });

  final List<String> labels;
  final List<double> seriesA;
  final List<double> seriesB;
  final double scaleMax;
  final double labelMax;
  final Color colorA;
  final Color colorB;
  final Color gridColor;
  final Color labelColor;
  final int? selectedIndex;
  final double? selectedSlot;
  final Color highlightColor;
  final Color selectedLabelColor;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    const bottomInset = 20.0;
    final chartHeight = size.height - bottomInset;
    final scale = scaleMax <= 0 ? 1.0 : chartHeight / (scaleMax * 1.15);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (labelMax > 0) {
      final maxTp = TextPainter(
        text: TextSpan(
          text: _compactNumber(labelMax),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor.withValues(alpha: 0.82),
            fontFamily: fontFamily,
            fontFeatures: tabularFigures,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      maxTp.paint(canvas, Offset(size.width - maxTp.width, 2));
    }

    final slot = size.width / labels.length;
    final barWidth = math.min(9.0, slot * 0.26);
    final radius = Radius.circular(barWidth / 2);

    if (selectedSlot != null &&
        selectedSlot! >= -0.5 &&
        selectedSlot! <= labels.length - 0.5) {
      final clampedSlot = selectedSlot!.clamp(0.0, (labels.length - 1).toDouble());
      final left = slot * clampedSlot + 2;
      final right = slot * (clampedSlot + 1) - 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 0, right, chartHeight),
          const Radius.circular(10),
        ),
        Paint()..color = highlightColor,
      );
    }

    final paintA = Paint()..color = colorA;
    final paintB = Paint()..color = colorB;
    for (var i = 0; i < labels.length; i++) {
      final cx = slot * i + slot / 2;
      final a = (i < seriesA.length ? seriesA[i] : 0.0) * scale;
      final b = (i < seriesB.length ? seriesB[i] : 0.0) * scale;
      if (a > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barWidth - 1.5, chartHeight - a, barWidth, a),
            radius,
          ),
          paintA,
        );
      }
      if (b > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 1.5, chartHeight - b, barWidth, b),
            radius,
          ),
          paintB,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: TypeScale.micro,
            color: i == selectedIndex ? selectedLabelColor : labelColor,
            fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w400,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(_BarPairPainter old) =>
      !listEquals(old.seriesA, seriesA) ||
      !listEquals(old.seriesB, seriesB) ||
      !listEquals(old.labels, labels) ||
      old.scaleMax != scaleMax ||
      old.labelMax != labelMax ||
      old.colorA != colorA ||
      old.colorB != colorB ||
      old.selectedIndex != selectedIndex ||
      old.selectedSlot != selectedSlot ||
      old.highlightColor != highlightColor ||
      old.selectedLabelColor != selectedLabelColor ||
      old.fontFamily != fontFamily;
}

/// 环形占比图。
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.labels,
    this.size = 150,
    this.centerLabel,
    this.centerValue,
    this.semanticLabel,
  });

  final List<double> values;
  final List<Color> colors;
  final List<String> labels;
  final double size;
  final String? centerLabel;
  final String? centerValue;
  final String? semanticLabel;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Timings.slow,
  );
  late List<double> _fromValues = List<double>.filled(widget.values.length, 0);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      if (disable) {
        _fromValues = List<double>.of(widget.values);
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (disable) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values)) {
      final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disable) {
        _fromValues = List<double>.of(widget.values);
        _controller.value = 1;
      } else {
        final t = Curves2.out.transform(_controller.value);
        _fromValues = _lerpSeries(_fromValues, oldWidget.values, t);
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _semanticText {
    final prefix = widget.semanticLabel ?? '环形占比图';
    final total = widget.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return '$prefix，暂无数据';
    final parts = <String>[];
    for (var i = 0; i < widget.labels.length; i++) {
      if (i >= widget.values.length || widget.values[i] <= 0) continue;
      final percent = (widget.values[i] / total * 100).round();
      parts.add('${widget.labels[i]} $percent%');
    }
    final center = widget.centerValue == null
        ? ''
        : '，中心 ${widget.centerLabel} ${widget.centerValue}';
    return '$prefix。${parts.join('，')}$center';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves2.out.transform(_controller.value);
              final animatedValues = _lerpSeries(_fromValues, widget.values, t);
              final fromTotal = _fromValues.fold<double>(0, (s, v) => s + v);
              final sweepProgress = fromTotal <= 0 ? t : 1.0;
              return CustomPaint(
                isComplex: true,
                willChange: _controller.isAnimating,
                painter: _DonutPainter(
                  values: animatedValues,
                  colors: widget.colors,
                  trackColor: tokens.inset,
                  sweepProgress: sweepProgress,
                ),
                child: child,
              );
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.centerValue != null)
                    AnimatedSwitcher(
                      duration: motionDuration(
                        Timings.fast,
                        disableAnimations: disable,
                      ),
                      switchInCurve: Curves2.out,
                      switchOutCurve: Curves2.out,
                      child: Text(
                        widget.centerValue!,
                        key: ValueKey(widget.centerValue),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.text,
                          letterSpacing: -0.02,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ),
                  if (widget.centerLabel != null)
                    Text(
                      widget.centerLabel!,
                      style: TextStyle(
                        fontSize: TypeScale.micro,
                        color: tokens.text3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
    this.sweepProgress = 1.0,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;
  final double sweepProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    final stroke = size.width * 0.14;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (total <= 0 || sweepProgress <= 0) return;

    var start = -math.pi / 2;
    final maxArc = math.pi * 2 * sweepProgress.clamp(0.0, 1.0);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < values.length; i++) {
      final sweep = maxArc * (values[i] / total);
      if (sweep <= 0) continue;
      arcPaint.color = colors[i % colors.length];
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - 0.02 * sweepProgress),
        false,
        arcPaint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      !listEquals(old.values, values) ||
      !listEquals(old.colors, colors) ||
      old.trackColor != trackColor ||
      old.sweepProgress != sweepProgress;
}

/// 进度条（预算/目标）。
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.ratio,
    required this.color,
    this.height = 8,
    this.trackColor,
  });

  final double ratio;
  final Color color;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clamped = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0);
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = BorderRadius.circular(height);
    return Semantics(
      container: true,
      label: '进度',
      value: '${(clamped * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: trackColor ?? colors.inset,
              child: AnimatedFractionallySizedBox(
                duration: motionDuration(
                  Timings.slow,
                  disableAnimations: disable,
                ),
                curve: Curves2.out,
                alignment: Alignment.centerLeft,
                widthFactor: clamped,
                child: AnimatedContainer(
                  duration: motionDuration(
                    Timings.fast,
                    disableAnimations: disable,
                  ),
                  curve: Curves2.soft,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 年度工时面积折线（带月份标签与基线）。
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.height = 150,
    this.semanticLabel,
    this.seriesName = '数值',
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final String? semanticLabel;
  final String seriesName;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Timings.slow,
  );
  late List<double> _fromValues = List<double>.filled(widget.values.length, 0);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      if (disable) {
        _fromValues = List<double>.of(widget.values);
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (disable) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values)) {
      final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disable) {
        _fromValues = List<double>.of(widget.values);
        _controller.value = 1;
      } else {
        final t = Curves2.out.transform(_controller.value);
        _fromValues = _lerpSeries(_fromValues, oldWidget.values, t);
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _semanticText {
    final prefix = widget.semanticLabel ?? '趋势图';
    if (widget.values.isEmpty) return '$prefix，暂无数据';
    final parts = <String>[];
    for (var i = 0; i < widget.values.length; i++) {
      final label = i < widget.labels.length ? widget.labels[i] : '${i + 1}';
      parts.add('$label ${_compactNumber(widget.values[i])}');
    }
    return '$prefix。${widget.seriesName}：${parts.join('，')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fontFamily = DefaultTextStyle.of(context).style.fontFamily;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      child: SizedBox(
        height: widget.height,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves2.out.transform(_controller.value);
              final animatedValues = _lerpSeries(_fromValues, widget.values, t);
              final targetMax = widget.values.fold<double>(
                0,
                (m, v) => math.max(m, v),
              );
              final scaleMax = animatedValues.fold<double>(
                targetMax,
                (m, v) => math.max(m, v),
              );
              return CustomPaint(
                isComplex: true,
                willChange: _controller.isAnimating,
                painter: _TrendPainter(
                  values: animatedValues,
                  scaleMax: scaleMax,
                  labelMax: targetMax,
                  peakOpacity: t,
                  labels: widget.labels,
                  color: widget.color,
                  gridColor: colors.divider,
                  labelColor: colors.text3,
                  fontFamily: fontFamily,
                ),
                child: child,
              );
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.scaleMax,
    required this.labelMax,
    required this.peakOpacity,
    required this.labels,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    this.fontFamily,
  });

  final List<double> values;
  final double scaleMax;
  final double labelMax;
  final double peakOpacity;
  final List<String> labels;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const bottomInset = 18.0;
    final chartHeight = size.height - bottomInset;
    final top = scaleMax <= 0 ? 1.0 : scaleMax * 1.12;
    final step = values.length <= 1
        ? size.width
        : size.width / (values.length - 1);

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(step * i, chartHeight - (values[i] / top) * chartHeight),
    ];

    // Catmull-Rom 斜率（夹取，避免过冲到负值）
    final slopes = <double>[
      for (var i = 0; i < points.length; i++)
        if (i == 0 || i == points.length - 1)
          0
        else
          ((points[i + 1].dy - points[i - 1].dy) / 2).clamp(
            -3 * (chartHeight - points[i].dy),
            3 * (chartHeight - points[i].dy),
          ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      path.cubicTo(
        p0.dx + step / 3,
        p0.dy + slopes[i - 1] / 3,
        p1.dx - step / 3,
        p1.dy - slopes[i] / 3,
        p1.dx,
        p1.dy,
      );
    }

    final area = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.72)
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 2; i++) {
      final y = chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.24),
          color.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));

    canvas
      ..save()
      ..clipRect(Offset.zero & Size(size.width, chartHeight))
      ..drawPath(area, areaPaint)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();

    if (labelMax > 0) {
      var peakIndex = 0;
      for (var i = 1; i < values.length; i++) {
        if (values[i] > values[peakIndex]) peakIndex = i;
      }
      final peak = points[peakIndex];
      final alpha = peakOpacity.clamp(0.0, 1.0);
      canvas.drawCircle(
        peak,
        7.5,
        Paint()..color = color.withValues(alpha: 0.18 * alpha),
      );
      canvas.drawCircle(
        peak,
        4.2,
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        peak,
        2.0,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      final peakTp = TextPainter(
        text: TextSpan(
          text: _compactNumber(labelMax),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: alpha),
            fontFamily: fontFamily,
            fontFeatures: tabularFigures,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final px = (peak.dx - peakTp.width / 2)
          .clamp(0.0, size.width - peakTp.width);
      final py = math.max(0.0, peak.dy - peakTp.height - 7);
      peakTp.paint(canvas, Offset(px, py));
    }

    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: TypeScale.micro,
            color: labelColor,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (step * i - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartHeight + 5));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      !listEquals(old.values, values) ||
      old.scaleMax != scaleMax ||
      old.labelMax != labelMax ||
      old.peakOpacity != peakOpacity ||
      !listEquals(old.labels, labels) ||
      old.color != color ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor ||
      old.fontFamily != fontFamily;
}
