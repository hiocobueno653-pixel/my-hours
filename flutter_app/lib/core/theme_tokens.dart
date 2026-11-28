/// 设计令牌：系统分组背景、清晰内容表面与克制的 Liquid Glass 控件。
///
/// 以语义色构建内容层，用蓝色强调交互，再由悬浮导航建立玻璃层级。
library;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

/// 主题色风格。主题页只改变主色及其派生色，不改变语义色。
enum AppColorStyle { vivid, atmospheric, soft, monochrome }

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

  /// 分组卡片边界，在浅色与深色外观下保持细微区分。
  Color get cardBorder =>
      isDark ? const Color(0xFF2B2E3B) : const Color(0xFFE2E4EC);

  /// 英雄卡片基底色：与当前明暗界面同色系，仅融入极轻的主题色光感。
  Color get heroBase => Color.lerp(card, primary, isDark ? 0.045 : 0.018)!;

  /// 英雄卡片高光端色。
  Color get heroHighlight =>
      Color.lerp(card, Colors.white, isDark ? 0.05 : 0.0)!;

  /// 英雄卡片下沉底座色：用于今日主卡操作盘、预算条与统计底栏，建立「上读数 / 下操作」两段式仪器质感。
  Color get heroWell => Color.lerp(card, block, isDark ? 0.56 : 0.44)!;

  AppColors copyWith({
    Color? page,
    Color? card,
    Color? block,
    Color? inset,
    Color? text,
    Color? text2,
    Color? text3,
    Color? divider,
    Color? outline,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? warning,
    Color? warningSoft,
    List<Color>? chart,
    bool? isDark,
  }) {
    return AppColors(
      page: page ?? this.page,
      card: card ?? this.card,
      block: block ?? this.block,
      inset: inset ?? this.inset,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      divider: divider ?? this.divider,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      chart: chart ?? this.chart,
      isDark: isDark ?? this.isDark,
    );
  }

  /// 从主题页的强调色派生一整套主色，保留已有的语义色。
  AppColors withAccent(
    Color seed, {
    required bool isDark,
    AppColorStyle style = AppColorStyle.vivid,
    bool pureBlack = false,
  }) {
    final base = isDark
        ? (pureBlack ? AppColors.darkPureBlack : AppColors.dark)
        : AppColors.light;
    var adjusted = switch (style) {
      AppColorStyle.vivid => seed,
      AppColorStyle.atmospheric => Color.lerp(
        seed,
        isDark ? const Color(0xFF111114) : const Color(0xFFF2F2F7),
        isDark ? 0.16 : 0.10,
      )!,
      AppColorStyle.soft => Color.lerp(
        seed,
        isDark ? const Color(0xFF1E1F24) : Colors.white,
        isDark ? 0.18 : 0.20,
      )!,
      AppColorStyle.monochrome => HSLColor.fromColor(
        seed,
      ).withSaturation(0).toColor(),
    };
    if (isDark) {
      adjusted = Color.lerp(adjusted, Colors.white, 0.24)!;
    }
    final container = isDark
        ? Color.lerp(adjusted, base.inset, 0.72)!
        : Color.lerp(adjusted, Colors.white, 0.88)!;
    final onContainer = isDark
        ? Color.lerp(adjusted, Colors.white, 0.72)!
        : Color.lerp(adjusted, Colors.black, 0.40)!;
    const darkInk = Color(0xFF071222);
    final darkInkContrast = _contrastRatio(adjusted, darkInk);
    final whiteContrast = _contrastRatio(adjusted, Colors.white);
    final onPrimary = (whiteContrast >= 4.0 || whiteContrast >= darkInkContrast)
        ? Colors.white
        : darkInk;
    var page = base.page;
    var card = base.card;
    var block = base.block;
    var inset = base.inset;
    if (!(isDark && pureBlack)) {
      switch (style) {
        case AppColorStyle.vivid:
          break;
        case AppColorStyle.atmospheric:
          page = Color.lerp(base.page, adjusted, isDark ? 0.07 : 0.028)!;
          card = Color.lerp(base.card, adjusted, isDark ? 0.06 : 0.006)!;
          block = Color.lerp(base.block, adjusted, isDark ? 0.09 : 0.05)!;
          inset = Color.lerp(base.inset, adjusted, isDark ? 0.11 : 0.07)!;
          break;
        case AppColorStyle.soft:
          page = Color.lerp(base.page, Colors.white, isDark ? 0.03 : 0.16)!;
          card = Color.lerp(base.card, Colors.white, isDark ? 0.05 : 0.0)!;
          block = Color.lerp(base.block, Colors.white, isDark ? 0.07 : 0.12)!;
          inset = Color.lerp(base.inset, Colors.white, isDark ? 0.09 : 0.08)!;
          break;
        case AppColorStyle.monochrome:
          page = isDark ? const Color(0xFF0B0B0E) : const Color(0xFFF1F1F3);
          card = isDark ? const Color(0xFF17181C) : const Color(0xFFFFFFFF);
          block = isDark ? const Color(0xFF24262C) : const Color(0xFFE7E7EB);
          inset = isDark ? const Color(0xFF32343D) : const Color(0xFFDADAE0);
          break;
      }
    }
    return base.copyWith(
      page: page,
      card: card,
      block: block,
      inset: inset,
      primary: adjusted,
      onPrimary: onPrimary,
      primaryContainer: container,
      onPrimaryContainer: onContainer,
      chart: [
        adjusted,
        Color.lerp(adjusted, Colors.white, isDark ? 0.30 : 0.28)!,
        ...base.chart.sublist(2),
      ],
    );
  }

  static const AppColors light = AppColors(
    page: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    block: Color(0xFFE7E8F0),
    inset: Color(0xFFDBDDE8),
    text: Color(0xFF111216),
    text2: Color(0xFF565966),
    text3: Color(0xFF868996),
    divider: Color(0xFFE5E5EA),
    outline: Color(0xFFAEAEB2),
    primary: Color(0xFF007AFF),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE5F1FF),
    onPrimaryContainer: Color(0xFF004FA6),
    income: Color(0xFF1B9A58),
    incomeSoft: Color(0xFFE6F7EE),
    expense: Color(0xFFE5352B),
    expenseSoft: Color(0xFFFEECEB),
    warning: Color(0xFFDC7E00),
    warningSoft: Color(0xFFFFF3E0),
    chart: [
      Color(0xFF007AFF),
      Color(0xFF1B9A58),
      Color(0xFF5856D6),
      Color(0xFFFF9500),
      Color(0xFFFF2D55),
      Color(0xFF8E8E93),
    ],
    isDark: false,
  );

  static const AppColors dark = AppColors(
    page: Color(0xFF090A0F),
    card: Color(0xFF171820),
    block: Color(0xFF232530),
    inset: Color(0xFF303341),
    text: Color(0xFFF5F5F7),
    text2: Color(0xFFA0A4B2),
    text3: Color(0xFF6E7280),
    divider: Color(0xFF262834),
    outline: Color(0xFF636776),
    primary: Color(0xFF3A9BFF),
    onPrimary: Color(0xFF081226),
    primaryContainer: Color(0xFF142A48),
    onPrimaryContainer: Color(0xFFD6EAFF),
    income: Color(0xFF30D158),
    incomeSoft: Color(0xFF102E1D),
    expense: Color(0xFFFF453A),
    expenseSoft: Color(0xFF351819),
    warning: Color(0xFFFF9F0A),
    warningSoft: Color(0xFF33230E),
    chart: [
      Color(0xFF3A9BFF),
      Color(0xFF30D158),
      Color(0xFF7D7AFF),
      Color(0xFFFF9F0A),
      Color(0xFFFF375F),
      Color(0xFF98989D),
    ],
    isDark: true,
  );

  static const AppColors darkPureBlack = AppColors(
    page: Color(0xFF000000),
    card: Color(0xFF14151B),
    block: Color(0xFF20222B),
    inset: Color(0xFF2D303B),
    text: Color(0xFFF5F5F7),
    text2: Color(0xFFA5A9B8),
    text3: Color(0xFF747888),
    divider: Color(0xFF22242E),
    outline: Color(0xFF686D7D),
    primary: Color(0xFF3A9BFF),
    onPrimary: Color(0xFF081226),
    primaryContainer: Color(0xFF142A48),
    onPrimaryContainer: Color(0xFFD6EAFF),
    income: Color(0xFF30D158),
    incomeSoft: Color(0xFF102E1D),
    expense: Color(0xFFFF453A),
    expenseSoft: Color(0xFF351819),
    warning: Color(0xFFFF9F0A),
    warningSoft: Color(0xFF33230E),
    chart: [
      Color(0xFF3A9BFF),
      Color(0xFF30D158),
      Color(0xFF7D7AFF),
      Color(0xFFFF9F0A),
      Color(0xFFFF375F),
      Color(0xFF98989D),
    ],
    isDark: true,
  );
}

