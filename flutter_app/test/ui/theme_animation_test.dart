import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('主题切换不触发整页渐变过渡', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWithValue(settings)],
        child: MyHoursApp(settings: settings),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, Duration.zero);
  });
}
