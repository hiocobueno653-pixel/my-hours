import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluid_glass/fluid_glass.dart';
import 'package:my_hours/core/motion_origin.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/ui/dialog.dart';

void main() {
  testWidgets('确认弹窗点击空白只关闭一层', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConfirmDialog(
                context,
                title: '测试弹窗',
                description: '点击空白关闭',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('测试弹窗'), findsOneWidget);
    expect(find.byType(LiquidButton), findsNWidgets(2));
    final scrim = find.byKey(const ValueKey('dialog-scrim'));
    expect(scrim, findsOneWidget);
    final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getRect(scrim), Offset.zero & logicalSize);
    expect(
      find.ancestor(of: scrim, matching: find.byType(BackdropFilter)),
      findsNothing,
    );

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('测试弹窗'), findsNothing);
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('窄屏下弹窗不横向溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConfirmDialog(
                context,
                title: '这是一个较长的弹窗标题',
                description: '说明文字会换行显示，按钮也应该保持在屏幕内。',
                confirmLabel: '确认',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('这是一个较长的弹窗标题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹窗从最近按压点附近生长，并按原路收回', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConfirmDialog(
                context,
                title: '来源测试',
                description: '应该从左上角附近出现。',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    MotionOrigin.record(const Offset(20, 20));
    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final entering = tester.getRect(find.text('来源测试'));
    expect(entering.center.dx, lessThan(200));

    MotionOrigin.record(const Offset(20, 20));
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final leaving = tester.getRect(find.text('来源测试'));
    expect(leaving.center.dx, lessThan(200));
  });
}
