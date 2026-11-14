/// 设计令牌：颜色 / 圆角 / 间距 / 阴影 / 字号。
///
/// 视觉基线来自 `E:/蒸馏/FlClash_UI` 的令牌与版式测量（GPL-3.0 项目的
/// 设计事实），只取数值，不引入 prism_ui 代码或资源。时页品牌色为
/// `#2563EB`，深色主题使用偏蓝的夜间灰阶。改这里就等于改全站，不要在
/// 组件里写裸色值。
library;

import 'package:flutter/material.dart';

/// 一套颜色。字段名保留旧版别名，避免页面层大范围改名。
class AppColors {
  const AppColors({
    required this.page,
    required this.card,
    required this.block,
    required this.inset,
    required this.text,
    required this.text2,
    required this.text3,
    required this.divider,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.warning,
    required this.warningSoft,
    required this.chart,
    required this.isDark,
  });

  final Color page;
  final Color card;
  final Color block;
  final Color inset;
  final Color text;
  final Color text2;
  final Color text3;
  final Color divider;
  final Color outline;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color warning;
  final Color warningSoft;
  final List<Color> chart;
  final bool isDark;

  Color get bg => page;
  Color get surface => card;
  Color get surfaceSoft => block;
  Color get surfaceMuted => inset;
  Color get border => divider;
  Color get borderStrong => outline;
  Color get accent => primary;
  Color get accentStrong => primary;
  Color get accentSoft => primaryContainer;

  static const AppColors light = AppColors(
    page: Color(0xFFF3F5F9),
    card: Color(0xFFFFFFFF),
    block: Color(0xFFEDF1F7),
    inset: Color(0xFFE2E8F2),
    text: Color(0xFF111827),
    text2: Color(0xFF4B5563),
    text3: Color(0xFF667085),
    divider: Color(0x24111827),
    outline: Color(0xFF6B7280),
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    income: Color(0xFF047857),
    incomeSoft: Color(0xFFD1FAE5),
    expense: Color(0xFFDC2626),
    expenseSoft: Color(0xFFFEE2E2),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    chart: [
      Color(0xFF2563EB),
      Color(0xFF60A5FA),
      Color(0xFF047857),
      Color(0xFFDC2626),
      Color(0xFFB45309),
      Color(0xFF94A3B8),
    ],
    isDark: false,
  );

  static const AppColors dark = AppColors(
    page: Color(0xFF0B1120),
    card: Color(0xFF151D2E),
    block: Color(0xFF1E293B),
    inset: Color(0xFF273449),
    text: Color(0xFFF8FAFC),
    text2: Color(0xFFC7D2E5),
    text3: Color(0xFF8FA0B9),
    divider: Color(0x24F8FAFC),
    outline: Color(0xFF94A3B8),
    primary: Color(0xFF6D9EFF),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFDBEAFE),
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF064E3B),
    expense: Color(0xFFF87171),
    expenseSoft: Color(0xFF7F1D1D),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF78350F),
    chart: [
      Color(0xFF6D9EFF),
      Color(0xFF93C5FD),
      Color(0xFF34D399),
      Color(0xFFF87171),
      Color(0xFFFBBF24),
      Color(0xFF94A3B8),
    ],
    isDark: true,
  );
}

/// 圆角。所有容器与胶囊都走超椭圆，不用普通圆角矩形。
abstract final class Radii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double hero = 32;
  static const double alert = 34;
  static const double card = 28;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(alert),
  );

  static RoundedSuperellipseBorder shape(double radius) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));

  static RoundedSuperellipseBorder get cardShape => shape(card);
  static RoundedSuperellipseBorder get pillShape => shape(pill);
}

/// 间距（4pt 刻度）。
abstract final class Gaps {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 卡片之间的间距（FlClash 移动端实测 8）。
  static const double cardGap = 8;

  /// 页面左右内边距。
  static const double page = 16;

  /// 主页面标题栏高度（不含状态栏）。
  static const double headerHeight = 72;
}

