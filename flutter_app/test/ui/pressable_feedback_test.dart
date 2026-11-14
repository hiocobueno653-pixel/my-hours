import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/ui/widgets.dart';

void main() {
  testWidgets('可按压面向无障碍服务暴露可点击动作', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Pressable(
            onTap: () => taps += 1,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('保存'),
            ),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.text('保存'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('保存'));
    await tester.pump();
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('滚动起手不震动，真正点击才震动一次', (tester) async {
    final haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: Pressable(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('保存'),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('保存')),
    );
    await tester.pump();
    expect(haptics, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(haptics, hasLength(1));
  });
}
