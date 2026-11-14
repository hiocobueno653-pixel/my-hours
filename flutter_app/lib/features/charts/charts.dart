/// 图表：全部 `CustomPainter` 自绘，零第三方图表库。
///
/// 平滑折线的算法借自 `E:/蒸馏/prism_ui/lib/line_chart.dart` 的手法
/// （Catmull-Rom 斜率夹取 + 三次贝塞尔 + 面积填充），但这里带坐标轴与月份标签，
/// 因为年度趋势需要刻度，而那个实现只是流式 sparkline。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme_tokens.dart';

/// 双序列柱状图（收入/支出）。
class BarPairChart extends StatelessWidget {
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

  String get _semanticText {
    final prefix = semanticLabel ?? '柱状图';
    final formatter = valueFormatter ?? (value) => _compactNumber(value);
    final parts = <String>[];
    for (var i = 0; i < labels.length; i++) {
      final a = i < seriesA.length ? formatter(seriesA[i]) : '0';
      final b = i < seriesB.length ? formatter(seriesB[i]) : '0';
      parts.add('${labels[i]}：$seriesAName $a，$seriesBName $b');
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
      hint: onSelected == null ? null : '轻点柱子切换月份',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onSelected == null || labels.isEmpty
                ? null
                : (details) {
                    final slot = constraints.maxWidth / labels.length;
                    if (slot <= 0) return;
                    final index = (details.localPosition.dx / slot)
                        .floor()
                        .clamp(0, labels.length - 1)
                        .toInt();
                    HapticFeedback.selectionClick();
                    onSelected!(index);
                  },
            child: CustomPaint(
              painter: _BarPairPainter(
                labels: labels,
                seriesA: seriesA,
                seriesB: seriesB,
                colorA: colorA,
                colorB: colorB,
                gridColor: colors.divider,
                labelColor: colors.text3,
                selectedIndex: selectedIndex,
                highlightColor: colors.primary.withValues(
                  alpha: colors.isDark ? 0.12 : 0.07,
                ),
                selectedLabelColor: colors.primary,
              ),
              child: SizedBox(height: height, width: double.infinity),
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
    required this.colorA,
    required this.colorB,
    required this.gridColor,
    required this.labelColor,
    required this.selectedIndex,
    required this.highlightColor,
    required this.selectedLabelColor,
  });

  final List<String> labels;
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA;
  final Color colorB;
  final Color gridColor;
  final Color labelColor;
  final int? selectedIndex;
  final Color highlightColor;
  final Color selectedLabelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    const bottomInset = 20.0;
    final chartHeight = size.height - bottomInset;
    final maxValue = [
      ...seriesA,
      ...seriesB,
    ].fold<double>(0, (m, v) => math.max(m, v));
    final scale = maxValue <= 0 ? 1.0 : chartHeight / (maxValue * 1.15);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / labels.length;
    final barWidth = math.min(9.0, slot * 0.26);
    final radius = Radius.circular(barWidth / 2);

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < labels.length) {
      final left = slot * selectedIndex! + 2;
      final right = slot * (selectedIndex! + 1) - 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 0, right, chartHeight),
          const Radius.circular(10),
        ),
        Paint()..color = highlightColor,
      );
    }

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
          Paint()..color = colorA,
        );
      }
      if (b > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 1.5, chartHeight - b, barWidth, b),
            radius,
          ),
          Paint()..color = colorB,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 9.5,
            color: i == selectedIndex ? selectedLabelColor : labelColor,
            fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(_BarPairPainter old) =>
      old.seriesA != seriesA ||
      old.seriesB != seriesB ||
      old.labels != labels ||
      old.colorA != colorA ||
      old.colorB != colorB ||
      old.selectedIndex != selectedIndex ||
      old.highlightColor != highlightColor ||
      old.selectedLabelColor != selectedLabelColor;
}

/// 环形占比图。
class DonutChart extends StatelessWidget {
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

  String get _semanticText {
    final prefix = semanticLabel ?? '环形占比图';
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return '$prefix，暂无数据';
    final parts = <String>[];
    for (var i = 0; i < labels.length; i++) {
      if (i >= values.length || values[i] <= 0) continue;
      final percent = (values[i] / total * 100).round();
      parts.add('${labels[i]} $percent%');
    }
    final center = centerValue == null ? '' : '，中心 $centerLabel $centerValue';
    return '$prefix。${parts.join('，')}$center';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.colors;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            values: values,
            colors: colors,
            trackColor: tokens.inset,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerValue != null)
                  Text(
                    centerValue!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.text,
                      letterSpacing: -0.02,
                    ),
                  ),
                if (centerLabel != null)
                  Text(
                    centerLabel!,
                    style: TextStyle(fontSize: 10.5, color: tokens.text3),
                  ),
              ],
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
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

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
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * (values[i] / total);
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colors[i % colors.length];
      canvas.drawArc(rect, start, math.max(0, sweep - 0.02), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors;
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
    return Semantics(
      container: true,
      label: '进度',
      value: '${(clamped * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(height),
              ),
            ),
            child: ColoredBox(
              color: trackColor ?? colors.inset,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clamped,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 年度工时面积折线（带月份标签与基线）。
class TrendChart extends StatelessWidget {
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

  String get _semanticText {
    final prefix = semanticLabel ?? '趋势图';
    if (values.isEmpty) return '$prefix，暂无数据';
    final parts = <String>[];
    for (var i = 0; i < values.length; i++) {
      final label = i < labels.length ? labels[i] : '${i + 1}';
      parts.add('$label ${_compactNumber(values[i])}');
    }
    return '$prefix。$seriesName：${parts.join('，')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticText,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _TrendPainter(
            values: values,
            labels: labels,
            color: color,
            gridColor: colors.divider,
            labelColor: colors.text3,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const bottomInset = 18.0;
    final chartHeight = size.height - bottomInset;
    final maxValue = values.fold<double>(0, (m, v) => math.max(m, v));
    final top = maxValue <= 0 ? 1.0 : maxValue * 1.12;
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

    canvas
      ..save()
      ..clipRect(Offset.zero & Size(size.width, chartHeight))
      ..drawPath(area, Paint()..color = color.withValues(alpha: 0.14))
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      gridPaint,
    );

    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (step * i - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartHeight + 5));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.labels != labels || old.color != color;
}
