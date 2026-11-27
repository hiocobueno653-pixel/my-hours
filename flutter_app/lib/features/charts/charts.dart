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

void _disposeTextPainters(List<TextPainter> painters) {
  for (final painter in painters) {
    painter.dispose();
  }
}

TextPainter _layoutTextPainter(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
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
  late final Listenable _repaint = Listenable.merge([
    _dataController,
    _selectController,
  ]);
  late List<double> _fromA = List<double>.filled(widget.seriesA.length, 0);
  late List<double> _fromB = List<double>.filled(widget.seriesB.length, 0);
  double? _fromSelected;
  double? _toSelected;
  bool _started = false;
  int? _xCacheKey;
  List<TextPainter> _xLabelPainters = const [];
  int? _yCacheKey;
  List<TextPainter> _yLabelPainters = const [];

  void _syncLabelCaches({
    required double targetMax,
    required Color labelColor,
    required Color selectedLabelColor,
    required String? fontFamily,
  }) {
    final xKey = Object.hash(
      Object.hashAll(widget.labels),
      widget.selectedIndex,
      labelColor.toARGB32(),
      selectedLabelColor.toARGB32(),
      fontFamily,
    );
    if (_xCacheKey != xKey) {
      _disposeTextPainters(_xLabelPainters);
      _xCacheKey = xKey;
      _xLabelPainters = [
        for (var i = 0; i < widget.labels.length; i++)
          _layoutTextPainter(
            widget.labels[i],
            TextStyle(
              fontSize: TypeScale.micro,
              color: i == widget.selectedIndex
                  ? selectedLabelColor
                  : labelColor,
              fontWeight: i == widget.selectedIndex
                  ? FontWeight.w600
                  : FontWeight.w400,
              fontFamily: fontFamily,
            ),
          ),
      ];
    }

    final yKey = Object.hash(targetMax, labelColor.toARGB32(), fontFamily);
    if (_yCacheKey != yKey) {
      _disposeTextPainters(_yLabelPainters);
      _yCacheKey = yKey;
      if (targetMax <= 0) {
        _yLabelPainters = const [];
      } else {
        final yStyle = TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: labelColor.withValues(alpha: 0.82),
          fontFamily: fontFamily,
          fontFeatures: tabularFigures,
        );
        _yLabelPainters = [
          _layoutTextPainter(_compactNumber(targetMax.roundToDouble()), yStyle),
          _layoutTextPainter(
            _compactNumber((targetMax * 2 / 3).roundToDouble()),
            yStyle,
          ),
          _layoutTextPainter(
            _compactNumber((targetMax / 3).roundToDouble()),
            yStyle,
          ),
        ];
      }
    }
  }

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
    _disposeTextPainters(_xLabelPainters);
    _disposeTextPainters(_yLabelPainters);
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
    var targetMax = 0.0;
    for (final v in widget.seriesA) {
      if (v > targetMax) targetMax = v;
    }
    for (final v in widget.seriesB) {
      if (v > targetMax) targetMax = v;
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      hint: widget.onSelected == null ? null : '轻点柱子切换月份',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fontFamily = DefaultTextStyle.of(context).style.fontFamily;
          _syncLabelCaches(
            targetMax: targetMax,
            labelColor: colors.text3,
            selectedLabelColor: colors.primary,
            fontFamily: fontFamily,
          );
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
              child: CustomPaint(
                isComplex: true,
                willChange:
                    _dataController.isAnimating ||
                    _selectController.isAnimating,
                painter: _BarPairPainter(
                  repaint: _repaint,
                  dataAnimation: _dataController,
                  selectAnimation: _selectController,
                  labels: widget.labels,
                  fromA: _fromA,
                  toA: widget.seriesA,
                  fromB: _fromB,
                  toB: widget.seriesB,
                  targetMax: targetMax,
                  colorA: widget.colorA,
                  colorB: widget.colorB,
                  gridColor: colors.divider,
                  selectedIndex: widget.selectedIndex,
                  fromSelected: _fromSelected,
                  toSelected: _toSelected,
                  highlightColor: colors.primary.withValues(
                    alpha: colors.isDark ? 0.12 : 0.07,
                  ),
                  xLabelPainters: _xLabelPainters,
                  yLabelPainters: _yLabelPainters,
                  xCacheKey: _xCacheKey ?? 0,
                  yCacheKey: _yCacheKey ?? 0,
                ),
                child: SizedBox(height: widget.height, width: double.infinity),
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
    required Listenable repaint,
    required this.dataAnimation,
    required this.selectAnimation,
    required this.labels,
    required this.fromA,
    required this.toA,
    required this.fromB,
    required this.toB,
    required this.targetMax,
    required this.colorA,
    required this.colorB,
    required this.gridColor,
    required this.selectedIndex,
    required this.fromSelected,
    required this.toSelected,
    required this.highlightColor,
    required this.xLabelPainters,
    required this.yLabelPainters,
    required this.xCacheKey,
    required this.yCacheKey,
  }) : super(repaint: repaint);

  final Animation<double> dataAnimation;
  final Animation<double> selectAnimation;
  final List<String> labels;
  final List<double> fromA;
  final List<double> toA;
  final List<double> fromB;
  final List<double> toB;
  final double targetMax;
  final Color colorA;
  final Color colorB;
  final Color gridColor;
  final int? selectedIndex;
  final double? fromSelected;
  final double? toSelected;
  final Color highlightColor;
  final List<TextPainter> xLabelPainters;
  final List<TextPainter> yLabelPainters;
  final int xCacheKey;
  final int yCacheKey;

  double _valueAt(List<double> from, List<double> to, int index, double t) {
    if (index >= to.length) return 0.0;
    final start = index < from.length ? from[index] : 0.0;
    return start + (to[index] - start) * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    const bottomInset = 20.0;
    final chartHeight = size.height - bottomInset;
    final t = Curves2.out.transform(dataAnimation.value);
    var scaleMax = targetMax;
    final countA = toA.length;
    for (var i = 0; i < countA; i++) {
      final v = _valueAt(fromA, toA, i, t);
      if (v > scaleMax) scaleMax = v;
    }
    final countB = toB.length;
    for (var i = 0; i < countB; i++) {
      final v = _valueAt(fromB, toB, i, t);
      if (v > scaleMax) scaleMax = v;
    }
    final scale = scaleMax <= 0 ? 1.0 : chartHeight / (scaleMax * 1.15);

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final dashPath = Path();
    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      if (i == 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      } else {
        _addDashedLine(dashPath, Offset(0, y), Offset(size.width, y));
      }
    }
    canvas.drawPath(dashPath, gridPaint);

    if (yLabelPainters.length == 3) {
      yLabelPainters[0].paint(canvas, const Offset(0, 2));
      yLabelPainters[1].paint(canvas, Offset(0, chartHeight / 3 + 2));
      yLabelPainters[2].paint(canvas, Offset(0, chartHeight * 2 / 3 + 2));
    }

    final slot = size.width / labels.length;
    final barWidth = math.min(9.0, slot * 0.28);
    final radius = Radius.circular(barWidth / 2);
    final notchPaint = Paint()..color = gridColor.withValues(alpha: 0.72);

    final double? selectedSlot;
    if (toSelected == null) {
      selectedSlot = null;
    } else {
      final start = fromSelected ?? toSelected!;
      final st = Curves2.out.transform(selectAnimation.value);
      selectedSlot = start + (toSelected! - start) * st;
    }

    if (selectedSlot != null &&
        selectedSlot >= -0.5 &&
        selectedSlot <= labels.length - 0.5) {
      final clampedSlot = selectedSlot.clamp(
        0.0,
        (labels.length - 1).toDouble(),
      );
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

    final gradientA = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.lerp(colorA, Colors.white, 0.14)!, colorA],
    );
    final gradientB = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.lerp(colorB, Colors.white, 0.14)!, colorB],
    );
    final barPaint = Paint();

    for (var i = 0; i < labels.length; i++) {
      final cx = slot * i + slot / 2;
      final a = _valueAt(fromA, toA, i, t) * scale;
      final b = _valueAt(fromB, toB, i, t) * scale;
      if (a <= 0 && b <= 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cx - barWidth * 0.65,
              chartHeight - 3,
              barWidth * 1.3,
              3,
            ),
            const Radius.circular(999),
          ),
          notchPaint,
        );
      }
      if (a > 0) {
        final rectA = Rect.fromLTWH(
          cx - barWidth - 1.5,
          chartHeight - a,
          barWidth,
          a,
        );
        barPaint.shader = gradientA.createShader(rectA);
        canvas.drawRRect(RRect.fromRectAndRadius(rectA, radius), barPaint);
      }
      if (b > 0) {
        final rectB = Rect.fromLTWH(cx + 1.5, chartHeight - b, barWidth, b);
        barPaint.shader = gradientB.createShader(rectB);
        canvas.drawRRect(RRect.fromRectAndRadius(rectB, radius), barPaint);
      }
      if (i < xLabelPainters.length) {
        final tp = xLabelPainters[i];
        tp.paint(canvas, Offset(cx - tp.width / 2, chartHeight + 6));
      }
    }
  }

  @override
  bool shouldRepaint(_BarPairPainter old) =>
      !listEquals(old.fromA, fromA) ||
      !listEquals(old.toA, toA) ||
      !listEquals(old.fromB, fromB) ||
      !listEquals(old.toB, toB) ||
      !listEquals(old.labels, labels) ||
      old.targetMax != targetMax ||
      old.colorA != colorA ||
      old.colorB != colorB ||
      old.gridColor != gridColor ||
      old.selectedIndex != selectedIndex ||
      old.fromSelected != fromSelected ||
      old.toSelected != toSelected ||
      old.highlightColor != highlightColor ||
      old.xCacheKey != xCacheKey ||
      old.yCacheKey != yCacheKey;
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
    final fromTotal = _fromValues.fold<double>(0, (s, v) => s + v);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: _controller.isAnimating,
            painter: _DonutPainter(
              animation: _controller,
              fromValues: _fromValues,
              toValues: widget.values,
              fromTotal: fromTotal,
              colors: widget.colors,
              trackColor: tokens.inset,
            ),
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
    required this.animation,
    required this.fromValues,
    required this.toValues,
    required this.fromTotal,
    required this.colors,
    required this.trackColor,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<double> fromValues;
  final List<double> toValues;
  final double fromTotal;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves2.out.transform(animation.value);
    final sweepProgress = fromTotal <= 0 ? t : 1.0;
    final count = toValues.length;
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      final start = i < fromValues.length ? fromValues[i] : 0.0;
      total += start + (toValues[i] - start) * t;
    }
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
    for (var i = 0; i < count; i++) {
      final fromVal = i < fromValues.length ? fromValues[i] : 0.0;
      final value = fromVal + (toValues[i] - fromVal) * t;
      final sweep = maxArc * (value / total);
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
      !listEquals(old.fromValues, fromValues) ||
      !listEquals(old.toValues, toValues) ||
      old.fromTotal != fromTotal ||
      !listEquals(old.colors, colors) ||
      old.trackColor != trackColor;
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
                  decoration: BoxDecoration(color: color, borderRadius: radius),
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
  int? _xCacheKey;
  List<TextPainter> _xLabelPainters = const [];
  int? _yCacheKey;
  List<TextPainter> _yLabelPainters = const [];
  int? _peakCacheKey;
  TextPainter? _peakLabelPainter;

  void _syncLabelCaches({
    required double targetMax,
    required Color labelColor,
    required Color onColor,
    required String? fontFamily,
  }) {
    final xKey = Object.hash(
      Object.hashAll(widget.labels),
      labelColor.toARGB32(),
      fontFamily,
    );
    if (_xCacheKey != xKey) {
      _disposeTextPainters(_xLabelPainters);
      _xCacheKey = xKey;
      final xStyle = TextStyle(
        fontSize: TypeScale.micro,
        color: labelColor,
        fontFamily: fontFamily,
      );
      _xLabelPainters = [
        for (final label in widget.labels) _layoutTextPainter(label, xStyle),
      ];
    }

    final yKey = Object.hash(targetMax, labelColor.toARGB32(), fontFamily);
    if (_yCacheKey != yKey) {
      _disposeTextPainters(_yLabelPainters);
      _yCacheKey = yKey;
      if (targetMax <= 0) {
        _yLabelPainters = const [];
      } else {
        final yStyle = TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: labelColor.withValues(alpha: 0.85),
          fontFamily: fontFamily,
          fontFeatures: tabularFigures,
        );
        _yLabelPainters = [
          _layoutTextPainter(_compactNumber(targetMax), yStyle),
          _layoutTextPainter(_compactNumber(targetMax / 2), yStyle),
        ];
      }
    }

    final peakKey = Object.hash(targetMax, onColor.toARGB32(), fontFamily);
    if (_peakCacheKey != peakKey) {
      _peakLabelPainter?.dispose();
      _peakCacheKey = peakKey;
      _peakLabelPainter = targetMax <= 0
          ? null
          : _layoutTextPainter(
              _compactNumber(targetMax),
              TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: onColor,
                fontFamily: fontFamily,
                fontFeatures: tabularFigures,
              ),
            );
    }
  }

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
    _disposeTextPainters(_xLabelPainters);
    _disposeTextPainters(_yLabelPainters);
    _peakLabelPainter?.dispose();
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
    var targetMax = 0.0;
    for (final v in widget.values) {
      if (v > targetMax) targetMax = v;
    }
    _syncLabelCaches(
      targetMax: targetMax,
      labelColor: colors.text3,
      onColor: colors.onPrimary,
      fontFamily: fontFamily,
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      child: SizedBox(
        height: widget.height,
        child: RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: _controller.isAnimating,
            painter: _TrendPainter(
              animation: _controller,
              fromValues: _fromValues,
              toValues: widget.values,
              labelMax: targetMax,
              labels: widget.labels,
              color: widget.color,
              onColor: colors.onPrimary,
              surfaceColor: colors.card,
              gridColor: colors.divider,
              fontFamily: fontFamily,
              xLabelPainters: _xLabelPainters,
              yLabelPainters: _yLabelPainters,
              peakLabelPainter: _peakLabelPainter,
              xCacheKey: _xCacheKey ?? 0,
              yCacheKey: _yCacheKey ?? 0,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.animation,
    required this.fromValues,
    required this.toValues,
    required this.labelMax,
    required this.labels,
    required this.color,
    required this.onColor,
    required this.surfaceColor,
    required this.gridColor,
    this.fontFamily,
    required this.xLabelPainters,
    required this.yLabelPainters,
    required this.peakLabelPainter,
    required this.xCacheKey,
    required this.yCacheKey,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<double> fromValues;
  final List<double> toValues;
  final double labelMax;
  final List<String> labels;
  final Color color;
  final Color onColor;
  final Color surfaceColor;
  final Color gridColor;
  final String? fontFamily;
  final List<TextPainter> xLabelPainters;
  final List<TextPainter> yLabelPainters;
  final TextPainter? peakLabelPainter;
  final int xCacheKey;
  final int yCacheKey;

  @override
  void paint(Canvas canvas, Size size) {
    final count = toValues.length;
    if (count == 0) return;
    final t = Curves2.out.transform(animation.value);
    final values = List<double>.generate(count, (i) {
      final start = i < fromValues.length ? fromValues[i] : 0.0;
      return start + (toValues[i] - start) * t;
    });
    var scaleMax = labelMax;
    for (final v in values) {
      if (v > scaleMax) scaleMax = v;
    }
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
      ..color = gridColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final dashPath = Path();
    for (var i = 0; i <= 2; i++) {
      final y = chartHeight * i / 2;
      if (i == 2) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      } else {
        _addDashedLine(dashPath, Offset(0, y), Offset(size.width, y));
      }
    }
    canvas.drawPath(dashPath, gridPaint);

    if (yLabelPainters.length == 2) {
      yLabelPainters[0].paint(canvas, const Offset(0, 2));
      yLabelPainters[1].paint(canvas, Offset(0, chartHeight / 2 + 2));
    }

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.04),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.65, 1.0],
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

    final nodePaint = Paint()..color = gridColor.withValues(alpha: 0.72);
    final dotFillPaint = Paint()..color = color;
    final dotCorePaint = Paint()..color = surfaceColor;
    for (var i = 0; i < points.length; i++) {
      if (values[i] <= 0) {
        canvas.drawCircle(Offset(points[i].dx, chartHeight), 1.6, nodePaint);
      } else {
        canvas.drawCircle(points[i], 3.2, dotFillPaint);
        canvas.drawCircle(points[i], 1.5, dotCorePaint);
      }
    }

    if (labelMax > 0) {
      var peakIndex = 0;
      for (var i = 1; i < values.length; i++) {
        if (values[i] > values[peakIndex]) peakIndex = i;
      }
      final peak = points[peakIndex];
      final alpha = t.clamp(0.0, 1.0);
      final peakDash = Path();
      _addDashedLine(
        peakDash,
        Offset(peak.dx, peak.dy + 6),
        Offset(peak.dx, chartHeight),
      );
      canvas.drawPath(
        peakDash,
        Paint()
          ..color = color.withValues(alpha: 0.34 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        peak,
        8.5,
        Paint()..color = color.withValues(alpha: 0.20 * alpha),
      );
      canvas.drawCircle(
        peak,
        4.4,
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        peak,
        2.0,
        Paint()..color = surfaceColor.withValues(alpha: alpha),
      );
      final useCachedPeak = alpha >= 0.99 && peakLabelPainter != null;
      final peakTp = useCachedPeak
          ? peakLabelPainter!
          : _layoutTextPainter(
              _compactNumber(labelMax),
              TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: onColor.withValues(alpha: alpha),
                fontFamily: fontFamily,
                fontFeatures: tabularFigures,
              ),
            );
      final pillW = peakTp.width + 12;
      final pillH = peakTp.height + 5;
      final px = (peak.dx - pillW / 2).clamp(0.0, size.width - pillW);
      final py = math.max(0.0, peak.dy - pillH - 9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, py, pillW, pillH),
          const Radius.circular(999),
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
      peakTp.paint(canvas, Offset(px + 6, py + 2.5));
      if (!useCachedPeak) {
        peakTp.dispose();
      }
    }

    for (var i = 0; i < xLabelPainters.length; i++) {
      final tp = xLabelPainters[i];
      final x = (step * i - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartHeight + 5));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      !listEquals(old.fromValues, fromValues) ||
      !listEquals(old.toValues, toValues) ||
      old.labelMax != labelMax ||
      !listEquals(old.labels, labels) ||
      old.color != color ||
      old.onColor != onColor ||
      old.surfaceColor != surfaceColor ||
      old.gridColor != gridColor ||
      old.fontFamily != fontFamily ||
      old.xCacheKey != xCacheKey ||
      old.yCacheKey != yCacheKey;
}

void _addDashedLine(
  Path path,
  Offset start,
  Offset end, {
  double dash = 3.5,
  double gap = 3.5,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final total = math.sqrt(dx * dx + dy * dy);
  if (total <= 0) return;
  final ux = dx / total;
  final uy = dy / total;
  var distance = 0.0;
  while (distance < total) {
    final next = math.min(distance + dash, total);
    path
      ..moveTo(start.dx + ux * distance, start.dy + uy * distance)
      ..lineTo(start.dx + ux * next, start.dy + uy * next);
    distance += dash + gap;
  }
}
