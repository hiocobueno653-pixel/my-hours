/// 系统级居中确认弹窗：卡片底、超椭圆圆角、双块面按钮。
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:fluid_glass/fluid_glass.dart';

import '../core/motion.dart';
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
  final quality =
      GlassQualityScope.maybeOf(context) ?? GlassDeviceTier.instance.quality;
  final blur = disable || quality == GlassQuality.plain ? 10.0 : 18.0;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '关闭弹窗',
    barrierColor: Colors.transparent,
    transitionDuration: motionDuration(
      const Duration(milliseconds: 180),
      disableAnimations: disable,
    ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.16)),
              ),
            ),
          ),
          Center(
            child: Dialog(
              backgroundColor: colors.card,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: Radii.shape(Radii.xxl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 310,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.29,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: colors.text,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: colors.text2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _DialogButton(
                                label: cancelLabel,
                                background: colors.block,
                                foreground: colors.text2,
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DialogButton(
                                label: confirmLabel,
                                background: danger
                                    ? colors.expenseSoft
                                    : colors.block,
                                foreground: danger
                                    ? colors.expense
                                    : colors.primary,
                                bold: true,
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(true),
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
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves2.out,
        reverseCurve: Curves2.inCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
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
          height: 46,
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
