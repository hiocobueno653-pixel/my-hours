/// 应用设置：主题模式、大字模式、动效开关。
///
/// 只存 UI 偏好，不进备份文档（备份 v4 契约里没有设置字段，加了就破坏兼容）。
library;

import 'measure_unit.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_layout.dart';
import 'theme_tokens.dart';

enum AppDockStyle { floating, fixed }

enum AppTabTransition { slide, fade }

enum AppGlassPreference { none, standard, extreme }

/// 由 `main.dart` 覆盖为真实实例。
final settingsProvider = Provider<AppSettings>(
  (ref) => throw StateError('settingsProvider 必须在 ProviderScope 中覆盖'),
);

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const _kTheme = 'my-hours.theme';
  static const _kLargeText = 'my-hours.largeText';
  static const _kReduceMotion = 'my-hours.reduceMotion';
  static const _kWelcomeSeen = 'my-hours.welcomeSeen';
  static const _kBrandWelcomeSeen = 'my-hours.brandWelcomeSeen';
  static const _kAccent = 'my-hours.accent';
  static const _kAccentPalette = 'my-hours.accentPalette';
  static const _kPureBlack = 'my-hours.pureBlack';
  static const _kColorStyle = 'my-hours.colorStyle';
  static const _kDockStyle = 'my-hours.dockStyle';
  static const _kTabTransition = 'my-hours.tabTransition';
  static const _kGlassPreference = 'my-hours.glassPreference';
  static const _kFontFamily = 'my-hours.fontFamily';
  static const _kCustomTextScale = 'my-hours.customTextScale';
  static const _kFollowSystemText = 'my-hours.followSystemText';
  static const _kUnit = 'my-hours.unit';
  static const _kTimer = 'my-hours.timer';
  static const _kDashboardCards = 'my-hours.dashboardCards';

  static const Color defaultAccentColor = Color(0xFF1E5BFF);

  static const List<Color> defaultAccentPalette = [
    Color(0xFF1E5BFF),
    Color(0xFFE5484D),
    Color(0xFF0E9F6E),
    Color(0xFF6E56CF),
    Color(0xFFD97706),
    Color(0xFF334155),
  ];

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  /// 正在进行的计时（JSON）。进程被杀后靠它恢复。
  String? get timerSnapshot => _prefs.getString(_kTimer);

  Future<void> setTimerSnapshot(String? raw) async {
    if (raw == null) {
      await _prefs.remove(_kTimer);
    } else {
      await _prefs.setString(_kTimer, raw);
    }
  }

  /// 计量单位：工时 / 学时 / 次数 / 章 / 页 / 公里。
  ///
  /// 只影响显示，不动数据：`WorkDayRecord.hours` 仍然是一个 double。
  MeasureUnit get measureUnit => MeasureUnit.byId(_prefs.getString(_kUnit));

  Future<void> setMeasureUnit(MeasureUnit unit) async {
    await _prefs.setString(_kUnit, unit.id);
    notifyListeners();
  }

  /// 首页月汇总卡的顺序；今日概览和日历固定，不在此列表。
  List<String> get dashboardCards => DashboardCardIds.sanitize(
    _prefs.getStringList(_kDashboardCards) ?? DashboardCardIds.defaults,
  );

  Future<void> setDashboardCards(List<String> cards) async {
    await _prefs.setStringList(
      _kDashboardCards,
      DashboardCardIds.sanitize(cards),
    );
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_prefs.getString(_kTheme)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'auto',
    };
    await _prefs.setString(_kTheme, value);
    notifyListeners();
  }

  bool get largeText => _prefs.getBool(_kLargeText) ?? false;

  Future<void> setLargeText(bool value) async {
    await _prefs.setBool(_kLargeText, value);
    notifyListeners();
  }

  bool get reduceMotion => _prefs.getBool(_kReduceMotion) ?? false;

  Future<void> setReduceMotion(bool value) async {
    await _prefs.setBool(_kReduceMotion, value);
    notifyListeners();
  }

  Color get accentColor {
    final raw = _prefs.getString(_kAccent);
    final hex = raw?.replaceFirst('#', '');
    if (hex != null && hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return defaultAccentColor;
  }

  Future<void> setAccentColor(Color color) async {
    await _prefs.setString(_kAccent, _encodeHex(color));
    notifyListeners();
  }

  /// 主题页展示的色板（包含用户新增与编辑过的自定义色）。
  List<Color> get accentPalette {
    final stored = _prefs.getStringList(_kAccentPalette);
    if (stored == null || stored.isEmpty) {
      final current = accentColor;
      final hasCurrent = defaultAccentPalette.any(
        (item) => item.toARGB32() == current.toARGB32(),
      );
      return hasCurrent
          ? List<Color>.of(defaultAccentPalette)
          : [...defaultAccentPalette, current];
    }
    final parsed = <Color>[];
    final seen = <int>{};
    for (final raw in stored) {
      final color = _decodeHex(raw);
      if (color != null && seen.add(color.toARGB32())) {
        parsed.add(color);
      }
    }
    return parsed.isEmpty ? List<Color>.of(defaultAccentPalette) : parsed;
  }

  bool get isDefaultThemeColor {
    if (accentColor.toARGB32() != defaultAccentColor.toARGB32()) return false;
    if (colorStyle != AppColorStyle.vivid) return false;
    final current = accentPalette;
    if (current.length != defaultAccentPalette.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].toARGB32() != defaultAccentPalette[i].toARGB32()) {
        return false;
      }
    }
    return true;
  }

  Future<void> addAccentColor(Color color) async {
    final next = List<Color>.of(accentPalette);
    final rgb = color.toARGB32() | 0xFF000000;
    final normalized = Color(rgb);
    if (!next.any((item) => item.toARGB32() == rgb)) {
      next.add(normalized);
    }
    await _prefs.setStringList(
      _kAccentPalette,
      [for (final item in next) _encodeHex(item)],
    );
    await _prefs.setString(_kAccent, _encodeHex(normalized));
    notifyListeners();
  }

  Future<void> editAccentColor(Color oldColor, Color newColor) async {
    final oldRgb = oldColor.toARGB32() | 0xFF000000;
    final newRgb = newColor.toARGB32() | 0xFF000000;
    final normalized = Color(newRgb);
    final next = List<Color>.of(accentPalette);
    final index = next.indexWhere((item) => item.toARGB32() == oldRgb);
    if (index == -1) {
      await addAccentColor(normalized);
      return;
    }
    if (oldRgb == newRgb) return;
    if (next.any((item) => item.toARGB32() == newRgb)) {
      next.removeAt(index);
    } else {
      next[index] = normalized;
    }
    await _prefs.setStringList(
      _kAccentPalette,
      [for (final item in next) _encodeHex(item)],
    );
    if (accentColor.toARGB32() == oldRgb) {
      await _prefs.setString(_kAccent, _encodeHex(normalized));
    }
    notifyListeners();
  }

  Future<void> removeAccentColor(Color color) async {
    final rgb = color.toARGB32() | 0xFF000000;
    final next = List<Color>.of(accentPalette)
      ..removeWhere((item) => item.toARGB32() == rgb);
    if (next.isEmpty) return;
    await _prefs.setStringList(
      _kAccentPalette,
      [for (final item in next) _encodeHex(item)],
    );
    if (accentColor.toARGB32() == rgb) {
      final fallback = next.any(
        (item) => item.toARGB32() == defaultAccentColor.toARGB32(),
      )
          ? defaultAccentColor
          : next.first;
      await _prefs.setString(_kAccent, _encodeHex(fallback));
    }
    notifyListeners();
  }

  Future<void> resetThemeColors() async {
    await _prefs.remove(_kAccentPalette);
    await _prefs.setString(_kAccent, _encodeHex(defaultAccentColor));
    await _prefs.setString(_kColorStyle, 'vivid');
    notifyListeners();
  }

  static String _encodeHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color? _decodeHex(String raw) {
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  bool get pureBlack => _prefs.getBool(_kPureBlack) ?? false;

  Future<void> setPureBlack(bool value) async {
    await _prefs.setBool(_kPureBlack, value);
    notifyListeners();
  }

  AppColorStyle get colorStyle {
    return switch (_prefs.getString(_kColorStyle)) {
      'atmospheric' => AppColorStyle.atmospheric,
      'soft' => AppColorStyle.soft,
      'monochrome' => AppColorStyle.monochrome,
      _ => AppColorStyle.vivid,
    };
  }

  Future<void> setColorStyle(AppColorStyle value) async {
    final stored = switch (value) {
      AppColorStyle.vivid => 'vivid',
      AppColorStyle.atmospheric => 'atmospheric',
      AppColorStyle.soft => 'soft',
      AppColorStyle.monochrome => 'monochrome',
    };
    await _prefs.setString(_kColorStyle, stored);
    notifyListeners();
  }

  AppDockStyle get dockStyle {
    return _prefs.getString(_kDockStyle) == 'fixed'
        ? AppDockStyle.fixed
        : AppDockStyle.floating;
  }

  Future<void> setDockStyle(AppDockStyle value) async {
    await _prefs.setString(
      _kDockStyle,
      value == AppDockStyle.fixed ? 'fixed' : 'floating',
    );
    notifyListeners();
  }

  AppTabTransition get tabTransition {
    return _prefs.getString(_kTabTransition) == 'fade'
        ? AppTabTransition.fade
        : AppTabTransition.slide;
  }

  Future<void> setTabTransition(AppTabTransition value) async {
    await _prefs.setString(
      _kTabTransition,
      value == AppTabTransition.fade ? 'fade' : 'slide',
    );
    notifyListeners();
  }

  AppGlassPreference get glassPreference {
    return switch (_prefs.getString(_kGlassPreference)) {
      'none' => AppGlassPreference.none,
      'extreme' => AppGlassPreference.extreme,
      _ => AppGlassPreference.standard,
    };
  }

  Future<void> setGlassPreference(AppGlassPreference value) async {
    final stored = switch (value) {
      AppGlassPreference.none => 'none',
      AppGlassPreference.standard => 'standard',
      AppGlassPreference.extreme => 'extreme',
    };
    await _prefs.setString(_kGlassPreference, stored);
    notifyListeners();
  }

  /// 应用内字体族。空字符串/null 表示跟随系统默认字体。
  String get fontFamily => _prefs.getString(_kFontFamily) ?? '';

  Future<void> setFontFamily(String value) async {
    if (value.isEmpty) {
      await _prefs.remove(_kFontFamily);
    } else {
      await _prefs.setString(_kFontFamily, value);
    }
    notifyListeners();
  }

  bool get followSystemText => _prefs.getBool(_kFollowSystemText) ?? true;

  Future<void> setFollowSystemText(bool value) async {
    await _prefs.setBool(_kFollowSystemText, value);
    notifyListeners();
  }

  double get customTextScale =>
      (_prefs.getDouble(_kCustomTextScale) ?? 1.0).clamp(0.9, 1.3).toDouble();

  Future<void> setCustomTextScale(double value) async {
    await _prefs.setDouble(_kCustomTextScale, value.clamp(0.9, 1.3).toDouble());
    notifyListeners();
  }

  /// 首次欢迎页只出现一次；之后启动直接进入记工主页。
  bool get welcomeSeen => _prefs.getBool(_kWelcomeSeen) ?? false;

  /// 品牌改版后的欢迎页单独记一次，保证老用户升级后也能看到新品牌首屏。
  bool get brandWelcomeSeen => _prefs.getBool(_kBrandWelcomeSeen) ?? false;

  Future<void> setWelcomeSeen() async {
    final changed = !welcomeSeen || !brandWelcomeSeen;
    if (!welcomeSeen) await _prefs.setBool(_kWelcomeSeen, true);
    if (!brandWelcomeSeen) await _prefs.setBool(_kBrandWelcomeSeen, true);
    if (changed) notifyListeners();
  }

  /// 大字模式对应的文本缩放（对齐旧版 `.large-text` 的 1.12 倍）。
  double get textScale {
    if (largeText) return 1.12;
    if (followSystemText) return 1.0;
    return customTextScale;
  }
}
