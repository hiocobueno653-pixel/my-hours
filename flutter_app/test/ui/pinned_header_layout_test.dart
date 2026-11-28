import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/ui/glass_menu.dart';
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

  testWidgets('月份与操作共享顶栏材质且保留44dp触控区', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var month = '2026-11';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PinnedHeader(
              title: '工时',
              actions: [
                GlassActionGroup(
                  height: 46,
                  children: [
                    MonthSwitchPill(
                      month: month,
                      embedded: true,
                      onChanged: (value) => setState(() => month = value),
                      onPick: () {},
                    ),
                    GlassGroupIconAction(
                      icon: Icons.search_rounded,
                      tooltip: '搜索',
                      onTap: () {},
                    ),
                    GlassMenuButton(clustered: true, items: const []),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previousMonth = find.bySemanticsLabel('上个月');
    expect(tester.getSize(previousMonth).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(previousMonth).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSize(find.byTooltip('搜索')).width,
      greaterThanOrEqualTo(44),
    );
    expect(find.byType(GlassActionGroup), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(previousMonth);
    await tester.pumpAndSettle();
    expect(month, '2026-10');
  });
}