/// 内置几何数字与英文品牌字族（拉丁与数字走 Outfit，中文自动回退系统字体）。
const String kDisplayFont = 'Outfit';

/// 内容层主卡：不透明语义表面、轻微色调过渡与柔和层级阴影。
ShapeDecoration studioHeroDecoration(
  AppColors colors, {
  double radius = Radii.hero,
}) {
  final borderColor = colors.cardBorder;
  final shape = Radii.shape(radius)
      .copyWith(side: BorderSide(color: borderColor, width: 0.8));
  return ShapeDecoration(
    shape: shape,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors.isDark
          ? [colors.heroHighlight, colors.heroBase]
          : [colors.card, colors.heroBase],
    ),
    shadows: colors.isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0A1633).withValues(alpha: 0.048),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF0A1633).withValues(alpha: 0.022),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
  );
}

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// 连续曲率同心超椭圆圆角刻度。
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double hero = 26;
  static const double alert = 28;
  static const double card = 22;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(alert),
  );

  static const RoundedSuperellipseBorder cardShape = RoundedSuperellipseBorder(
    borderRadius: cardRadius,
  );
  static const RoundedSuperellipseBorder pillShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(pill)),
  );

  static final Map<double, RoundedSuperellipseBorder> _shapeCache = {
    card: cardShape,
    pill: pillShape,
  };

  static RoundedSuperellipseBorder shape(double radius) {
    if (radius == card) return cardShape;
    if (radius == pill) return pillShape;
    return _shapeCache.putIfAbsent(
      radius,
      () => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
    );
  }
}