/// 主题扩展：把令牌挂到 `ThemeData.extensions`，组件里用 `context.tokens` 取。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.colors,
    required this.shadows,
    required this.floatingShadows,
  });

  final AppColors colors;
  final List<BoxShadow> shadows;
  final List<BoxShadow> floatingShadows;

  static const AppTokens lightTokens = AppTokens(
    colors: AppColors.light,
    shadows: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0x17000000),
        blurRadius: 28,
        spreadRadius: -6,
        offset: Offset(0, 12),
      ),
    ],
    floatingShadows: [
      BoxShadow(
        color: Color(0x2E000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  static const AppTokens darkTokens = AppTokens(
    colors: AppColors.dark,
    shadows: [
      BoxShadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 24,
        spreadRadius: -6,
        offset: Offset(0, 10),
      ),
    ],
    floatingShadows: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  @override
  AppTokens copyWith({
    AppColors? colors,
    List<BoxShadow>? shadows,
    List<BoxShadow>? floatingShadows,
  }) => AppTokens(
    colors: colors ?? this.colors,
    shadows: shadows ?? this.shadows,
    floatingShadows: floatingShadows ?? this.floatingShadows,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      colors: t < 0.5 ? colors : other.colors,
      shadows: t < 0.5 ? shadows : other.shadows,
      floatingShadows: t < 0.5 ? floatingShadows : other.floatingShadows,
    );
  }
}

/// 便捷访问。
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.lightTokens;

  AppColors get colors => tokens.colors;

  List<BoxShadow> get shadows => tokens.shadows;

  List<BoxShadow> get floatingShadows => tokens.floatingShadows;
}

/// 页面滚动内容的底部留白。
///
/// 手机底部有悬浮 Dock，需要预留约一个 Dock 的高度；宽屏使用侧栏后
/// Dock 不再出现，只保留系统手势区和少量呼吸空间。
///
/// 键盘弹出时改按键盘高度留白：AppShell 关掉了 `resizeToAvoidBottomInset`
/// （否则悬浮 Dock 会被顶到键盘上方），所以这一层必须自己把内容
/// 顶到键盘之上，否则列表底部会一直藏在键盘后面。
double pageBottomInset(BuildContext context) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  if (keyboard > 0) return keyboard + 24;
  final system = MediaQuery.paddingOf(context).bottom;
  return system + (MediaQuery.sizeOf(context).width >= 720 ? 24 : 104);
}

/// 构建 ThemeData。
///
/// 字体走平台系统字体（FlClash 的移动端字形），不打包品牌字体；
/// 数字由各组件显式启用 tabular figures。
ThemeData buildAppTheme(AppColors colors, AppTokens tokens) {
  final base = ThemeData(
    brightness: colors.isDark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.page,
    canvasColor: colors.page,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: colors.text.withValues(alpha: 0.04),
    colorScheme: ColorScheme(
      brightness: colors.isDark ? Brightness.dark : Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.income,
      onSecondary: colors.isDark ? const Color(0xFF003910) : Colors.white,
      error: colors.expense,
      onError: colors.isDark ? const Color(0xFF690005) : Colors.white,
      errorContainer: colors.expenseSoft,
      onErrorContainer: colors.isDark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF93000A),
      surface: colors.card,
      onSurface: colors.text,
      onSurfaceVariant: colors.text2,
      surfaceContainerHighest: colors.inset,
      outline: colors.outline,
      outlineVariant: colors.divider,
    ),
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: TextStyle(
      fontSize: 40,
      height: 1.1,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: colors.text,
    ),
    displayMedium: TextStyle(
      fontSize: 34,
      height: 1.21,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: colors.text,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      height: 1.21,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.01,
      color: colors.text,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: colors.text,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.27,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01,
      color: colors.text,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: colors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.29,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: colors.text,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.33,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: colors.text,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      height: 1.29,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: colors.text,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.33,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: colors.text,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.38,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: colors.text2,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.33,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: colors.text,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: colors.text2,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: colors.text3,
    ),
  );
  // 主题层统一关闭文字装饰；弹层还会提供透明 Material，避免 MaterialApp
  // 的 fallback 错误样式（黄色双下划线）泄漏到正文。
  final normalizedTextTheme = textTheme.apply(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  return base.copyWith(
    extensions: [tokens],
    textTheme: normalizedTextTheme,
    dividerColor: colors.divider,
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: Radii.shape(Radii.xxl),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      modalBarrierColor: Color(0x33000000),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onPrimary
            : colors.card,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.inset,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: WidgetStatePropertyAll(
        colors.primary.withValues(alpha: 0.10),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.block,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(fontSize: 13, color: colors.text3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      titleTextStyle: TextStyle(
        fontSize: 15,
        height: 1.33,
        fontWeight: FontWeight.w500,
        color: colors.text,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        height: 1.38,
        color: colors.text2,
      ),
      iconColor: colors.text2,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.primary.withValues(alpha: 0.22),
      selectionHandleColor: colors.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.inset,
      circularTrackColor: colors.inset,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.isDark ? colors.block : const Color(0xE6141416),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: Radii.shape(Radii.md),
    ),
  );
}
