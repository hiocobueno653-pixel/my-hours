import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../core/theme_tokens.dart';
import '../../state/app_controller.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import '../../ui/dialog.dart';
import 'theme_page.dart';

/// 使用设置：深色模式、大字、动效、清空数据。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    required this.onBack,
    required this.largeText,
    required this.onLargeTextChanged,
  });

  final VoidCallback onBack;
  final bool largeText;
  final ValueChanged<bool> onLargeTextChanged;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final colors = context.colors;
        return Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.only(
                  top: PinnedSubHeader.totalHeight(context) + 8,
                  bottom: 40,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: Gaps.xs,
                          ),
                          child: ListRow(
                            title: '主题与外观',
                            subtitle: '主题模式、主题色、液态玻璃与文本缩放',
                            leading: Icon(
                              Icons.palette_outlined,
                              color: colors.text2,
                            ),
                            showChevron: true,
                            onTap: () => _openTheme(context),
                          ),
                        ),
                        const SizedBox(height: Gaps.md),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: Gaps.xs,
                          ),
                          child: Column(
                            children: [
                              Material(
                                type: MaterialType.transparency,
                                child: SwitchListTile(
                                  value: settings.largeText,
                                  onChanged: settings.setLargeText,
                                  title: const Text('大字模式'),
                                  subtitle: const Text('整体字号放大约 12%'),
                                ),
                              ),
                              Divider(height: 1, color: colors.divider),
                              Material(
                                type: MaterialType.transparency,
                                child: SwitchListTile(
                                  value: settings.reduceMotion,
                                  onChanged: (value) =>
                                      settings.setReduceMotion(value),
                                  title: const Text('减少动效'),
                                  subtitle: const Text('折叠空间动画，并降低玻璃折射'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.md),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: Gaps.xs,
                          ),
                          child: ListRow(
                            title: '清空全部数据',
                            subtitle: '工时、账目、分类、工作与预算全部删除，不可恢复',
                            danger: true,
                            onTap: () async {
                              final confirmed = await showConfirmDialog(
                                context,
                                title: '清空全部数据？',
                                description: '将删除全部工时与账目，并重置应用。\n建议先导出备份。',
                                confirmLabel: '清空',
                                danger: true,
                              );
                              if (confirmed != true) return;
                              if (!context.mounted) return;
                              final cleared = ref
                                  .read(appControllerProvider.notifier)
                                  .clearAll();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      cleared
                                          ? '已清空全部数据'
                                          : '本地文件已清空，但新存档写入失败，请重试',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: Gaps.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/brand/app_icon.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '时页 TIMEPAGE · 1.7.1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '数据全部保存在本机，无账号、无后端。',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.text3,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gaps.xxl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedSubHeader(title: '使用设置', onBack: widget.onBack),
            ),
          ],
        );
      },
    );
  }

  void _openTheme(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          backgroundColor: routeContext.colors.page,
          body: SafeArea(
            top: false,
            child: ThemePage(onBack: () => Navigator.of(routeContext).pop()),
          ),
        ),
      ),
    );
  }
}
