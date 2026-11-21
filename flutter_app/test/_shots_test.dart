// 本地视觉回归工具：把真实页面渲染成 PNG，供人眼评审。
//
// 只在设置 CAPTURE_SHOTS=1 时运行，CI 默认跳过（跑 `flutter test` 不会执行抓图）。
// 用法：
//   CAPTURE_SHOTS=1 flutter test test/_shots_test.dart
// 产物：flutter_app/shots/*.png（已在 .gitignore 之外，评审后删除）
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/app.dart';
import 'package:my_hours/core/settings.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/constants.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/features/mine/backup_page.dart';
import 'package:my_hours/features/mine/custom_color_sheet.dart';
import 'package:my_hours/features/mine/settings_page.dart';
import 'package:my_hours/features/mine/theme_page.dart';
import 'package:my_hours/features/onboarding/welcome_screen.dart';
import 'package:my_hours/state/app_controller.dart';
import 'package:my_hours/ui/glass_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _family = 'CaptureSans';
const String _shotKey = 'shot-root';

bool get _enabled => Platform.environment['CAPTURE_SHOTS'] == '1';

Future<ByteData> _readFont(String path) async {
  final bytes = File(path).readAsBytesSync();
  return ByteData.view(bytes.buffer);
}

Future<void> _loadFonts() async {
  final outfitLoader = FontLoader(kDisplayFont);
  for (final path in const [
    'assets/fonts/Outfit-Regular.ttf',
    'assets/fonts/Outfit-Medium.ttf',
    'assets/fonts/Outfit-SemiBold.ttf',
    'assets/fonts/Outfit-Bold.ttf',
  ]) {
    if (File(path).existsSync()) {
      outfitLoader.addFont(_readFont(path));
    }
  }
  await outfitLoader.load();

  final loader = FontLoader(_family);
  if (File('C:/Windows/Fonts/NotoSansSC-VF.ttf').existsSync()) {
    loader.addFont(_readFont('C:/Windows/Fonts/NotoSansSC-VF.ttf'));
  } else if (File('C:/Windows/Fonts/Deng.ttf').existsSync()) {
    loader.addFont(_readFont('C:/Windows/Fonts/Deng.ttf'));
    if (File('C:/Windows/Fonts/Dengb.ttf').existsSync()) {
      loader.addFont(_readFont('C:/Windows/Fonts/Dengb.ttf'));
    }
  }
  await loader.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final iconCandidates = <String>[
    if (flutterRoot != null && flutterRoot.isNotEmpty)
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'E:/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in iconCandidates) {
    if (File(path).existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      iconLoader.addFont(_readFont(path));
      await iconLoader.load();
      break;
    }
  }
}

String _pad(int v) => v.toString().padLeft(2, '0');

