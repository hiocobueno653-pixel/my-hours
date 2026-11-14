import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/features/mine/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('设置开关点击后立即反映新状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWithValue(settings)],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              onBack: () {},
              largeText: settings.largeText,
              onLargeTextChanged: settings.setLargeText,
            ),
          ),
        ),
      ),
    );

    final switches = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(switches.first).value, isFalse);
    expect(tester.widget<SwitchListTile>(switches.last).value, isFalse);

    await tester.tap(find.text('大字模式'));
    await tester.pump();
    expect(settings.largeText, isTrue);
    expect(tester.widget<SwitchListTile>(switches.first).value, isTrue);

    await tester.tap(find.text('减少动效'));
    await tester.pump();
    expect(settings.reduceMotion, isTrue);
    expect(tester.widget<SwitchListTile>(switches.last).value, isTrue);
  });
}
