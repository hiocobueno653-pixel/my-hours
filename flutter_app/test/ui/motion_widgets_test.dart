import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/measure_unit.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/dates.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/features/charts/charts.dart';
import 'package:my_hours/features/mine/custom_color_sheet.dart';
import 'package:my_hours/features/work/month_view.dart';
import 'package:my_hours/state/app_controller.dart';
import 'package:my_hours/ui/pinned_header.dart';
import 'package:my_hours/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('RollingDigitsText 逐位滚轮切换并在关闭动效时退化为单文本', (tester) async {
    final semantics = tester.ensureSemantics();
    const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);

    await tester.pumpWidget(
      _wrap(const RollingDigitsText(text: '01:23', style: style)),
    );
    expect(find.byType(AnimatedSwitcher), findsNWidgets(4));
    expect(
      tester.getSemantics(find.byType(RollingDigitsText)).label,
      '01:23',
    );

    await tester.pumpWidget(
      _wrap(const RollingDigitsText(text: '01:24', style: style)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(RollingDigitsText)).label,
      '01:24',
    );

    await tester.pumpWidget(
      _wrap(
        const RollingDigitsText(text: '01:24', style: style),
        disableAnimations: true,
      ),
    );
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.text('01:24'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('UndoBar 渲染倒计时进度条，关闭动效时隐藏进度动画并响应撤销', (tester) async {
    var undone = 0;
    await tester.pumpWidget(
      _wrap(
        UndoBar(
          message: '已删除 餐饮 ¥28',
          seconds: 2,
          onUndo: () => undone += 1,
        ),
      ),
    );
    expect(find.byType(FractionallySizedBox), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    final midBar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(midBar.widthFactor, lessThan(0.95));
    expect(midBar.widthFactor, greaterThan(0.05));

    await tester.tap(find.text('撤销'));
    await tester.pump();
    expect(undone, 1);

    await tester.pumpWidget(
      _wrap(
        UndoBar(
          message: '已删除 餐饮 ¥28',
          seconds: 2,
          onUndo: () {},
        ),
        disableAnimations: true,
      ),
    );
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets('三类图表在数据与选中项更新时可平滑收敛', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarPairChart(
              labels: const ['1', '2', '3'],
              seriesA: const [10, 20, 15],
              seriesB: const [4, 8, 6],
              colorA: AppColors.light.income,
              colorB: AppColors.light.expense,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
            DonutChart(
              values: const [30, 70],
              colors: [AppColors.light.primary, AppColors.light.income],
              labels: const ['A', 'B'],
              centerLabel: '合计',
              centerValue: '¥100',
            ),
            TrendChart(
              values: const [4, 8, 6],
              labels: const ['1月', '2月', '3月'],
              color: AppColors.light.primary,
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarPairChart(
              labels: const ['1', '2', '3'],
              seriesA: const [18, 12, 24],
              seriesB: const [6, 5, 11],
              colorA: AppColors.light.income,
              colorB: AppColors.light.expense,
              selectedIndex: 2,
              onSelected: (_) {},
            ),
            DonutChart(
              values: const [60, 40],
              colors: [AppColors.light.primary, AppColors.light.income],
              labels: const ['A', 'B'],
              centerLabel: '合计',
              centerValue: '¥200',
            ),
            TrendChart(
              values: const [9, 5, 12],
              labels: const ['1月', '2月', '3月'],
              color: AppColors.light.primary,
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('¥200'), findsOneWidget);
  });

  test('默认蓝 #007AFF 的主色文字为纯白，且自定义色板支持增删改与重置', () async {
    final lightBlue = AppColors.light.withAccent(
      AppSettings.defaultAccentColor,
      isDark: false,
      style: AppColorStyle.vivid,
    );
    expect(lightBlue.onPrimary, Colors.white);

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.isDefaultThemeColor, isTrue);

    const coral = Color(0xFFFF5A5F);
    const teal = Color(0xFF0D9488);
    await settings.addAccentColor(coral);
    expect(settings.accentColor.toARGB32(), coral.toARGB32());
    expect(settings.isDefaultThemeColor, isFalse);
    expect(
      settings.accentPalette.any((c) => c.toARGB32() == coral.toARGB32()),
      isTrue,
    );

    await settings.editAccentColor(coral, teal);
    expect(settings.accentColor.toARGB32(), teal.toARGB32());
    expect(
      settings.accentPalette.any((c) => c.toARGB32() == teal.toARGB32()),
      isTrue,
    );

    await settings.removeAccentColor(teal);
    expect(
      settings.accentPalette.any((c) => c.toARGB32() == teal.toARGB32()),
      isFalse,
    );

    await settings.resetThemeColors();
    expect(settings.isDefaultThemeColor, isTrue);
    expect(
      settings.accentColor.toARGB32(),
      AppSettings.defaultAccentColor.toARGB32(),
    );
  });

  testWidgets('三模式自定义取色面板支持网格、光谱、滑块切换与 HEX 预览', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Color? confirmed;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showCustomColorSheet(
              context,
              initialColor: const Color(0xFF007AFF),
              colorStyle: AppColorStyle.vivid,
              pureBlack: false,
              floatingDock: true,
              onConfirmed: (c) => confirmed = c,
            ),
            child: const Text('打开取色'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开取色'));
    await tester.pumpAndSettle();
    expect(find.text('自定义主题色'), findsOneWidget);
    expect(find.text('网格'), findsOneWidget);
    expect(find.text('光谱'), findsOneWidget);
    expect(find.text('滑块'), findsOneWidget);
    expect(find.text('HEX 色值'), findsOneWidget);

    await tester.tap(find.text('光谱'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('滑块'));
    await tester.pumpAndSettle();
    expect(find.text('色相'), findsOneWidget);
    expect(find.text('饱和度'), findsOneWidget);
    expect(find.text('明度'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(confirmed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页左上角标题随计量单位变化，长按可弹出单位菜单并切换；未来月显示未来月份提示', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final dir = Directory.systemTemp.createTempSync('my_hours_unit_header_');
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
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MeasureUnitScope(
            unit: settings.measureUnit,
            child: MaterialApp(
              theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
              home: const Scaffold(body: MonthView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('工时'), findsOneWidget);

    await tester.longPress(find.text('工时'));
    await tester.pumpAndSettle();
    expect(find.text('切换计量单位'), findsOneWidget);
    await tester.tap(find.text('学时（学时）'));
    await tester.pumpAndSettle();

    expect(settings.measureUnit.id, MeasureUnit.schoolHours.id);
    expect(
      find.descendant(
        of: find.byType(PinnedHeader),
        matching: find.text('学时'),
      ),
      findsOneWidget,
    );

    final futureMonth = shiftMonth(currentMonthKey(), 2);
    container.read(selectedMonthProvider.notifier).setMonth(futureMonth);
    await tester.pumpAndSettle();
    expect(find.textContaining('未来月份'), findsOneWidget);
  });
}