void _seed(ProviderContainer container) {
  final controller = container.read(appControllerProvider.notifier);
  // 种子一律落在「当前月」，否则几个月后跑出来的截图是历史月份（没有
  // 今日 Bento），评审时会被误读成布局坏了。
  final now = DateTime.now();
  final prefix = '${now.year}-${_pad(now.month)}';
  String day(int value) => '$prefix-${_pad(value)}';
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  bool valid(int value) => value <= lastDay;
  controller.saveWorkProfile(
    const WorkProfile(id: defaultWorkId, name: '工地', hourlyRate: 32),
  );
  controller.saveWorkProfile(
    const WorkProfile(id: 'w2', name: '家教', hourlyRate: 90),
  );
  // 整月填满（周日休息）：只有前半个月有数据时，日历下半月会成片空白，
  // 评审容易把「没数据」误读成「留白失控」。
  final hours = <int, double>{};
  for (var d = 1; d <= 28; d++) {
    if (!valid(d)) continue;
    final weekday = DateTime(now.year, now.month, d).weekday;
    if (weekday == DateTime.sunday && d != now.day) continue;
    hours[d] = weekday == DateTime.saturday ? 4 : 8;
  }
  hours[9] = 9.5; // 加班
  hours[15] = 5.5; // 今天
  const remarks = <int, String>{4: '收尾，提前走', 9: '加班两小时', 13: '半天'};
  hours.forEach((date, value) {
    if (!valid(date)) return;
    controller.saveDay(
      day(date),
      value,
      remarks[date] ?? '',
      workId: date.isEven ? defaultWorkId : 'w2',
    );
  });
  // 已结算的前半段，让工资面板与日历有分层数据。
  for (final value in [2, 3, 4, 5]) {
    if (valid(value)) controller.setRecordSettled(day(value), true);
  }
  const entries = <(int, LedgerType, double, String, String)>[
    (3, LedgerType.expense, 28, '餐饮', '午饭'),
    (5, LedgerType.expense, 12, '交通', '地铁'),
    (6, LedgerType.income, 500, '其他', '朋友还款'),
    (8, LedgerType.expense, 268, '购物', '工作鞋'),
    (11, LedgerType.expense, 45, '餐饮', '聚餐 AA'),
    (12, LedgerType.expense, 120, '居家', '生活用品'),
    (14, LedgerType.expense, 32, '餐饮', '外卖'),
    (15, LedgerType.income, 180, '其他', '闲置转卖'),
  ];
  for (final (value, type, amount, category, remark) in entries) {
    if (!valid(value)) continue;
    controller.saveLedgerEntry(
      LedgerEntry(
        id: 'seed-$value-$category',
        date: day(value),
        type: type,
        amount: amount,
        category: category,
        remark: remark,
      ),
    );
  }
  controller.saveBudgetTargets(
    const BudgetTargets(monthlyExpenseBudget: 1200, monthlyIncomeGoal: 6000),
  );
}