/// 微排版刻度。
///
/// 卡片里曾经出现过 8.5 / 9 / 9.5 / 10 / 10.5 / 11.5 六种「按像素挤出来」的
/// 字号：每处单独看都合理，放在一起就没有节奏，而且 8.5pt 在手机上已经低于
/// 可读下限。这里只保留五档，卡片内的角标、单位、说明统一从这里取。
abstract final class TypeScale {
  /// 角标 / 图例 / 单位。低于这个值的正文不要出现。
  static const double micro = 11;

  /// 次级说明（卡片底部的元信息）。
  static const double caption = 12;

  /// 标签、胶囊按钮。
  static const double label = 13;

  /// 卡片标题。
  static const double title = 15;

  /// 正文强调 / 双栏指标金额。
  static const double body = 17;

  /// 区块标题。
  static const double section = 20;

  /// 中型指标数字。
  static const double metric = 24;

  /// 首屏主数字。
  static const double display = 32;
}

/// 间距（4pt 刻度）。
abstract final class Gaps {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 卡片之间的呼吸间距。
  static const double cardGap = 10;

  /// 页面左右内边距。
  static const double page = 16;

  /// 主页面标题栏高度（不含状态栏）。
  static const double headerHeight = 54;
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
      BoxShadow(color: Color(0x0C0A1633), blurRadius: 22, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x060A1633), blurRadius: 4, offset: Offset(0, 1)),
    ],
    floatingShadows: [
      BoxShadow(
        color: Color(0x1F0A1633),
        blurRadius: 30,
        offset: Offset(0, 14),
      ),
      BoxShadow(color: Color(0x0B0A1633), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  static const AppTokens darkTokens = AppTokens(
    colors: AppColors.dark,
    shadows: [
      BoxShadow(color: Color(0x36000000), blurRadius: 18, offset: Offset(0, 6)),
    ],
    floatingShadows: [
      BoxShadow(
        color: Color(0x5A000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x28000000), blurRadius: 5, offset: Offset(0, 2)),
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

/// 页面滚动内容的底部留白：让内容延伸到悬浮液态玻璃底栏之下产生折射，
/// 同时滚到底部时最后一张卡片能完全越过底栏。
double pageBottomInset(BuildContext context) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  final system = MediaQuery.paddingOf(context).bottom;
  if (keyboard > 0) {
    final keyboardInset = keyboard + 24;
    final safeInset = system + 24;
    return keyboardInset > safeInset ? keyboardInset : safeInset;
  }
  final wide = MediaQuery.sizeOf(context).width >= 720;
  return wide ? system + 28 : system + 124;
}

/// 构建 ThemeData。
ThemeData buildAppTheme(
  AppColors colors,
  AppTokens tokens, {
  String? fontFamily,
}) {
  final fallbackFonts = <String>[
    if (fontFamily != null &&
        fontFamily.isNotEmpty &&
        fontFamily != kDisplayFont)
      fontFamily,
  ];
  final base = ThemeData(
    brightness: colors.isDark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    platform: TargetPlatform.iOS,
    fontFamily: kDisplayFont,
    fontFamilyFallback: fallbackFonts.isEmpty ? null : fallbackFonts,
    scaffoldBackgroundColor: colors.page,
    canvasColor: colors.page,
    splashFactory: LiquidInkHighlight.splashFactory,
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
      letterSpacing: 0,
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
      letterSpacing: 0,
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
    fontFamily: kDisplayFont,
    fontFamilyFallback: fallbackFonts.isEmpty ? null : fallbackFonts,
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
            : (colors.isDark ? colors.text2 : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.block;
        }
        return states.contains(WidgetState.selected)
            ? colors.primary
            : colors.inset;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.cardBorder,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: WidgetStatePropertyAll(
        colors.primary.withValues(alpha: 0.10),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.inset,
      thumbColor: colors.primary,
      overlayColor: colors.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
      backgroundColor: colors.isDark
          ? const Color(0xF0252732)
          : const Color(0xEB1C1C1E),
      contentTextStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(18, 0, 18, 88),
      shape: Radii.shape(18).copyWith(
        side: BorderSide(
          color: Colors.white.withValues(alpha: colors.isDark ? 0.12 : 0.10),
          width: 0.75,
        ),
      ),
    ),
  );
}
