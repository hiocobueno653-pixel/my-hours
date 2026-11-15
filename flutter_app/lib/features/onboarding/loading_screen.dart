import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme_tokens.dart';
import 'timepage_loader.dart';

/// Flutter 第一帧到本地数据准备好之间的品牌加载页。
class TimepageLoadingScreen extends StatelessWidget {
  const TimepageLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;
    final background = dark ? const Color(0xFF0A1020) : const Color(0xFFF7F9FF);
    final muted = dark ? const Color(0xFF9BA8C7) : const Color(0xFF6B7280);
    final width = MediaQuery.sizeOf(context).width;
    final loaderWidth = (width * 0.62).clamp(190.0, 270.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.82,
                  colors: [
                    colors.primary.withValues(alpha: dark ? 0.16 : 0.10),
                    background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TimepageLoader(
                      width: loaderWidth,
                      color: colors.primary,
                      useDarkAsset: dark,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      '记录时间，记下生活。',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '正在打开你的时间页',
                      style: TextStyle(
                        color: colors.primary.withValues(
                          alpha: dark ? 0.82 : 0.78,
                        ),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
