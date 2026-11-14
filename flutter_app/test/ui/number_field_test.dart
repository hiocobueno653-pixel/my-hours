import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/ui/widgets.dart';

void main() {
  testWidgets('数字输入最多保留两位小数，并拒绝多个小数点', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(body: NumberField(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(TextField), '12.34');
    await tester.pump();
    expect(controller.text, '12.34');

    await tester.enterText(find.byType(TextField), '12.345');
    await tester.pump();
    expect(controller.text, '12.34');

    await tester.enterText(find.byType(TextField), '1.2.3');
    await tester.pump();
    expect(controller.text, '12.34');
  });
}
