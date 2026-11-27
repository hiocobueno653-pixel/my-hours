import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/dates.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/features/work/month_view.dart';
import 'package:my_hours/features/work/work_bento_header.dart';
import 'package:my_hours/state/app_controller.dart';
import 'package:my_hours/state/timer_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记工页的时间语境：只有当前月才渲染「今天」工作区。
void main() {
  for (final scenario in [
    (from: '2021-02', to: '2021-03', rows: 1, swipe: -240.0),
    (from: '2021-03', to: '2021-02', rows: -1, swipe: 240.0),
    (from: '2021-04', to: '2021-05', rows: 1, swipe: -240.0),
    (from: '2021-05', to: '2021-04', rows: -1, swipe: 240.0),
  ]) {
    testWidgets('日历 ${scenario.from} → ${scenario.to} 只改变可见高度', (tester) async {
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
      container.read(selectedMonthProvider.notifier).setMonth(scenario.from);

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

      final calendar = find.byKey(ValueKey('calendar-grid-${scenario.from}'));
      await tester.ensureVisible(find.text('本月日历'));
      await tester.pumpAndSettle();
      final gridHeight = tester.getSize(calendar).height;
      final legend = find.text('左右滑动切月 · 长按快记');
      final previousLegendOffset =
          tester.getTopLeft(legend).dy - tester.getTopLeft(calendar).dy;

      await tester.dragFrom(
        tester.getTopLeft(calendar) + const Offset(300, 32),
        Offset(scenario.swipe, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(container.read(selectedMonthProvider), scenario.to);
      expect(find.byType(GridView), findsNWidgets(2));
      final legendOffset =
          tester.getTopLeft(legend).dy - tester.getTopLeft(calendar).dy;
      expect(
        (legendOffset - previousLegendOffset) * scenario.rows,
        greaterThan(0),
      );
      expect(tester.getSize(calendar).height, gridHeight);

      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.getSize(find.byType(GridView)).height, gridHeight);
      final nextCalendar = find.byKey(ValueKey('calendar-grid-${scenario.to}'));
      final nextLegendOffset =
          tester.getTopLeft(legend).dy - tester.getTopLeft(nextCalendar).dy;
      expect(
        nextLegendOffset - previousLegendOffset,
        closeTo(scenario.rows * 48.0, 0.01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('开始计时时卡片高度平滑过渡，暂停后主读数可恢复', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final dir = Directory.systemTemp.createTempSync('my_hours_timer_motion_');
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(LocalStore(dir)),
        settingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      settings.dispose();
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
    await tester.pumpAndSettle();

    final todayCard = find.byKey(const ValueKey('today-bento-card'));
    final initialHeight = tester.getSize(todayCard).height;
    await tester.tap(find.bySemanticsLabel('开始计时'));
    expect(container.read(timerProvider)?.running, isTrue);

    // 读数区换成计时器后，旧文案先淡出，卡片高度随后才收拢：
    // 采样整段过渡，确认是逐帧插值而不是一帧瞬跳。
    final heights = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      heights.add(tester.getSize(todayCard).height);
    }
    final settledHeight = heights.last;
    expect(settledHeight, lessThan(initialHeight));
    expect(
      heights.any((height) => height < initialHeight && height > settledHeight),
      isTrue,
      reason: '卡片高度应逐帧收拢，而不是一次性跳变',
    );

    container.read(timerProvider.notifier).pause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(container.read(timerProvider)?.running, isFalse);
    expect(find.text('已暂停'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

    // 默认停在本月：今日 Bento 概览在场。
    expect(find.byType(WorkBentoHeader), findsOneWidget);
    expect(find.text('回到本月'), findsNothing);

    container
        .read(selectedMonthProvider.notifier)
        .setMonth(shiftMonth(currentMonthKey(), -1));
    await tester.pump();

    // 历史月份：Bento 结构保留（月工时 / 月工资仍在），只有「今天」卡片
    // 让位给可点的回本月提示——这样切月份时上半屏不会整块消失。
    expect(find.byType(WorkBentoHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('today-bento-card')), findsNothing);
    expect(find.text('回到本月'), findsOneWidget);
  });

  testWidgets('Bento 快捷工时会写回今天记录', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('my_hours_quick_');
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

    await tester.tap(find.text('+1h'));
    await tester.pump();
    expect(container.read(appControllerProvider).records.single.hours, 1);

    await tester.tap(find.text('8h'));
    await tester.pump();
    expect(container.read(appControllerProvider).records.single.hours, 8);
    container.read(appControllerProvider.notifier).flushPendingPersist();
    await tester.pump();
  });
}
