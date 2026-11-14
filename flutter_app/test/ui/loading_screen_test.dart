import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/features/onboarding/loading_screen.dart';
import 'package:my_hours/features/onboarding/timepage_loader.dart';

void main() {
  testWidgets('品牌加载页展示 TIMEPAGE 动画与 Slogan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: const TimepageLoadingScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(TimepageLoader), findsOneWidget);
    expect(find.text('记录时间，记下生活。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动效时加载页保持静态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: TimepageLoadingScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TimepageLoader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
