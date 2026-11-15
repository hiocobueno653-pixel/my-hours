import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首次欢迎标记默认未完成，写入后可持久化读取', () async {
    SharedPreferences.setMockInitialValues({});

    final settings = await AppSettings.load();
    expect(settings.welcomeSeen, isFalse);
    expect(settings.brandWelcomeSeen, isFalse);

    await settings.setWelcomeSeen();
    expect(settings.welcomeSeen, isTrue);
    expect(settings.brandWelcomeSeen, isTrue);

    final reloaded = await AppSettings.load();
    expect(reloaded.welcomeSeen, isTrue);
    expect(reloaded.brandWelcomeSeen, isTrue);
  });

  test('主题色、玻璃、底栏、选项卡与文本缩放可持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    await settings.setAccentColor(const Color(0xFF8B5CF6));
    await settings.setColorStyle(AppColorStyle.soft);
    await settings.setPureBlack(true);
    await settings.setDockStyle(AppDockStyle.fixed);
    await settings.setTabTransition(AppTabTransition.fade);
    await settings.setGlassPreference(AppGlassPreference.extreme);
    await settings.setFollowSystemText(false);
    await settings.setCustomTextScale(1.2);

    final reloaded = await AppSettings.load();
    expect(reloaded.accentColor, const Color(0xFF8B5CF6));
    expect(reloaded.colorStyle, AppColorStyle.soft);
    expect(reloaded.pureBlack, isTrue);
    expect(reloaded.dockStyle, AppDockStyle.fixed);
    expect(reloaded.tabTransition, AppTabTransition.fade);
    expect(reloaded.glassPreference, AppGlassPreference.extreme);
    expect(reloaded.textScale, 1.2);
  });
}
