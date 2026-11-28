import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/ui/sheet.dart';

void main() {
  testWidgets('遮罩原地渐暗，不跟随底部弹层上移', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) =>
                      const SheetScaffold(title: '遮罩测试', child: Text('正文')),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final scrim = find.byKey(const ValueKey('sheet-scrim'));
    expect(scrim, findsOneWidget);
    expect(tester.getRect(scrim), const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('干净的底部 sheet 可以从标题处下拉关闭', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) =>
                      const SheetScaffold(title: '测试弹层', child: Text('弹层正文')),
                ),
                child: const Text('打开弹层'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开弹层'));
    await tester.pumpAndSettle();
    expect(find.text('测试弹层'), findsOneWidget);

    await tester.drag(find.text('测试弹层'), const Offset(0, 140));
    await tester.pumpAndSettle();
    expect(find.text('测试弹层'), findsNothing);
  });

  testWidgets('点遮罩关闭有未保存内容的 sheet 时先确认', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) => SheetScaffold(
                    title: '编辑弹层',
                    guard: () => true,
                    child: const Text('未保存内容'),
                  ),
                ),
                child: const Text('打开编辑弹层'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开编辑弹层'));
    await tester.pumpAndSettle();
    expect(find.text('编辑弹层'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('编辑弹层'), findsOneWidget);
  });

  testWidgets('Sheet 关闭键保留 44dp 触控区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) =>
                      const SheetScaffold(title: '触控测试', child: Text('正文')),
                ),
                child: const Text('打开触控弹层'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开触控弹层'));
    await tester.pumpAndSettle();

    final close = find.byKey(const ValueKey('sheet-close-button'));
    expect(tester.getSize(close).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
  });

  testWidgets('固定操作区在键盘上方保持可见', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) => SheetScaffold(
                    title: '底栏测试',
                    footer: const Text('固定操作'),
                    child: const SizedBox(height: 1200),
                  ),
                ),
                child: const Text('打开底栏弹层'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开底栏弹层'));
    await tester.pumpAndSettle();

    final footer = find.byKey(const ValueKey('sheet-footer'));
    expect(footer, findsOneWidget);
    expect(tester.getBottomLeft(footer).dy, lessThanOrEqualTo(500));
  });
}
