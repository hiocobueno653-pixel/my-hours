import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/theme_tokens.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';

enum _PaletteMode { grid, spectrum, sliders }

/// FlClash 风格自定义主题色面板：
/// - 顶部亮/暗双小屏实时预览 + `#RRGGBB` 十六进制输入框；
/// - 网格（12×10 栅格）/ 光谱（2D 连续 HSL）/ 滑块（HSV 三轨渐变）三模式切换；
/// - 点「确定」先关闭弹层再触发全树换色，避免关窗动画掉帧。
Future<void> showCustomColorSheet(
  BuildContext context, {
  required Color initialColor,
  required AppColorStyle colorStyle,
  required bool pureBlack,
  required bool floatingDock,
  required ValueChanged<Color> onConfirmed,
  String title = '自定义主题色',
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => _CustomColorSheet(
      title: title,
      initialColor: initialColor,
      colorStyle: colorStyle,
      pureBlack: pureBlack,
      floatingDock: floatingDock,
      onConfirmed: onConfirmed,
    ),
  );
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({
    required this.title,
    required this.initialColor,
    required this.colorStyle,
    required this.pureBlack,
    required this.floatingDock,
    required this.onConfirmed,
  });

  final String title;
  final Color initialColor;
  final AppColorStyle colorStyle;
  final bool pureBlack;
  final bool floatingDock;
  final ValueChanged<Color> onConfirmed;

  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late final ValueNotifier<Color> _color = ValueNotifier<Color>(
    Color(widget.initialColor.toARGB32() | 0xFF000000),
  );
  late HSVColor _hsv = HSVColor.fromColor(_color.value);
  _PaletteMode _mode = _PaletteMode.grid;

  @override
  void initState() {
    super.initState();
    _color.addListener(_syncHsv);
  }

  void _syncHsv() {
    if (_hsv.toColor().toARGB32() != _color.value.toARGB32()) {
      setState(() => _hsv = HSVColor.fromColor(_color.value));
    }
  }

  void _pickColor(Color next) {
    final opaque = Color(next.toARGB32() | 0xFF000000);
    if (_color.value.toARGB32() == opaque.toARGB32()) return;
    _color.value = opaque;
  }

  void _pickHsv(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _color.value = Color(hsv.toColor().toARGB32() | 0xFF000000);
  }

  void _confirm() {
    HapticFeedback.selectionClick();
    final picked = _color.value;
    final onConfirmed = widget.onConfirmed;
    final route = ModalRoute.of(context);
    if (route != null) {
      unawaited(route.completed.whenComplete(() => onConfirmed(picked)));
    } else {
      onConfirmed(picked);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _color.removeListener(_syncHsv);
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SheetScaffold(
      title: widget.title,
      maxHeightFactor: 0.90,
      actions: [
        TextActionButton(label: '确定', onPressed: _confirm),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<Color>(
            valueListenable: _color,
            builder: (_, color, _) => _DualBrightnessPreview(
              color: color,
              colorStyle: widget.colorStyle,
              pureBlack: widget.pureBlack,
              floatingDock: widget.floatingDock,
              onColorChanged: _pickColor,
            ),
          ),
          const SizedBox(height: Gaps.lg),
          Segmented<_PaletteMode>(
            values: _PaletteMode.values,
            selected: _mode,
            accentActive: true,
            labelOf: (mode) => switch (mode) {
              _PaletteMode.grid => '网格',
              _PaletteMode.spectrum => '光谱',
              _PaletteMode.sliders => '滑块',
            },
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(height: Gaps.lg),
          AnimatedSize(
            duration: motionDuration(Timings.base, disableAnimations: disable),
            curve: Curves2.out,
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder<Color>(
              valueListenable: _color,
              builder: (_, color, _) => switch (_mode) {
                _PaletteMode.grid => _ColorGridPad(
                  color: color,
                  onPicked: _pickColor,
                ),
                _PaletteMode.spectrum => _SpectrumPad(
                  color: color,
                  onPicked: _pickColor,
                ),
                _PaletteMode.sliders => _HsvSlidersPanel(
                  hsv: _hsv,
                  onChanged: _pickHsv,
                ),
              },
            ),
          ),
          const SizedBox(height: Gaps.md),
        ],
      ),
    );
  }
}

class _DualBrightnessPreview extends StatelessWidget {
  const _DualBrightnessPreview({
    required this.color,
    required this.colorStyle,
    required this.pureBlack,
    required this.floatingDock,
    required this.onColorChanged,
  });

  final Color color;
  final AppColorStyle colorStyle;
  final bool pureBlack;
  final bool floatingDock;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lightPalette = AppColors.light.withAccent(
      color,
      isDark: false,
      style: colorStyle,
    );
    final darkPalette = AppColors.dark.withAccent(
      color,
      isDark: true,
      style: colorStyle,
      pureBlack: pureBlack,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: colors.block,
        shape: Radii.shape(Radii.xl),
      ),
      child: Row(
        children: [
          _MiniPhonePreview(palette: lightPalette, floatingDock: floatingDock),
          const SizedBox(width: 10),
          _MiniPhonePreview(palette: darkPalette, floatingDock: floatingDock),
          const SizedBox(width: 12),
          Expanded(
            child: _HexColorInput(color: color, onChanged: onColorChanged),
          ),
        ],
      ),
    );
  }
}

