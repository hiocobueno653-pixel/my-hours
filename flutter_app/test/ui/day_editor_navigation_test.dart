import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/features/work/month_view.dart';
import 'package:my_hours/data/dates.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/state/app_controller.dart';

void main() {
  testWidgets('日编辑可用日期箭头切换，且今天不能切到未来', (tester) async {
    final dir = Directory.systemTemp.createTempSync('my_hours_day_editor_');
    final container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(LocalStore(dir))],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final today = todayISO();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
          home: Scaffold(body: DayEditorSheet(date: today)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(formatDateLabel(today)), findsOneWidget);
    expect(container.read(selectedMonthProvider), today.substring(0, 7));

    await tester.tap(find.byTooltip('后一天'));
    await tester.pump();
    expect(find.text(formatDateLabel(today)), findsOneWidget);

    await tester.tap(find.byTooltip('前一天'));
    await tester.pumpAndSettle();
    final previous = shiftDate(today, -1);
    expect(find.text(formatDateLabel(previous)), findsOneWidget);
    expect(container.read(selectedMonthProvider), previous.substring(0, 7));
  });
}
