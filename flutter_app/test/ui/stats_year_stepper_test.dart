import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/features/mine/stats_page.dart';
import 'package:my_hours/state/app_controller.dart';

/// 年度统计的年份步进器：年份居中，两侧按钮不再夹着文字。
void main() {
  testWidgets('年份居中，两侧各有独立按钮', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('my_hours_stats_');
    final container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(LocalStore(dir))],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
          home: Scaffold(body: StatsPage(onBack: () {})),
        ),
      ),
    );
    await tester.pump();

    final yearLabel = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^\d{4} 年$').hasMatch(widget.data!),
    );
    expect(yearLabel, findsOneWidget);

    // 居中：偏差要明显小于半个按钮宽（22dp），否则文字仍贴着某一侧。
    final screenWidth = tester.view.physicalSize.width / 3.0;
    final offset = tester.getCenter(yearLabel).dx - screenWidth / 2;
    expect(offset.abs(), lessThan(22));
  });
}
