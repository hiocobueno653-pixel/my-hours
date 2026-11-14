import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/dates.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/features/work/month_view.dart';

void main() {
  testWidgets('窄屏大字模式下今日卡片不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TodayCard(
                date: todayISO(),
                record: const WorkDayRecord(
                  date: '2026-11-14',
                  hours: 24,
                  fixedPay: 999999999.99,
                  remark: '一个很长很长的备注，用来检查窄屏下的布局',
                ),
                profiles: const [
                  WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 99),
                ],
                income: 999999999.99,
                expense: 999999999.99,
                entryCount: 999,
                onOpenLedger: () {},
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TodayCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
