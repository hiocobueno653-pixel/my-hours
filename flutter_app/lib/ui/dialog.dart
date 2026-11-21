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
      final rimColor = isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.92);
      final outerStroke = isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.06);
      final glassTop = isDark
          ? const Color(0xFF282A33).withValues(alpha: highContrast ? 1.0 : 0.82)
          : Colors.white.withValues(alpha: highContrast ? 1.0 : 0.85);
      final glassBottom = isDark
          ? const Color(0xFF1E2028).withValues(alpha: highContrast ? 1.0 : 0.78)
          : const Color(0xFFF6F7FC).withValues(alpha: highContrast ? 1.0 : 0.78);
      final blurSigma = highContrast ? 0.0 : (disable ? 12.0 : 26.0);
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
                  color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.28),
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
                if (dialogOrigin == null) {
                  final scale = entering
                      ? FlClashSprings.alertEntryScale -
                            (FlClashSprings.alertEntryScale - 1.0) *
                                springProgress
                      : 1.0;
                  return Opacity(
                    opacity: progress,
                    child: Transform.scale(scale: scale, child: child),
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
                      child: child,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 336,
                      maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.76,
                    ),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: dialogShape.copyWith(
                          side: BorderSide(color: outerStroke, width: 0.8),
                        ),
                        shadows: [
                          ...context.floatingShadows,
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.38 : 0.12,
                            ),
                            blurRadius: 42,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipPath(
                        clipper: ShapeBorderClipper(shape: dialogShape),
                        child: _maybeBlur(
                          sigma: blurSigma,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [glassTop, glassBottom],
                              ),
                              shape: dialogShape.copyWith(
                                side: BorderSide(color: rimColor, width: 1.2),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: colors.text,
                                    ),
                                  ),
                                  if (description != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        height: 1.5,
                                        color: colors.text2,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 22),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DialogButton(
                                          label: cancelLabel,
                                          background: colors.text.withValues(
                                            alpha: isDark ? 0.12 : 0.08,
                                          ),
                                          foreground: colors.text,
                                          onTap: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _DialogButton(
                                          label: confirmLabel,
                                          background: confirmBackground,
                                          foreground: confirmForeground,
                                          bold: true,
                                          elevated: true,
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
    this.elevated = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool bold;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final shape = Radii.pillShape;
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
          height: 48,
          decoration: ShapeDecoration(
            color: background,
            shape: shape,
            shadows: elevated
                ? [
                    BoxShadow(
                      color: background.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
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