class _MiniPhonePreview extends StatelessWidget {
  const _MiniPhonePreview({
    required this.palette,
    required this.floatingDock,
  });

  final AppColors palette;
  final bool floatingDock;

  @override
  Widget build(BuildContext context) {
    final shape = Radii.shape(Radii.md);
    return ExcludeSemantics(
      child: Container(
        width: 70,
        height: 94,
        padding: const EdgeInsets.all(6),
        decoration: ShapeDecoration(
          color: palette.page,
          shape: shape.copyWith(
            side: BorderSide(color: palette.cardBorder, width: 0.8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.text,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: ShapeDecoration(
                color: palette.card,
                shape: Radii.shape(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 14,
                    height: 10,
                    decoration: ShapeDecoration(
                      color: palette.primary,
                      shape: Radii.pillShape,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: ShapeDecoration(
                        color: palette.card,
                        shape: Radii.shape(6),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 14,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.primaryContainer,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: ShapeDecoration(
                        color: palette.card,
                        shape: Radii.shape(6),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 14,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.incomeSoft,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 11,
              margin: EdgeInsets.symmetric(horizontal: floatingDock ? 6 : 0),
              decoration: ShapeDecoration(
                color: palette.card,
                shape: floatingDock ? Radii.pillShape : Radii.shape(3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 6,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 4,
                      height: 3,
                      decoration: BoxDecoration(
                        color: palette.text3.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexColorInput extends StatefulWidget {
  const _HexColorInput({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_HexColorInput> createState() => _HexColorInputState();
}

class _HexColorInputState extends State<_HexColorInput> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.color),
  );
  final FocusNode _focusNode = FocusNode();

  static String _format(Color color) => (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();

  @override
  void didUpdateWidget(covariant _HexColorInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _format(widget.color);
    if (!_focusNode.hasFocus && _controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final cleaned = raw.replaceAll('#', '').trim().toUpperCase();
    if (cleaned.length != 6) return;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return;
    widget.onChanged(Color(0xFF000000 | parsed));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rgb = widget.color;
    final r = (rgb.r * 255).round();
    final g = (rgb.g * 255).round();
    final b = (rgb.b * 255).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'HEX 色值',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.text2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: ShapeDecoration(
            color: colors.card,
            shape: Radii.shape(Radii.sm).copyWith(
              side: BorderSide(color: colors.divider, width: 0.8),
            ),
          ),
          child: Row(
            children: [
              Text(
                '#',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text3,
                  fontFeatures: tabularFigures,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  maxLength: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                  ],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.text,
                    fontFeatures: tabularFigures,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'RGB $r, $g, $b',
          style: TextStyle(
            fontSize: 11,
            color: colors.text3,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

const double _padCorner = 16.0;
const double _thumbRadius = 13.0;

class _ColorGridPad extends StatelessWidget {
  const _ColorGridPad({required this.color, required this.onPicked});

  static const _hues = <double>[
    210,
    232,
    262,
    290,
    328,
    354,
    18,
    38,
    54,
    88,
    142,
    176,
  ];
  static const _lightnesses = <double>[
    0.22,
    0.30,
    0.38,
    0.46,
    0.53,
    0.61,
    0.70,
    0.78,
    0.86,
  ];

  static final List<List<Color>> _rows = [
    [
      for (var c = 0; c < _hues.length; c++)
        HSLColor.fromAHSL(1, 0, 0, 1.0 - c / (_hues.length - 1)).toColor(),
    ],
    for (final l in _lightnesses)
      [
        for (final h in _hues)
          HSLColor.fromAHSL(1, h, l > 0.75 ? 0.86 : 0.92, l).toColor(),
      ],
  ];

  final Color color;
  final ValueChanged<Color> onPicked;

  @override
  Widget build(BuildContext context) {
    final columns = _hues.length;
    final rows = _rows.length;
    return AspectRatio(
      aspectRatio: columns / rows,
      child: _ImmediatePickArea(
        onPicked: (pos, size) {
          final col = (pos.dx / size.width * columns)
              .floor()
              .clamp(0, columns - 1);
          final row = (pos.dy / size.height * rows).floor().clamp(0, rows - 1);
          onPicked(_rows[row][col]);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ColorGridPainter(rows: _rows, selected: color),
          ),
        ),
      ),
    );
  }
}

class _ColorGridPainter extends CustomPainter {
  const _ColorGridPainter({required this.rows, required this.selected});

  final List<List<Color>> rows;
  final Color selected;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = rows.first.length;
    final cellW = size.width / cols;
    final cellH = size.height / rows.length;
    canvas.save();
    canvas.clipRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(_padCorner),
      ),
    );
    final paint = Paint()..isAntiAlias = false;
    Rect? selectedRect;
    final selectedRgb = selected.toARGB32() & 0xFFFFFF;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        final cellColor = rows[r][c];
        canvas.drawRect(rect, paint..color = cellColor);
        if ((cellColor.toARGB32() & 0xFFFFFF) == selectedRgb) {
          selectedRect = rect;
        }
      }
    }
    if (selectedRect != null) {
      final isDark = selected.computeLuminance() < 0.45;
      canvas.drawRRect(
        RRect.fromRectAndRadius(selectedRect.deflate(1.5), const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = isDark ? Colors.white : const Color(0xFF111114),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ColorGridPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class _SpectrumPad extends StatefulWidget {
  const _SpectrumPad({required this.color, required this.onPicked});

  final Color color;
  final ValueChanged<Color> onPicked;

  @override
  State<_SpectrumPad> createState() => _SpectrumPadState();
}

class _SpectrumPadState extends State<_SpectrumPad> {
  ({Offset position, int rgb})? _picked;

  Offset _positionOf(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    if (_picked != null && _picked!.rgb == rgb) {
      return _picked!.position;
    }
    final hsl = HSLColor.fromColor(color);
    return Offset(hsl.hue / 360.0, 1.0 - hsl.lightness);
  }

  void _handlePicked(Offset pos, Size size) {
    final frac = Offset(pos.dx / size.width, pos.dy / size.height);
    final next = HSLColor.fromAHSL(
      1,
      clampDouble(frac.dx * 360.0, 0, 359.99),
      1,
      clampDouble(1.0 - frac.dy, 0, 1),
    ).toColor();
    _picked = (position: frac, rgb: next.toARGB32() & 0xFFFFFF);
    widget.onPicked(next);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 6 / 5,
      child: _ImmediatePickArea(
        onPicked: _handlePicked,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _SpectrumPainter(
              color: widget.color,
              position: _positionOf(widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter({required this.color, required this.position});

  static final List<Color> _hues = [
    for (var hue = 0; hue <= 360; hue += 60)
      HSLColor.fromAHSL(1, (hue % 360).toDouble(), 1, 0.5).toColor(),
  ];

  final Color color;
  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RSuperellipse.fromRectAndRadius(
      rect,
      const Radius.circular(_padCorner),
    );
    canvas.drawRSuperellipse(
      shape,
      Paint()..shader = LinearGradient(colors: _hues).createShader(rect),
    );
    canvas.drawRSuperellipse(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0x00FFFFFF),
            Color(0x00000000),
            Colors.black,
          ],
          stops: [0, 0.5, 0.5, 1],
        ).createShader(rect),
    );
    final center = Offset(
      clampDouble(position.dx * size.width, _thumbRadius, size.width - _thumbRadius),
      clampDouble(position.dy * size.height, _thumbRadius, size.height - _thumbRadius),
    );
    _paintThumb(canvas, center, _thumbRadius, color);
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.position != position;
}

void _paintThumb(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center + const Offset(0, 2),
    radius,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius - 3, Paint()..color = color);
}

class _HsvSlidersPanel extends StatelessWidget {
  const _HsvSlidersPanel({required this.hsv, required this.onChanged});

  static final List<Color> _hueStops = [
    for (var hue = 0; hue <= 360; hue += 60)
      HSVColor.fromAHSV(1, (hue % 360).toDouble(), 1, 1).toColor(),
  ];

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pureHue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    final satStart = HSVColor.fromAHSV(1, hsv.hue, 0, hsv.value).toColor();
    final satEnd = HSVColor.fromAHSV(1, hsv.hue, 1, hsv.value).toColor();
    final valEnd = HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, 1).toColor();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: ShapeDecoration(
        color: colors.block,
        shape: Radii.shape(Radii.xl),
      ),
      child: Column(
        children: [
          _GradientSliderRow(
            label: '色相',
            valueText: '${hsv.hue.round()}°',
            fraction: hsv.hue / 360.0,
            gradientColors: _hueStops,
            thumbColor: pureHue,
            onChanged: (f) => onChanged(hsv.withHue((f * 360.0).clamp(0, 359.99))),
          ),
          const SizedBox(height: 16),
          _GradientSliderRow(
            label: '饱和度',
            valueText: '${(hsv.saturation * 100).round()}%',
            fraction: hsv.saturation,
            gradientColors: [satStart, satEnd],
            thumbColor: hsv.toColor(),
            onChanged: (f) => onChanged(hsv.withSaturation(f)),
          ),
          const SizedBox(height: 16),
          _GradientSliderRow(
            label: '明度',
            valueText: '${(hsv.value * 100).round()}%',
            fraction: hsv.value,
            gradientColors: [Colors.black, valEnd],
            thumbColor: hsv.toColor(),
            onChanged: (f) => onChanged(hsv.withValue(f)),
          ),
        ],
      ),
    );
  }
}

class _GradientSliderRow extends StatelessWidget {
  const _GradientSliderRow({
    required this.label,
    required this.valueText,
    required this.fraction,
    required this.gradientColors,
    required this.thumbColor,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double fraction;
  final List<Color> gradientColors;
  final Color thumbColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.text2,
              ),
            ),
            const Spacer(),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.text,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: _ImmediatePickArea(
            onPicked: (pos, size) {
              final usable = math.max(1.0, size.width - _thumbRadius * 2);
              final next = ((pos.dx - _thumbRadius) / usable).clamp(0.0, 1.0);
              onChanged(next);
            },
            child: CustomPaint(
              painter: _GradientTrackPainter(
                fraction: fraction,
                colors: gradientColors,
                thumbColor: thumbColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientTrackPainter extends CustomPainter {
  const _GradientTrackPainter({
    required this.fraction,
    required this.colors,
    required this.thumbColor,
  });

  final double fraction;
  final List<Color> colors;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 20.0;
    final trackRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: trackHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(trackHeight / 2)),
      Paint()..shader = LinearGradient(colors: colors).createShader(trackRect),
    );
    final cx = _thumbRadius + (size.width - _thumbRadius * 2) * fraction.clamp(0.0, 1.0);
    _paintThumb(canvas, Offset(cx, size.height / 2), _thumbRadius, thumbColor);
  }

  @override
  bool shouldRepaint(_GradientTrackPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.thumbColor != thumbColor ||
      oldDelegate.colors.first != colors.first ||
      oldDelegate.colors.last != colors.last;
}

class _ImmediatePanRecognizer extends PanGestureRecognizer {
  _ImmediatePanRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _ImmediatePickArea extends StatelessWidget {
  const _ImmediatePickArea({required this.onPicked, required this.child});

  final void Function(Offset position, Size size) onPicked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = constraints.biggest;
        void pick(Offset local) => onPicked(
          Offset(
            clampDouble(local.dx, 0, size.width),
            clampDouble(local.dy, 0, size.height),
          ),
          size,
        );
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _ImmediatePanRecognizer:
                GestureRecognizerFactoryWithHandlers<_ImmediatePanRecognizer>(
                  () => _ImmediatePanRecognizer(debugOwner: this),
                  (recognizer) => recognizer
                    ..onDown = ((details) => pick(details.localPosition))
                    ..onUpdate = ((details) => pick(details.localPosition)),
                ),
          },
          child: child,
        );
      },
    );
  }
}
