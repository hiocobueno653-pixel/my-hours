import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/features/charts/charts.dart';

void main() {
  testWidgets('柱状图点击按月份槽位回调，短序列也不会越界', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: BarPairChart(
                labels: const ['1', '2', '3'],
                seriesA: const [12],
                seriesB: const [8],
                colorA: AppColors.light.income,
                colorB: AppColors.light.expense,
                selectedIndex: 0,
                onSelected: (index) => selected = index,
              ),
            ),
          ),
        ),
      ),
    );

    final chart = find.byType(BarPairChart);
    final topLeft = tester.getTopLeft(chart);
    await tester.tapAt(topLeft + const Offset(12, 48));
    await tester.pump();
    expect(selected, 0);

    await tester.tapAt(topLeft + const Offset(140, 48));
    await tester.pump();
    expect(selected, 1);
  });
}
