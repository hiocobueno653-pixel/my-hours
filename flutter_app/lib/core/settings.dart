/// 应用设置：主题模式、大字模式、动效开关。
///
/// 只存 UI 偏好，不进备份文档（备份 v4 契约里没有设置字段，加了就破坏兼容）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
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
  double get textScale => largeText ? 1.12 : 1.0;
}
