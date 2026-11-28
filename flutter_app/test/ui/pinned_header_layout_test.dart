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

  testWidgets('顶栏标题随主内容滚动收紧，并始终保留标题语义', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: PrimaryScrollController(
          controller: scroll,
          child: Scaffold(
            body: Stack(
              children: [
                ListView(children: const [SizedBox(height: 1400)]),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PinnedHeader(title: '工时'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Text title() => tester.widget<Text>(find.text('工时'));
    final expandedSize = title().style!.fontSize!;
    expect(
      tester.getSemantics(find.text('工时')),
      containsSemantics(isHeader: true, label: '工时'),
    );

    await tester.dragFrom(const Offset(195, 420), const Offset(0, -90));
    await tester.pump();

    expect(title().style!.fontSize, lessThan(expandedSize));
    expect(scroll.offset, greaterThan(0));
  });
}
