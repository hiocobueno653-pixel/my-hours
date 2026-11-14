import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/features/work/month_view.dart';

void main() {
  testWidgets('点修改记录只触发一次，不会叠出两个详情弹窗', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: TodayCard(
                date: '2026-11-12',
                record: const WorkDayRecord(date: '2026-11-12', hours: 8),
                profiles: const [],
                income: 0,
                expense: 0,
                entryCount: 0,
                onOpenLedger: null,
                onTap: () => taps += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('修改记录'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
