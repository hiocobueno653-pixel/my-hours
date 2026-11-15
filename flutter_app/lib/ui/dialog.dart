/// 系统级居中确认弹窗：卡片底、超椭圆圆角、双块面按钮。
library;

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
      const Duration(milliseconds: 240),
      disableAnimations: disable,
    ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final isDark = colors.isDark;
      final dialogOrigin = MotionOrigin.recent;
      final panelTop = isDark
          ? Color.lerp(colors.card, Colors.white, 0.06)!
          : Color.lerp(Colors.white, colors.page, 0.04)!;
      final panelBottom = isDark
          ? Color.lerp(colors.card, Colors.black, 0.10)!
          : Color.lerp(Colors.white, colors.block, 0.08)!;
      final confirmBackground = danger
          ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFB91C1C))
          : colors.primary;
      final confirmForeground = danger ? Colors.white : colors.onPrimary;
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: animation,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: isDark ? 0.46 : 0.24),
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final progress = Curves.easeOutCubic.transform(animation.value);
                final screen = MediaQuery.sizeOf(dialogContext);
                final screenCenter = Offset(
                  screen.width / 2,
                  screen.height / 2,
                );
                final origin =
                    dialogOrigin ??
                    Offset(screen.width / 2, screen.height * 0.44);
                final travel = (origin - screenCenter) * (1 - progress) * 0.92;
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 330,
                      maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.76,
                    ),
                    child: Container(
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [panelTop, panelBottom],
                        ),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(32),
                          side: BorderSide(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.16 : 0.72,
                            ),
                            width: 1.4,
                          ),
                        ),
                        shadows: [
                          ...context.floatingShadows,
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.08),
                            blurRadius: 36,
                            spreadRadius: 2,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -42,
                            right: -30,
                            child: IgnorePointer(
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: isDark ? 0.16 : 0.62,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 19,
                                    height: 1.28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.01,
                                    color: colors.text,
                                  ),
                                ),
                                if (description != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    description,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.55,
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
                                        background: colors.block.withValues(
                                          alpha: isDark ? 0.68 : 0.74,
                                        ),
                                        foreground: colors.text2,
                                        onTap: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
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
                        ],
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
    final isDark = context.colors.isDark;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        shape: Radii.pillShape,
        pressedScale: 0.97,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: background,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
              side: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.32),
                width: 0.8,
              ),
            ),
          ),
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
    );
  }
}