Widget _app({required Widget child, required bool dark}) {
  final colors = dark ? AppColors.dark : AppColors.light;
  final tokens = dark ? AppTokens.darkTokens : AppTokens.lightTokens;
  final theme = buildAppTheme(colors, tokens, fontFamily: _family);
  return RepaintBoundary(
    key: const ValueKey(_shotKey),
    child: LiquidGlassTheme(
      colors: dark
          ? LiquidGlassColors.dark.copyWith(
              accent: colors.primary,
              toggleAccent: colors.primary,
              content: colors.text,
              track: const Color(0xFF3E4150),
            )
          : LiquidGlassColors.light.copyWith(
              accent: colors.primary,
              toggleAccent: colors.primary,
              content: colors.text,
              track: const Color(0xFFD6DCE6),
            ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, widget) => DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: kDisplayFont,
            fontFamilyFallback: [_family],
          ),
          child: widget ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  // RevealOnMount 最晚 80ms 才开始，再跑 200ms；多给一帧余量，
  // 否则右侧两张月卡会停在 opacity 0，被误读成布局缺卡。
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey(_shotKey)),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('shots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<ProviderContainer> _boot(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await AppSettings.load();
  final dir = Directory.systemTemp.createTempSync('my_hours_shot_');
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
  if (Platform.environment['CAPTURE_SEED'] != '0') {
    _seed(container);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _app(child: child, dark: dark),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  test('视觉抓图工具（默认跳过）', () {}, skip: true);
  if (!_enabled) return;

  setUpAll(_loadFonts);

  setUp(() {
    // 低于默认值，避免 golden 风格的不稳定断言
  });

  testWidgets('记工页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, const AppShell(hoursOnly: false, largeText: false));
    await _capture(tester, 'work-light');
  });

  testWidgets('记工页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(
      tester,
      const AppShell(hoursOnly: false, largeText: false),
      dark: true,
    );
    await _capture(tester, 'work-dark');
  });

  testWidgets('记账页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, const AppShell(hoursOnly: false, largeText: false));
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('app-dock')), matching: find.text('账本')).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'ledger-light');
  });

  testWidgets('记账页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(
      tester,
      const AppShell(hoursOnly: false, largeText: false),
      dark: true,
    );
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('app-dock')), matching: find.text('账本')).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'ledger-dark');
  });

  testWidgets('统计页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, const AppShell(hoursOnly: false, largeText: false));
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('app-dock')), matching: find.text('统计')).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'stats-light');
  });

  testWidgets('统计页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(
      tester,
      const AppShell(hoursOnly: false, largeText: false),
      dark: true,
    );
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('app-dock')), matching: find.text('统计')).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'stats-dark');
  });

  testWidgets('我的页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, const AppShell(hoursOnly: false, largeText: false));
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('app-dock')), matching: find.text('我的')).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'mine-light');
  });

  testWidgets('我的页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(
      tester,
      const AppShell(hoursOnly: false, largeText: false),
      dark: true,
    );
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('app-dock')), matching: find.text('我的')).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'mine-dark');
  });

  testWidgets('设置页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, SettingsPage(onBack: () {}));
    await _capture(tester, 'settings-light');
  });

  testWidgets('设置页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, SettingsPage(onBack: () {}), dark: true);
    await _capture(tester, 'settings-dark');
  });

  testWidgets('主题页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, ThemePage(onBack: () {}));
    await _capture(tester, 'theme-light');
  });

  testWidgets('主题页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, ThemePage(onBack: () {}), dark: true);
    await _capture(tester, 'theme-dark');
  });

  testWidgets('备份页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, BackupPage(onBack: () {}));
    await _capture(tester, 'backup-light');
  });

  testWidgets('日记录编辑弹窗 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, const AppShell(hoursOnly: false, largeText: false));
    await tester.tap(find.text('编辑').first);
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, 'day-editor-light');
  });

  testWidgets('欢迎页 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, WelcomeScreen(onStart: () async {}));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(WelcomeScreen));
      await precacheImage(const AssetImage('assets/brand/app_icon.png'), ctx);
      await precacheImage(const AssetImage('assets/brand/wordmark.png'), ctx);
    });
    await tester.pumpAndSettle();
    await _capture(tester, 'welcome-light');
  });

  testWidgets('欢迎页 · 暗色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, WelcomeScreen(onStart: () async {}), dark: true);
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(WelcomeScreen));
      await precacheImage(const AssetImage('assets/brand/app_icon.png'), ctx);
      await precacheImage(
        const AssetImage('assets/brand/wordmark_dark.png'),
        ctx,
      );
    });
    await tester.pumpAndSettle();
    await _capture(tester, 'welcome-dark');
  });

  testWidgets('自定义主题色滑块 · 亮色', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, ThemePage(onBack: () {}));
    final ctx = tester.element(find.byType(ThemePage));
    unawaited(
      showCustomColorSheet(
      ctx,
      initialColor: AppColors.light.primary,
      colorStyle: AppColorStyle.vivid,
      pureBlack: false,
      floatingDock: true,
      onConfirmed: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('滑块'));
    await tester.pumpAndSettle();
    await _capture(tester, 'color-sliders-light');
  });

  testWidgets('液态水滴形变动效关键帧', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _boot(tester, ThemePage(onBack: () {}));
    final ctx = tester.element(find.byType(ThemePage));
    unawaited(
      showDropletGlassMenu(
      ctx,
      anchorRect: const Rect.fromLTWH(286, 360, 74, 34),
      panelWidth: 162,
      preferRightAlign: true,
      items: [
        GlassMenuAction(label: '鲜明', selected: true, onSelected: () {}),
        GlassMenuAction(label: '氛围', onSelected: () {}),
        GlassMenuAction(label: '柔和', onSelected: () {}),
        GlassMenuAction(label: '单色', onSelected: () {}),
      ],
      ),
    );
    Future<void> snapAt(String name, int ms) async {
      await tester.pump(Duration(milliseconds: ms));
      final boundary =
          tester.renderObject(find.byKey(const ValueKey(_shotKey)))
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('shots/$name.png').writeAsBytesSync(bytes!);
    }

    await snapAt('droplet-1', 45);
    await snapAt('droplet-2', 65);
    await snapAt('droplet-3', 65);
    await snapAt('droplet-4', 320);
  });
}
