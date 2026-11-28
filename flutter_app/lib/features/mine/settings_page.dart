import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../core/theme_tokens.dart';
import '../../data/dates.dart';
import '../../state/app_controller.dart';
import '../../state/timer_controller.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import '../../ui/dialog.dart';
import '../../core/measure_unit.dart';
import '../../ui/sheet.dart';
import '../../state/live_update_capability.dart';

/// 使用设置：深色模式、大字、动效、清空数据。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(liveUpdateCapabilityProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(liveUpdateCapabilityProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final colors = context.colors;
        final liveUpdate = ref.watch(liveUpdateCapabilityProvider);
        final canOpenNotificationSettings = liveUpdate.maybeWhen(
          data: (cap) => cap.sdkInt > 0,
          orElse: () => false,
        );
        final bottomSafe = MediaQuery.paddingOf(context).bottom;
        return Scaffold(
          backgroundColor: colors.page,
          body: AppPageBackground(
            child: LiquidBackdropScaffold(
              body: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  top: PinnedSubHeader.totalHeight(context) + 12,
                  bottom: bottomSafe + 28,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(title: '记录与通知'),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              ListRow(
                                title: '计量单位',
                                subtitle:
                                    '决定「${context.unit.quantity}」与短单位显示方式',
                                leading: AppIconBadge(
                                  icon: Icons.straighten_rounded,
                                  color: colors.primary,
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: colors.block,
                                    shape: Radii.pillShape,
                                  ),
                                  child: Text(
                                    context.unit.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text2,
                                    ),
                                  ),
                                ),
                                showChevron: true,
                                onTap: () => _pickUnit(context),
                              ),
                              Divider(
                                height: 1,
                                color: colors.divider,
                                indent: 64,
                                endIndent: 16,
                              ),
                              ListRow(
                                title: '实况通知',
                                subtitle: liveUpdate.maybeWhen(
                                  data: (cap) => cap.summary,
                                  orElse: () => '检测中…',
                                ),
                                showChevron: canOpenNotificationSettings,
                                leading: AppIconBadge(
                                  icon: Icons.notifications_active_outlined,
                                  color: colors.warning,
                                ),
                                onTap: canOpenNotificationSettings
                                    ? () => unawaited(
                                        openAppNotificationSettings(),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.lg),
                        const SectionHeading(title: '显示与交互'),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              LiquidSwitchRow(
                                title: '大字模式',
                                subtitle: '整体字号放大约 12%',
                                leading: const AppIconBadge(
                                  icon: Icons.format_size_rounded,
                                  color: Color(0xFF5856D6),
                                ),
                                value: settings.largeText,
                                onChanged: settings.setLargeText,
                              ),
                              Divider(
                                height: 1,
                                color: colors.divider,
                                indent: 64,
                                endIndent: 16,
                              ),
                              LiquidSwitchRow(
                                title: '减少动效',
                                subtitle: '关闭过渡位移动画，页面响应更直接',
                                leading: const AppIconBadge(
                                  icon: Icons.motion_photos_off_outlined,
                                  color: Color(0xFF0EA5E9),
                                ),
                                value: settings.reduceMotion,
                                onChanged: (value) =>
                                    settings.setReduceMotion(value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gaps.lg),
                        const SectionHeading(title: '数据管理'),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListRow(
                            title: '清空全部数据',
                            subtitle:
                                '删除全部${context.unit.quantity}、账目、分类、工作与预算，不可恢复',
                            leading: AppIconBadge(
                              icon: Icons.delete_outline_rounded,
                              color: colors.expense,
                            ),
                            danger: true,
                            onTap: () async {
                              final confirmed = await showConfirmDialog(
                                context,
                                title: '清空全部数据？',
                                description:
                                    '将删除全部${context.unit.quantity}与账目，'
                                    '并结束进行中的计时。\n建议先导出备份。',
                                confirmLabel: '清空',
                                danger: true,
                              );
                              if (confirmed != true) return;
                              if (!context.mounted) return;
                              ref.read(timerProvider.notifier).discard();
                              final cleared = ref
                                  .read(appControllerProvider.notifier)
                                  .clearAll();
                              ref
                                  .read(selectedMonthProvider.notifier)
                                  .setMonth(currentMonthKey());
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      cleared
                                          ? '已清空全部数据，进行中的计时已结束'
                                          : '本地文件已清空，但新存档写入失败，请重试',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: Gaps.xl),
                        Center(
                          child: Text(
                            '时页 TIMEPAGE · 1.8.2 · 数据全部保存在本机',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.text3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              overlays: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PinnedSubHeader(title: '使用设置', onBack: widget.onBack),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 选计量单位：只换显示标签，不动任何数据。
  Future<void> _pickUnit(BuildContext context) async {
    final settings = ref.read(settingsProvider);
    final current = context.unit;
    final picked = await showAppSheet<MeasureUnit>(
      context: context,
      builder: (sheetContext) => SheetScaffold(
        title: '计量单位',
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.xl),
          children: [
            for (final unit in MeasureUnit.presets)
              ListRow(
                title: unit.name,
                subtitle: '本月${unit.quantity} · 数字旁的短单位「${unit.short}」',
                trailing: unit.id == current.id
                    ? Icon(Icons.check_rounded, color: context.colors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(unit),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked.id != current.id) {
      await settings.setMeasureUnit(picked);
    }
  }
}
