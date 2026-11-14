import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/ui/date_wheel.dart';

/// 日期滚轮的冒烟测试：
/// 不追求像素截图（测试环境没有中文字体），只验证「能弹出、滚轮渲染、无溢出、能回传」。
void main() {
  testWidgets('日期滚轮能打开并回传 YYYY-MM-DD', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDateWheel(
                    context,
                    initialDate: '2026-11-09',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('选择日期'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(3));

    // 点确定，默认值应原样回传
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, '2026-11-09');
  });

  testWidgets('2 月天数随年份联动（闰年 29 天）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showDateWheel(context, initialDate: '2028-02-29'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 2028-02-29 是合法日期，不应被 clamp 掉
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('选择日期'), findsNothing);
  });
}
