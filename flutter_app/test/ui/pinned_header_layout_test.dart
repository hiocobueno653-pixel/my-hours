import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/ui/pinned_header.dart';
import 'package:my_hours/ui/widgets.dart';

void main() {
  testWidgets('窄屏大字模式顶栏不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.2),
          ),
          child: Scaffold(
            body: PinnedHeader(
              title: '记工',
              actions: [
                const SizedBox(width: 174, height: 44),
                GlassIconButton(
                  icon: Icons.download_rounded,
                  onTap: () {},
                  tooltip: '导出',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('记工'), findsOneWidget);
  });
}
