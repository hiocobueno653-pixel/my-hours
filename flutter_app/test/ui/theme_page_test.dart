import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/features/mine/theme_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('主题页展示预览与各分区，并且小屏不溢出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final colors = AppColors.light.withAccent(
      settings.accentColor,
      isDark: false,
      style: settings.colorStyle,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(
            colors,
            AppTokens.lightTokens.copyWith(colors: colors),
          ),
          home: Scaffold(
            backgroundColor: colors.page,
            body: ThemePage(onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('主题色彩'), findsOneWidget);
    expect(find.text('纯黑模式'), findsOneWidget);
    expect(find.text('选项卡动画'), findsOneWidget);
    expect(find.text('字体与阅读'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
