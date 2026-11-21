/// 设计令牌：FlClash 液态玻璃（Liquid Glass & Soft Surface）视觉系统。
///
/// 冷灰呼吸画布、高洁净度大连续圆角卡片、电光钴蓝鲜明主色与真实液态玻璃折射。
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

  /// 轻盈描边：暗色纯黑与玻璃浮层上提供微弱轮廓，亮色卡片靠面差呼吸。
  Color get cardBorder =>
      isDark ? const Color(0xFF253046) : const Color(0xFFE2E8F2);

  /// 英雄卡片深空基底色：随当前主题强调色微妙偏移，始终与品牌光感统一。
  Color get heroBase => Color.lerp(
    isDark ? const Color(0xFF121A2B) : const Color(0xFF0C1324),
    primary,
    isDark ? 0.16 : 0.14,
  )!;

  /// 英雄卡片高光端色。
  Color get heroHighlight => Color.lerp(
    isDark ? const Color(0xFF182540) : const Color(0xFF152342),
    primary,
    isDark ? 0.28 : 0.26,
  )!;

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
    final onPrimary =
        (whiteContrast >= 4.0 || whiteContrast >= darkInkContrast)
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
          page = Color.lerp(
            base.page,
            Colors.white,
            isDark ? 0.03 : 0.16,
          )!;
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
    page: Color(0xFFF3F5FA),
    card: Color(0xFFFFFFFF),
    block: Color(0xFFEAEFF7),
    inset: Color(0xFFDDE4F0),
    text: Color(0xFF0F172A),
    text2: Color(0xFF526077),
    text3: Color(0xFF8A96AB),
    divider: Color(0xFFE6ECF4),
    outline: Color(0xFF9EABC0),
    primary: Color(0xFF1E5BFF),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE8F0FF),
    onPrimaryContainer: Color(0xFF123DB3),
    income: Color(0xFF0E8A5F),
    incomeSoft: Color(0xFFE5F6EF),
    expense: Color(0xFFDC3F35),
    expenseSoft: Color(0xFFFDECEB),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFEF3E2),
    chart: [
      Color(0xFF1E5BFF),
      Color(0xFF0E9F6E),
      Color(0xFF6E56CF),
      Color(0xFFD97706),
      Color(0xFFE5484D),
      Color(0xFF64748B),
    ],
    isDark: false,
  );

  static const AppColors dark = AppColors(
    page: Color(0xFF0A0E17),
    card: Color(0xFF131926),
    block: Color(0xFF1C2436),
    inset: Color(0xFF263147),
    text: Color(0xFFF1F5FB),
    text2: Color(0xFF9BA8BF),
    text3: Color(0xFF66758F),
    divider: Color(0xFF20293B),
    outline: Color(0xFF5D6C86),
    primary: Color(0xFF5C93FF),
    onPrimary: Color(0xFF061326),
    primaryContainer: Color(0xFF182F58),
    onPrimaryContainer: Color(0xFFD6E8FF),
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF0F352A),
    expense: Color(0xFFF87171),
    expenseSoft: Color(0xFF3F1D23),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3B2C13),
    chart: [
      Color(0xFF5C93FF),
      Color(0xFF34D399),
      Color(0xFFA78BFA),
      Color(0xFFFBBF24),
      Color(0xFFF87171),
      Color(0xFF94A3B8),
    ],
    isDark: true,
  );

  static const AppColors darkPureBlack = AppColors(
    page: Color(0xFF000000),
    card: Color(0xFF10141E),
    block: Color(0xFF1A202E),
    inset: Color(0xFF262E40),
    text: Color(0xFFF4F7FC),
    text2: Color(0xFFA9B6CC),
    text3: Color(0xFF74849E),
    divider: Color(0xFF1D2433),
    outline: Color(0xFF677690),
    primary: Color(0xFF5C93FF),
    onPrimary: Color(0xFF061326),
    primaryContainer: Color(0xFF182F58),
    onPrimaryContainer: Color(0xFFD6E8FF),
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF0F352A),
    expense: Color(0xFFF87171),
    expenseSoft: Color(0xFF3F1D23),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3B2C13),
    chart: [
      Color(0xFF5C93FF),
      Color(0xFF34D399),
      Color(0xFFA78BFA),
      Color(0xFFFBBF24),
      Color(0xFFF87171),
      Color(0xFF94A3B8),
    ],
    isDark: true,
  );
}

/// 内置几何数字与英文品牌字族（拉丁与数字走 Outfit，中文自动回退系统字体）。
const String kDisplayFont = 'Outfit';

/// 深空琉璃英雄卡统一装饰：深邃蓝曜渐变 + 顶部微光描边 + 柔和景深阴影。
ShapeDecoration studioHeroDecoration(
  AppColors colors, {
  double radius = Radii.hero,
}) {
  final shape = Radii.shape(radius).copyWith(
    side: BorderSide(
      color: Colors.white.withValues(alpha: colors.isDark ? 0.12 : 0.16),
      width: 0.9,
    ),
  );
  final shadowTint = Color.lerp(
    const Color(0xFF0B1222),
    colors.primary,
    0.32,
  )!;
  return ShapeDecoration(
    shape: shape,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors.heroHighlight, colors.heroBase],
    ),
    shadows: [
      BoxShadow(
        color: shadowTint.withValues(alpha: colors.isDark ? 0.45 : 0.22),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: shadowTint.withValues(alpha: colors.isDark ? 0.24 : 0.08),
        blurRadius: 4,
        offset: const Offset(0, 2),
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

/// FlClash 风格连续曲率超椭圆圆角刻度。
abstract final class Radii {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double hero = 20;
  static const double alert = 22;
  static const double card = 18;
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
      BoxShadow(
        color: Color(0x0A0F172A),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x050F172A),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
    floatingShadows: [
      BoxShadow(
        color: Color(0x1A0F172A),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 5, offset: Offset(0, 2)),
    ],
  );

  static const AppTokens darkTokens = AppTokens(
    colors: AppColors.dark,
    shadows: [
      BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    floatingShadows: [
      BoxShadow(
        color: Color(0x48000000),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
      BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1)),
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
    if (fontFamily != null && fontFamily.isNotEmpty && fontFamily != kDisplayFont)
      fontFamily,
  ];
  final base = ThemeData(
    brightness: colors.isDark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
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
      trackColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.block;
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.inset;
        },
      ),
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
      backgroundColor: colors.isDark ? colors.block : const Color(0xE6141416),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: Radii.shape(Radii.md),
    ),
  );
}
