import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/dates.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/features/work/month_view.dart';
import 'package:my_hours/state/app_controller.dart';

/// 记工页的时间语境：只有当前月才渲染「今天」工作区。
void main() {
  testWidgets('日历左右滑动后新旧月份交叉滑入', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('my_hours_month_swipe_');
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
          home: const Scaffold(body: MonthView()),
        ),
      ),
    );
    await tester.pump();

    final startMonth = container.read(selectedMonthProvider);
    final calendar = find.byType(GridView).first;
    await tester.ensureVisible(calendar);
    await tester.pumpAndSettle();

    await tester.drag(calendar, const Offset(-240, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(container.read(selectedMonthProvider), shiftMonth(startMonth, 1));
    expect(find.byType(GridView), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('切到历史月份后不再渲染今天卡片，并给出回本月入口', (tester) async {
    final dir = Directory.systemTemp.createTempSync('my_hours_month_view_');
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
          home: const Scaffold(body: MonthView()),
        ),
      ),
    );
    await tester.pump();

    // 默认停在本月：今天卡片在场。
    expect(find.byType(TodayCard), findsOneWidget);
    expect(find.text('回到本月'), findsNothing);

    container
        .read(selectedMonthProvider.notifier)
        .setMonth(shiftMonth(currentMonthKey(), -1));
    await tester.pump();

    // 历史月份：今天卡片消失，替换为可点的回本月提示。
    expect(find.byType(TodayCard), findsNothing);
    expect(find.text('回到本月'), findsOneWidget);
  });
}
