import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/app.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/constants.dart';
import 'package:my_hours/data/dates.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/features/mine/backup_page.dart';
import 'package:my_hours/features/mine/my_view.dart';
import 'package:my_hours/features/mine/settings_page.dart';
import 'package:my_hours/features/mine/theme_page.dart';
import 'package:my_hours/features/work/month_view.dart';
import 'package:my_hours/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('四标签导航可切换工时、账本、统计、我的；纯工时模式隐藏账本', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('my_hours_nav_full_');
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
          home: const AppShell(hoursOnly: false, largeText: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dock = find.byKey(const ValueKey('app-dock'));
    expect(
      find.descendant(of: dock, matching: find.text('工时')),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(of: dock, matching: find.text('账本')),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(of: dock, matching: find.text('统计')),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(of: dock, matching: find.text('我的')),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(
      find.descendant(of: dock, matching: find.text('账本')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('本月结余'), findsOneWidget);

    await tester.tap(
      find.descendant(of: dock, matching: find.text('统计')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('全年工时'), findsOneWidget);

    await tester.tap(
      find.descendant(of: dock, matching: find.text('我的')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('记工与账务'), findsOneWidget);

    final hoursDir = Directory.systemTemp.createTempSync('my_hours_nav_only_');
    final hoursContainer = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(LocalStore(hoursDir))],
    );
    addTearDown(hoursContainer.dispose);
    addTearDown(() {
      if (hoursDir.existsSync()) hoursDir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: hoursContainer,
        child: MaterialApp(
          theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
          home: const AppShell(hoursOnly: true, largeText: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hoursDock = find.byKey(const ValueKey('app-dock'));
    expect(
      find.descendant(of: hoursDock, matching: find.text('账本')),
      findsNothing,
    );
    expect(
      find.descendant(of: hoursDock, matching: find.text('统计')),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('点选日历日期先更新行内摘要卡片，今天工作区展示生效时薪', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('my_hours_sel_day_');
    final container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(LocalStore(dir))],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final month = currentMonthKey();
    final parts = month.split('-');
    final targetDay = DateTime.now().day == 2 ? 3 : 2;
    final targetDate = '$month-${targetDay.toString().padLeft(2, '0')}';
    container
        .read(appControllerProvider.notifier)
        .saveWorkProfile(
          const WorkProfile(id: defaultWorkId, name: '兼职家教', hourlyRate: 90),
        );
    container
        .read(appControllerProvider.notifier)
        .saveDay(targetDate, 6, '数学辅导');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
          home: const Scaffold(body: MonthView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('兼职家教 · ¥90/时'),
      kHoursOnly ? findsNothing : findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('$targetDay日'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('${int.parse(parts[1])}月$targetDay日'),
      findsOneWidget,
    );
    expect(find.text('数学辅导'), findsOneWidget);
    expect(
      find.text(kHoursOnly ? '6 小时 · 兼职家教' : '6 小时 · ¥540 · 兼职家教'),
      findsOneWidget,
    );
    container.read(appControllerProvider.notifier).flushPendingPersist();
  });

  testWidgets('我的页推入二级子页具备 Scaffold 背景与 Material 祖先，无黑底黄线', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final dir = Directory.systemTemp.createTempSync('my_hours_subpage_');
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(LocalStore(dir)),
        settingsProvider.overrideWithValue(settings),
      ],
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
          home: const Scaffold(body: MyView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> verifySubpage(
      String rowLabel,
      Type pageType,
      String titleText,
    ) async {
      await tester.dragUntilVisible(
        find.text(rowLabel),
        find.byType(ListView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(rowLabel));
      await tester.pumpAndSettle();

      final pageFinder = find.byType(pageType);
      expect(pageFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: pageFinder, matching: find.byType(Scaffold)),
      );
      expect(scaffold.backgroundColor, AppColors.light.page);

      final titleElement = tester.element(
        find.descendant(of: pageFinder, matching: find.text(titleText)).first,
      );
      expect(Material.maybeOf(titleElement), isNotNull);
      expect(
        DefaultTextStyle.of(titleElement).style.decoration,
        isNot(TextDecoration.underline),
      );

      await tester.tap(
        find.descendant(of: pageFinder, matching: find.byTooltip('返回')),
      );
      await tester.pumpAndSettle();
    }

    await verifySubpage('使用设置', SettingsPage, '使用设置');
    await verifySubpage('主题与外观', ThemePage, '主题');
    await verifySubpage('数据与备份', BackupPage, '数据与备份');
  });
}
