import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluid_glass/fluid_glass.dart';

import 'core/motion.dart';
import 'core/theme_tokens.dart';
import 'features/ledger/ledger_view.dart';
import 'features/mine/my_view.dart';
import 'features/work/month_view.dart';
import 'platform/back_navigation.dart';
import 'state/app_controller.dart';
import 'ui/widgets.dart';

const bool _plainGlassBuild = bool.fromEnvironment('MYHOURS_PLAIN_GLASS');

/// 折射着色器在 Android x86_64 模拟器上会拖慢冷启动，
/// 真机 ARM/ARM64 才启用液态镜片；其余平台退回普通高斯玻璃。
bool get _liquidDockSupported {
  if (_plainGlassBuild || !Platform.isAndroid) return false;
  final abi = Abi.current();
  if (abi != Abi.androidArm64) return false;
  // 低端机即使 ABI 支持，也不做全屏折射；省下持续的背景采样。
  return GlassDeviceTier.instance.quality.hasRefraction;
}

/// 三个 tab。`HOURS_ONLY` 变体只保留记工与我的。
enum AppTab { work, ledger, mine }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.hoursOnly,
    required this.largeText,
    required this.onLargeTextChanged,
  });

  final bool hoursOnly;
  final bool largeText;
  final ValueChanged<bool> onLargeTextChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.work;
  String? _exitHint;
  DateTime? _lastBackAt;
  Timer? _exitTimer;
  bool _ledgerOpening = false;
  final LayerBackdrop _backdrop = LayerBackdrop(preferPictureReplay: true);
  final Map<AppTab, ScrollController> _tabScrolls = {
    for (final tab in AppTab.values) tab: ScrollController(),
  };

  List<AppTab> get _tabs => widget.hoursOnly
      ? const [AppTab.work, AppTab.mine]
      : const [AppTab.work, AppTab.ledger, AppTab.mine];

  @override
  void dispose() {
    _exitTimer?.cancel();
    for (final controller in _tabScrolls.values) {
      controller.dispose();
    }
    _backdrop.dispose();
    super.dispose();
  }

  void _selectTab(AppTab tab) {
    if (tab == _tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  void _reselectTab() {
    HapticFeedback.selectionClick();
    final controller = _tabScrolls[_tab];
    if (controller == null || !controller.hasClients) return;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    controller.animateTo(
      0,
      duration: motionDuration(Timings.medium, disableAnimations: disable),
      curve: Curves2.out,
    );
  }

  void _openLedgerForDate(String date) {
    if (_ledgerOpening) return;
    _ledgerOpening = true;
    final targetMonth = date.length >= 7 ? date.substring(0, 7) : date;
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(selectedMonthProvider.notifier).setMonth(targetMonth);
    setState(() => _tab = AppTab.ledger);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _ledgerOpening = false;
        return;
      }
      try {
        await showLedgerEditor(context, presetDate: date);
      } finally {
        _ledgerOpening = false;
      }
    });
  }

  void _handleRootBack() {
    if (BackNavigation.dispatch()) {
      _lastBackAt = null;
      return;
    }
    if (_tab != AppTab.work) {
      setState(() => _tab = AppTab.work);
      return;
    }
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    setState(() => _exitHint = '再按一次返回键退出应用');
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _exitHint = null);
    });
  }

  Widget _pageFor(AppTab tab) {
    final page = switch (tab) {
      AppTab.work => MonthView(
        onOpenLedger: widget.hoursOnly ? null : _openLedgerForDate,
      ),
      AppTab.ledger => const LedgerView(),
      AppTab.mine => MyView(
        largeText: widget.largeText,
        onLargeTextChanged: widget.onLargeTextChanged,
      ),
    };
    return PrimaryScrollController(controller: _tabScrolls[tab]!, child: page);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleRootBack();
      },
      child: Scaffold(
        backgroundColor: colors.page,
        extendBody: true,
        extendBodyBehindAppBar: true,
        // 键盘弹出时不压缩 body。
        //
        // Dock 是 body 里 `Positioned(bottom: 0)` 的悬浮层，默认的
        // `resizeToAvoidBottomInset: true` 会把 body 顶到键盘上方，
        // 于是 Dock 跟着「抬起来」浮在半空。关掉之后 Dock 留在原位被键盘
        // 盖住，页面也不跟着上移；需要避让的滚动留白由 `pageBottomInset`
        // 单独加 keyboard inset 处理。
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showSidebar = constraints.maxWidth >= 720;
            final showLabels = constraints.maxWidth >= 900;
            final liquidDock = _liquidDockSupported && !disable && !showSidebar;
            final tabView = _FadeTabView(
              tabs: _tabs,
              active: _tab,
              builder: _pageFor,
            );

            final content = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: liquidDock
                      ? BackdropLayer(
                          backdrop: _backdrop,
                          changeMargin: 24,
                          motionPixelRatio: math.min(
                            MediaQuery.devicePixelRatioOf(context),
                            1.25,
                          ),
                          child: tabView,
                        )
                      : tabView,
                ),
                if (!showSidebar)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _AppDock(
                      tabs: _tabs,
                      active: _tab,
                      backdrop: _backdrop,
                      onSelect: _selectTab,
                      onReselect: _reselectTab,
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedSlide(
                      duration: motionDuration(
                        Timings.short,
                        disableAnimations: disable,
                      ),
                      offset: _exitHint == null
                          ? const Offset(0, -1.4)
                          : Offset.zero,
                      curve: Curves2.out,
                      child: AnimatedOpacity(
                        duration: motionDuration(
                          Timings.short,
                          disableAnimations: disable,
                        ),
                        opacity: _exitHint == null ? 0 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(top: Gaps.sm),
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Gaps.lg,
                                  vertical: 8,
                                ),
                                decoration: ShapeDecoration(
                                  color: colors.isDark
                                      ? colors.block
                                      : const Color(0xE6141416),
                                  shape: Radii.shape(Radii.md),
                                ),
                                child: Text(
                                  _exitHint ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.isDark
                                        ? colors.text
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );

            if (!showSidebar) return content;
            return Row(
              children: [
                _AppSidebar(
                  tabs: _tabs,
                  active: _tab,
                  showLabels: showLabels,
                  onSelect: _selectTab,
                ),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 保活页面 + 220ms 交叉淡入。隐藏页不接收指针与焦点，ticker 也停掉。
class _FadeTabView extends StatelessWidget {
  const _FadeTabView({
    required this.tabs,
    required this.active,
    required this.builder,
  });

  final List<AppTab> tabs;
  final AppTab active;
  final Widget Function(AppTab tab) builder;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final activeIndex = tabs.indexOf(active);
    return ClipRect(
      child: Stack(
        children: [
          for (final tab in tabs)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: tab != active,
                child: ExcludeSemantics(
                  excluding: tab != active,
                  child: ExcludeFocus(
                    excluding: tab != active,
                    child: AnimatedSlide(
                      offset: tab == active
                          ? Offset.zero
                          : Offset(
                              (tabs.indexOf(tab) - activeIndex).sign * 0.014,
                              0,
                            ),
                      duration: motionDuration(
                        Timings.short,
                        disableAnimations: disable,
                      ),
                      curve: Curves2.emphasizedDecelerate,
                      child: AnimatedOpacity(
                        opacity: tab == active ? 1 : 0,
                        duration: motionDuration(
                          Timings.short,
                          disableAnimations: disable,
                        ),
                        curve: Curves2.standard,
                        child: TickerMode(
                          enabled: tab == active,
                          child: RepaintBoundary(child: builder(tab)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 移动端 Dock：FluidGlass 的 `LiquidBottomTabs`。
///
/// 选中镜片支持按住膨胀、跟手拖动、跨 Tab 弹簧回位；镜片本身通过
/// `DrawBackdrop` 对页面做折射与色散，并放大下方 Tab 的高亮副本。
class _AppDock extends StatelessWidget {
  const _AppDock({
    required this.tabs,
    required this.active,
    required this.backdrop,
    required this.onSelect,
    required this.onReselect,
  });

  final List<AppTab> tabs;
  final AppTab active;
  final Backdrop backdrop;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback onReselect;

  static const double _height = 68;
  static const double _maxWidth = 356;

  static const _labels = {
    AppTab.work: '记工',
    AppTab.ledger: '记账',
    AppTab.mine: '我的',
  };

  static const _icons = {
    AppTab.work: Icons.calendar_month_rounded,
    AppTab.ledger: Icons.account_balance_wallet_rounded,
    AppTab.mine: Icons.person_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bottom = math.max(20.0, MediaQuery.paddingOf(context).bottom + 8);
    final index = tabs.indexOf(active);
    final bar = LiquidBottomTabs(
      selectedTabIndex: index,
      onTabSelected: (next) => onSelect(tabs[next]),
      backdrop: backdrop,
      tabsCount: tabs.length,
      height: _height,
      isInteractive: !disable,
      onTabReselected: (_) => onReselect(),
      children: [
        for (final tab in tabs)
          LiquidBottomTab(
            onPressed: () => onSelect(tab),
            children: [_DockTabContent(tab: tab)],
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: LiquidGlassTheme(
            colors:
                LiquidGlassColors.forBrightness(
                  colors.isDark ? Brightness.dark : Brightness.light,
                ).copyWith(
                  accent: colors.primary,
                  container: colors.isDark
                      ? colors.card.withValues(alpha: 0.38)
                      : Colors.white.withValues(alpha: 0.34),
                  content: colors.text,
                  track: colors.inset,
                ),
            child: _liquidDockSupported
                ? bar
                : GlassQualityScope(quality: GlassQuality.plain, child: bar),
          ),
        ),
      ),
    );
  }
}

class _DockTabContent extends StatelessWidget {
  const _DockTabContent({required this.tab});

  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_AppDock._icons[tab], size: 24.5, color: colors.text2),
        Text(
          _AppDock._labels[tab]!,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: colors.text2,
          ),
        ),
      ],
    );
  }
}

/// 宽屏侧栏：chrome 底 + 3×16 的选中指示条，展开/收窄不同宽度。
class _AppSidebar extends StatelessWidget {
  const _AppSidebar({
    required this.tabs,
    required this.active,
    required this.showLabels,
    required this.onSelect,
  });

  final List<AppTab> tabs;
  final AppTab active;
  final bool showLabels;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = showLabels ? 220.0 : 76.0;
    final chrome = colors.isDark ? const Color(0xFF111A2D) : colors.inset;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: chrome,
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                showLabels ? 20 : 0,
                20,
                showLabels ? 20 : 0,
                18,
              ),
              child: showLabels
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(3),
                          decoration: ShapeDecoration(
                            color: colors.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white,
                            shape: Radii.shape(13),
                            shadows: colors.isDark
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Color(0x122563EB),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Image.asset(
                            'assets/brand/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '时页',
                                style: TextStyle(
                                  fontSize: 21,
                                  height: 1.08,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.02,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'TIMEPAGE',
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '记录时间，记下生活。',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.2,
                                  color: colors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: colors.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white,
                          shape: Radii.shape(12),
                        ),
                        child: Image.asset(
                          'assets/brand/app_icon.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
            ),
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Pressable(
                  onTap: () => onSelect(tab),
                  shape: Radii.shape(14),
                  child: Container(
                    height: 44,
                    padding: EdgeInsets.symmetric(
                      horizontal: showLabels ? 12 : 0,
                    ),
                    decoration: ShapeDecoration(
                      color: tab == active ? colors.block : Colors.transparent,
                      shape: Radii.shape(14),
                    ),
                    child: Row(
                      mainAxisAlignment: showLabels
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 3,
                          height: 16,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: tab == active
                                  ? colors.primary
                                  : Colors.transparent,
                              shape: Radii.shape(2),
                            ),
                          ),
                        ),
                        SizedBox(width: showLabels ? 11 : 0),
                        Icon(
                          _AppDock._icons[tab],
                          size: 22,
                          color: tab == active ? colors.primary : colors.text2,
                        ),
                        if (showLabels) ...[
                          const SizedBox(width: 12),
                          Text(
                            _AppDock._labels[tab]!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: tab == active
                                  ? colors.primary
                                  : colors.text,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            if (showLabels)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Text(
                  '本机数据 · 无账号',
                  style: TextStyle(fontSize: 11, color: colors.text3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
