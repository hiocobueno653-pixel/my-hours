/// FlClash 风格液态玻璃居中确认弹窗：真实透底模糊、镜面高光描边、来源生长动效、全圆胶囊双钮。
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/motion_origin.dart';
import '../core/theme_tokens.dart';
import 'widgets.dart';

Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? description,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) {
  final colors = context.colors;
  final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭弹窗',
    barrierColor: Colors.transparent,
    transitionDuration: motionDuration(
      Timings.toast,
      disableAnimations: disable,
    ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final isDark = colors.isDark;
      final highContrast =
          MediaQuery.maybeOf(dialogContext)?.highContrast ?? false;
      final dialogOrigin = MotionOrigin.consumeRecent();
      final confirmBackground = danger
          ? colors.expense
          : colors.primary;
      final confirmForeground = danger ? Colors.white : colors.onPrimary;
      final dialogShape = Radii.shape(Radii.alert);
      final outerStroke = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFF0F172A).withValues(alpha: 0.08);
      final surfaceColor = isDark
          ? colors.card.withValues(alpha: highContrast ? 1.0 : 0.94)
          : colors.card.withValues(alpha: highContrast ? 1.0 : 0.96);
      final blurSigma = highContrast ? 0.0 : (disable ? 8.0 : 16.0);
      final scrimOpacity = animation.drive(
        CurveTween(
          curve: const Interval(0, 0.45, curve: Curves2.out),
        ),
      );
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: scrimOpacity,
                child: ColoredBox(
                  key: const ValueKey('dialog-scrim'),
                  color: Colors.black.withValues(alpha: isDark ? 0.56 : 0.30),
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final entering =
                    animation.status != AnimationStatus.reverse;
                final springProgress = FlClashSprings.alertCurve.transform(
                  animation.value,
                );
                final progress = springProgress.clamp(0.0, 1.0);
                final focusBlur = disable
                    ? 0.0
                    : (1.0 - (progress / 0.78).clamp(0.0, 1.0)) * 5.5;
                final contentChild = focusBlur > 0.25
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: focusBlur,
                          sigmaY: focusBlur,
                        ),
                        child: child,
                      )
                    : child;
                if (dialogOrigin == null) {
                  final scale = entering
                      ? FlClashSprings.alertEntryScale -
                            (FlClashSprings.alertEntryScale - 1.0) *
                                springProgress
                      : 1.0;
                  return Opacity(
                    opacity: progress,
                    child: Transform.scale(scale: scale, child: contentChild),
                  );
                }
                final screen = MediaQuery.sizeOf(dialogContext);
                final screenCenter = Offset(
                  screen.width / 2,
                  screen.height / 2,
                );
                final travel =
                    (dialogOrigin - screenCenter) * (1 - progress) * 0.78;
                return Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: travel,
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * progress,
                      child: contentChild,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 282,
                      maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                    ),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: dialogShape.copyWith(
                          side: BorderSide(color: outerStroke, width: 0.75),
                        ),
                        shadows: context.floatingShadows,
                      ),
                      child: ClipPath(
                        clipper: ShapeBorderClipper(shape: dialogShape),
                        child: _maybeBlur(
                          sigma: blurSigma,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: surfaceColor,
                              shape: dialogShape,
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                19,
                                20,
                                15,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.32,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: colors.text,
                                    ),
                                  ),
                                  if (description != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.48,
                                        color: colors.text2,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DialogButton(
                                          label: cancelLabel,
                                          background: colors.block,
                                          foreground: colors.text,
                                          onTap: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _DialogButton(
                                          label: confirmLabel,
                                          background: confirmBackground,
                                          foreground: confirmForeground,
                                          bold: true,
                                          onTap: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final shape = Radii.shape(Radii.md);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: shape,
        pressedScale: 0.96,
        child: Container(
          width: double.infinity,
          height: 40,
          decoration: ShapeDecoration(
            color: background,
            shape: shape,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _maybeBlur({required double sigma, required Widget child}) {
  if (sigma <= 0.1) return child;
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
