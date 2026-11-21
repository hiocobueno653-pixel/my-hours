import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/app.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/state/app_controller.dart';

/// 键盘弹出时页面与底部 Dock 都不该被顶上去。
void main() {
  testWidgets('键盘弹出时 body 不压缩，底部 Dock 停在原位', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('my_hours_shell_');
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
          home: AppShell(hoursOnly: false, largeText: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, isFalse);

    final dock = find.byKey(const ValueKey('app-dock'));
    expect(dock, findsOneWidget);
    final before = tester.getBottomLeft(dock).dy;

    // 键盘高度 900 物理像素 = 300 逻辑像素。
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.getBottomLeft(dock).dy, before);
  });
}
