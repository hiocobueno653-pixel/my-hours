import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/features/onboarding/welcome_screen.dart';

void main() {
  testWidgets('欢迎页展示三段功能并可开始使用', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onStart: () async {
            starts++;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('记录时间，记下生活。'), findsOneWidget);
    expect(find.text('把工时、工资与每一笔收支，留在属于你的时间页。'), findsOneWidget);
    expect(find.text('本周预览'), findsOneWidget);
    expect(find.text('本地离线'), findsOneWidget);
    expect(find.text('日工时预设'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('开始使用'));
    await tester.pump();
    expect(starts, 1);
  });

  testWidgets('小屏下欢迎页可滚动且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onStart: () async {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('开始使用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字模式下欢迎页不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
          ),
          child: WelcomeScreen(onStart: () async {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('开始使用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开始使用失败时给出可重试提示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onStart: () async => throw StateError('write failed'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    await tester.tap(find.text('开始使用'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('暂时无法保存，请再试一次'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
  });
}
