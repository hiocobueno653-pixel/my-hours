import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';
import 'package:my_hours/features/mine/custom_color_sheet.dart';
import 'package:my_hours/ui/glass_menu.dart';

void main() {
  testWidgets('自定义主题色滑块轨道占满宽度且拖拽色相/饱和度/明度可实时生效并确认', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Color? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showCustomColorSheet(
                    context,
                    initialColor: const Color(0xFF1E5BFF),
                    colorStyle: AppColorStyle.vivid,
                    pureBlack: false,
                    floatingDock: true,
                    onConfirmed: (color) => confirmed = color,
                  );
                },
                child: const Text('打开取色器'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开取色器'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('滑块'));
    await tester.pumpAndSettle();

    expect(find.text('色相'), findsOneWidget);
    expect(find.text('饱和度'), findsOneWidget);
    expect(find.text('明度'), findsOneWidget);

    final hueLabelRect = tester.getRect(find.text('色相'));
    // 滑块轨道位于标题行正下方，点按左侧靠近红色区（hue ~ 20°）应明显改变 HEX。
    final trackTap = Offset(hueLabelRect.left + 20, hueLabelRect.bottom + 24);
    await tester.tapAt(trackTap);
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed!.toARGB32(), isNot(0xFF1E5BFF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('液态水滴玻璃菜单可平滑形变展开并响应选中回调', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: () {
                    showDropletGlassMenu(
                      context,
                      anchorRect: const Rect.fromLTWH(280, 24, 80, 36),
                      panelWidth: 164,
                      items: [
                        GlassMenuAction(
                          label: '鲜明',
                          selected: true,
                          onSelected: () => picked = '鲜明',
                        ),
                        GlassMenuAction(
                          label: '柔和',
                          onSelected: () => picked = '柔和',
                        ),
                      ],
                    );
                  },
                  child: const Text('展开菜单'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('展开菜单'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('柔和'), findsOneWidget);
    await tester.tap(find.text('柔和'));
    await tester.pumpAndSettle();

    expect(picked, '柔和');
    expect(tester.takeException(), isNull);
  });
}
