import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/glass_policy.dart';
import 'core/measure_unit.dart';
import 'core/motion.dart';
import 'core/settings.dart';
import 'core/theme_tokens.dart';
import 'features/ledger/ledger_view.dart';
import 'features/mine/my_view.dart';
import 'features/mine/stats_page.dart';
import 'features/work/month_view.dart';
import 'platform/back_navigation.dart';
import 'state/app_controller.dart';
import 'state/timer_controller.dart';
import 'ui/widgets.dart';

/// 四个核心入口：工时 / 账本 / 统计 / 我的（HOURS_ONLY 省略账本）。
enum AppTab { work, ledger, stats, mine }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.hoursOnly,
    required this.largeText,
    this.dockStyle = AppDockStyle.floating,
    this.tabTransition = AppTabTransition.slide,
    this.glassPreference = AppGlassPreference.standard,
  });

  final bool hoursOnly;
  final bool largeText;
  final AppDockStyle dockStyle;
  final AppTabTransition tabTransition;
  final AppGlassPreference glassPreference;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final LayerBackdrop _backdrop = LayerBackdrop();
  AppTab _tab = AppTab.work;
  String? _exitHint;
  DateTime? _lastBackAt;
  Timer? _exitTimer;
  bool _ledgerOpening = false;
  final Map<AppTab, Widget> _pageCache = {};
  final Map<AppTab, ScrollController> _tabScrolls = {
    for (final tab in AppTab.values) tab: ScrollController(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(timerProvider.notifier).syncNotification(),
      );
    });
  }

  List<AppTab> get _tabs => widget.hoursOnly
      ? const [AppTab.work, AppTab.stats, AppTab.mine]
      : const [AppTab.work, AppTab.ledger, AppTab.stats, AppTab.mine];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitTimer?.cancel();
    for (final controller in _tabScrolls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appControllerProvider.notifier).flushPendingPersist();
    }
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.largeText != widget.largeText ||
        oldWidget.hoursOnly != widget.hoursOnly) {
      _pageCache.clear();
    }
  }

  void _selectTab(AppTab tab) {
    if (tab == _tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _tab = tab;
    });
  }

  void _reselectTab() {
    HapticFeedback.selectionClick();
    final controller = _tabScrolls[_tab];
    if (controller == null || !controller.hasClients) return;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    controller.animateTo(
      0,
      duration: motionDuration(Timings.slow, disableAnimations: disable),
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
    setState(() {
      _tab = AppTab.ledger;
    });
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
    final page = _pageCache.putIfAbsent(tab, () {
      return switch (tab) {
        AppTab.work => MonthView(
          onOpenLedger: widget.hoursOnly ? null : _openLedgerForDate,
        ),
        AppTab.ledger => const LedgerView(),
        AppTab.stats => const StatsPage(),
        AppTab.mine => const MyView(),
      };
    });
    return PrimaryScrollController(controller: _tabScrolls[tab]!, child: page);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final glassPolicy = resolveGlassEffectPolicy(
      widget.glassPreference,
      liquidSupported: GlassDeviceTier.instance.quality == GlassQuality.liquid,
      reduceEffects: disable,
    );
    final floatingDock = widget.dockStyle == AppDockStyle.floating;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final dockClearance =
        (floatingDock ? math.max(16.0, bottomPad + 6.0) : bottomPad) +
        _BottomNavBar.dockHeight +
        10;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleRootBack();
      },
      child: Scaffold(
        backgroundColor: colors.page,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showSidebar = constraints.maxWidth >= 720;
            final showLabels = constraints.maxWidth >= 900;
            final tabView = _FlClashTabView(
              tabs: _tabs,
              active: _tab,
              slide: widget.tabTransition == AppTabTransition.slide,
              animate: !showSidebar,
              builder: _pageFor,
            );

            final mainArea = AppBackdropScope(
              backdrop: _backdrop,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  BackdropLayer(
                    backdrop: _backdrop,
                    motionPixelRatio: 1.0,
                    changeMargin: 24.0,
                    child: AppBackdropScope(
                      backdrop: nativeBackdrop,
                      child: AmbientPageGlow(child: tabView),
                    ),
                  ),
                  if (!showSidebar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomNavBar(
                        key: const ValueKey('app-dock'),
                        tabs: _tabs,
                        active: _tab,
                        backdrop: _backdrop,
                        glassQuality: glassPolicy.dockQuality,
                        floating: floatingDock,
                        onSelect: _selectTab,
                        onReselect: _reselectTab,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: showSidebar ? 16 : dockClearance,
                    child: const _SaveStatusBanner(),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: AnimatedSlide(
                        duration: motionDuration(
                          Timings.fast,
                          disableAnimations: disable,
                        ),
                        offset: _exitHint == null
                            ? const Offset(0, -1.4)
                            : Offset.zero,
                        curve: Curves2.out,
                        child: AnimatedOpacity(
                          duration: motionDuration(
                            Timings.fast,
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
              ),
            );

            if (!showSidebar) return mainArea;
            return Row(
              children: [
                _AppSidebar(
                  tabs: _tabs,
                  active: _tab,
                  showLabels: showLabels,
                  onSelect: _selectTab,
                ),
                Expanded(child: mainArea),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// FlClash 双模式 PageView 标签切换：
/// - 滑动模式：整屏水平滑动（320ms Curves2.out），跨 >1 页时先临时换位到相邻槽位，
///   绝不构建和绘制中间路过的页面；
/// - 淡入模式：在同一 PageView 上抵消位移做原地交叉淡入（200ms Curves2.inOut），
///   且离位运动中的页由 SnapshotWidget 冻结重绘，保证 120fps 不掉帧。
class _FlClashTabView extends StatefulWidget {
  const _FlClashTabView({
    required this.tabs,
    required this.active,
    required this.slide,
    required this.animate,
    required this.builder,
  });

  final List<AppTab> tabs;
  final AppTab active;
  final bool slide;
  final bool animate;
  final Widget Function(AppTab tab) builder;

  @override
  State<_FlClashTabView> createState() => _FlClashTabViewState();
}

class _FlClashTabViewState extends State<_FlClashTabView> {
  late final PageController _pageController = PageController(
    initialPage: _indexOf(widget.active),
  );
  List<int>? _order;
  int _transitionToken = 0;

  int _indexOf(AppTab tab) {
    final index = widget.tabs.indexOf(tab);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant _FlClashTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length ||
        !_sameTabs(oldWidget.tabs, widget.tabs)) {
      _order = null;
      final target = _indexOf(widget.active);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(target);
        }
      });
      return;
    }
    if (oldWidget.active != widget.active) {
      unawaited(_navigateTo(widget.active));
    }
  }

  bool _sameTabs(List<AppTab> a, List<AppTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _navigateTo(AppTab tab) async {
    if (!mounted || !_pageController.hasClients) return;
    final target = _indexOf(tab);
    final token = ++_transitionToken;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final rawPage = _pageController.page?.round() ?? target;
    final current = (_order != null && rawPage < _order!.length)
        ? _order![rawPage]
        : rawPage.clamp(0, widget.tabs.length - 1);

    if (_order != null) {
      setState(() => _order = null);
      _pageController.jumpToPage(current);
    }

    if (disable || !widget.animate || current == target) {
      _pageController.jumpToPage(target);
      return;
    }

    if ((target - current).abs() > 1) {
      final adjacent = target > current ? target - 1 : target + 1;
      final swapped = List<int>.generate(widget.tabs.length, (i) => i);
      swapped[adjacent] = current;
      swapped[current] = adjacent;
      setState(() => _order = swapped);
      _pageController.jumpToPage(adjacent);
    }

    await _pageController.animateToPage(
      target,
      duration: widget.slide ? Timings.slow : Timings.fast,
      curve: widget.slide ? Curves2.out : Curves2.inOut,
    );
    if (mounted && token == _transitionToken && _order != null) {
      setState(() => _order = null);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(target);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.tabs.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<AppTab>) return null;
        final logical = widget.tabs.indexOf(key.value);
        if (logical == -1) return null;
        return _order?.indexOf(logical) ?? logical;
      },
      itemBuilder: (context, slotIndex) {
        final logicalIndex = _order?[slotIndex] ?? slotIndex;
        final tab = widget.tabs[logicalIndex];
        return _FlClashTabPage(
          key: ValueKey<AppTab>(tab),
          controller: _pageController,
          slotIndex: slotIndex,
          active: tab == widget.active,
          fadeMode: !widget.slide,
          child: widget.builder(tab),
        );
      },
    );
  }
}

class _FlClashTabPage extends StatefulWidget {
  const _FlClashTabPage({
    super.key,
    required this.controller,
    required this.slotIndex,
    required this.active,
    required this.fadeMode,
    required this.child,
  });

  final PageController controller;
  final int slotIndex;
  final bool active;
  final bool fadeMode;
  final Widget child;

  @override
  State<_FlClashTabPage> createState() => _FlClashTabPageState();
}

class _FlClashTabPageState extends State<_FlClashTabPage>
    with AutomaticKeepAliveClientMixin<_FlClashTabPage> {
  final SnapshotController _snapshot = SnapshotController();
  late final _TabFadeAnimation _fadeAnimation = _TabFadeAnimation();
  bool _moving = false;
  bool _disableAnimations = false;

  @override
  bool get wantKeepAlive => true;

  double _currentDelta() {
    final controller = widget.controller;
    final hasPage =
        controller.hasClients && controller.position.hasContentDimensions;
    final page = hasPage
        ? (controller.page ?? widget.slotIndex.toDouble())
        : widget.slotIndex.toDouble();
    return (page - widget.slotIndex).clamp(-1.0, 1.0);
  }

  void _syncMotion({bool allowSetState = true}) {
    final delta = _currentDelta();
    final absDelta = delta.abs();
    final moving = !_disableAnimations && absDelta > 0.001 && absDelta < 0.999;
    _snapshot.allowSnapshotting = moving;
    if (widget.fadeMode && !_disableAnimations) {
      _fadeAnimation.setValue((1.0 - absDelta).clamp(0.0, 1.0));
    } else {
      _fadeAnimation.setValue(1.0);
    }
    if (_moving != moving) {
      _moving = moving;
      if (allowSetState && mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncMotion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncMotion(allowSetState: false);
  }

  @override
  void didUpdateWidget(covariant _FlClashTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncMotion);
      widget.controller.addListener(_syncMotion);
    }
    _syncMotion(allowSetState: false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncMotion);
    _fadeAnimation.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final disable = _disableAnimations;
    final body = RepaintBoundary(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: widget.child,
      ),
    );
    final snapshotted = SnapshotWidget(
      controller: _snapshot,
      mode: SnapshotMode.permissive,
      child: body,
    );
    final gated = TickerMode(
      enabled: widget.active || _moving,
      child: IgnorePointer(
        ignoring: !widget.active,
        child: ExcludeSemantics(
          excluding: !widget.active,
          child: ExcludeFocus(excluding: !widget.active, child: snapshotted),
        ),
      ),
    );

    if (!widget.fadeMode || disable) return gated;

    return AnimatedBuilder(
      animation: widget.controller,
      child: FadeTransition(opacity: _fadeAnimation, child: gated),
      builder: (context, child) {
        return FractionalTranslation(
          translation: Offset(_currentDelta(), 0),
          child: child,
        );
      },
    );
  }
}

class _TabFadeAnimation extends Animation<double>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  double _value = 1.0;

  @override
  double get value => _value;

  @override
  AnimationStatus get status =>
      _value <= 0 ? AnimationStatus.dismissed : AnimationStatus.completed;

  void setValue(double next) {
    if ((_value - next).abs() < 0.0005) return;
    _value = next;
    notifyListeners();
  }
}

/// 落定式底部导航栏：实底卡片面 + 1px 顶分割线，永不遮挡日历或列表内容。
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    super.key,
    required this.tabs,
    required this.active,
    required this.backdrop,
    required this.glassQuality,
    required this.floating,
    required this.onSelect,
    required this.onReselect,
  });

  static const double dockHeight = 56;
  static const double _maxWidth = 340;
  static final ImageFilter _fixedBarBlur = ImageFilter.blur(
    sigmaX: 14,
    sigmaY: 14,
  );

  final List<AppTab> tabs;
  final AppTab active;
  final Backdrop backdrop;
  final GlassQuality glassQuality;
  final bool floating;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback onReselect;

  static String labelOf(BuildContext context, AppTab tab) => switch (tab) {
    AppTab.work => context.unit.quantity,
    AppTab.ledger => '账本',
    AppTab.stats => '统计',
    AppTab.mine => '我的',
  };

  static const _icons = {
    AppTab.work: Icons.schedule_outlined,
    AppTab.ledger: Icons.account_balance_wallet_outlined,
    AppTab.stats: Icons.insights_outlined,
    AppTab.mine: Icons.person_outline_rounded,
  };

  static const _activeIcons = {
    AppTab.work: Icons.schedule_rounded,
    AppTab.ledger: Icons.account_balance_wallet_rounded,
    AppTab.stats: Icons.insights_rounded,
    AppTab.mine: Icons.person_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final activeIndex = tabs.indexOf(active).clamp(0, tabs.length - 1);

    if (!floating) {
      final barColor = highContrast
          ? colors.card
          : (colors.isDark
                ? colors.card.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.80));
      final barSurface = DecoratedBox(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(
            top: BorderSide(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.8,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final tab in tabs)
                  Expanded(
                    child: Pressable(
                      onTap: () {
                        if (tab == active) {
                          onReselect();
                        } else {
                          onSelect(tab);
                        }
                      },
                      haptic: false,
                      shape: Radii.pillShape,
                      child: _DockTabContent(
                        tab: tab,
                        selected: tab == active,
                        disableAnimations: disable,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (highContrast || disable) return barSurface;
      return ClipRect(
        child: BackdropFilter(filter: _fixedBarBlur, child: barSurface),
      );
    }

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final bottomOffset = math.max(14.0, bottomPad + 6.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomOffset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: GlassQualityScope(
            quality: highContrast ? GlassQuality.plain : glassQuality,
            child: LiquidGlassTheme(
              colors: LiquidGlassTheme.of(context).copyWith(
                accent: colors.primary,
                content: colors.text,
                container: colors.isDark
                    ? Color.lerp(
                        colors.card,
                        Colors.white,
                        0.045,
                      )!.withValues(alpha: highContrast ? 1.0 : 0.88)
                    : colors.card.withValues(alpha: highContrast ? 1.0 : 0.92),
              ),
              child: LiquidBottomTabs(
                selectedTabIndex: activeIndex,
                onTabSelected: (index) {
                  if (index >= 0 && index < tabs.length) {
                    onSelect(tabs[index]);
                  }
                },
                onTabReselected: (_) => onReselect(),
                backdrop: backdrop,
                tabsCount: tabs.length,
                height: dockHeight,
                isInteractive: !disable,
                children: [
                  for (final tab in tabs)
                    LiquidBottomTab(
                      onPressed: () {
                        if (tab == active) {
                          onReselect();
                        } else {
                          onSelect(tab);
                        }
                      },
                      children: [_LiquidTabFace(tab: tab)],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidTabFace extends StatelessWidget {
  const _LiquidTabFace({required this.tab});

  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inAccentCopy =
        context
            .getElementForInheritedWidgetOfExactType<LiquidBottomTabScale>() !=
        null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 2,
      children: [
        Icon(
          inAccentCopy
              ? _BottomNavBar._activeIcons[tab]
              : _BottomNavBar._icons[tab],
          size: 20.5,
          color: colors.text2,
        ),
        Text(
          _BottomNavBar.labelOf(context, tab),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.15,
            fontWeight: inAccentCopy ? FontWeight.w600 : FontWeight.w500,
            color: colors.text2,
          ),
        ),
      ],
    );
  }
}

class _DockTabContent extends StatelessWidget {
  const _DockTabContent({
    required this.tab,
    required this.selected,
    required this.disableAnimations,
  });

  final AppTab tab;
  final bool selected;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = _BottomNavBar.labelOf(context, tab);
    final icon = selected
        ? _BottomNavBar._activeIcons[tab]!
        : _BottomNavBar._icons[tab]!;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: motionDuration(
              Timings.fast,
              disableAnimations: disableAnimations,
            ),
            curve: Curves2.out,
            width: selected ? 48 : 34,
            height: 28,
            decoration: ShapeDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              shape: Radii.pillShape,
            ),
            child: Icon(
              icon,
              size: 21,
              color: selected ? colors.primary : colors.text3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.primary : colors.text3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 写盘失败/隔离态的全局常驻提示。
///
/// 原先 `_persist` 失败只写日志，用户会看到界面已经变了、重启却丢了。
/// 这里把状态放到 Dock 上方，不遮住顶栏；磁盘错误提供「重试」，隔离态
/// 则明确指向备份恢复入口。
class _SaveStatusBanner extends ConsumerWidget {
  const _SaveStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(saveFailureProvider);
    final readOnly = ref.watch(archiveReadOnlyProvider);
    if (failure == null && !readOnly) {
      return const SizedBox.shrink();
    }
    final quarantined = readOnly || (failure?.quarantined ?? false);
    final colors = context.colors;
    final message = quarantined
        ? '存档损坏，当前为只读。请到「我的 → 数据与备份」导入备份。'
        : (failure?.message ?? '保存失败，本次改动仅在内存中。');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: ShapeDecoration(
            color: colors.expenseSoft,
            shape: Radii.shape(Radii.md),
            shadows: context.floatingShadows,
          ),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              children: [
                Icon(
                  quarantined ? Icons.shield_outlined : Icons.cloud_off_rounded,
                  size: 18,
                  color: colors.expense,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                ),
                if (!quarantined) ...[
                  const SizedBox(width: 6),
                  Pressable(
                    onTap: () =>
                        ref.read(appControllerProvider.notifier).retrySave(),
                    shape: Radii.pillShape,
                    pressedScale: 0.96,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: colors.card.withValues(alpha: 0.72),
                        shape: Radii.pillShape,
                      ),
                      child: Text(
                        '重试',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.card,
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
                                  fontSize: TypeScale.micro,
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
                                  fontSize: TypeScale.micro,
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
                          tab == active
                              ? _BottomNavBar._activeIcons[tab]
                              : _BottomNavBar._icons[tab],
                          size: 21,
                          color: tab == active ? colors.primary : colors.text2,
                        ),
                        if (showLabels) ...[
                          const SizedBox(width: 12),
                          Text(
                            _BottomNavBar.labelOf(context, tab),
                            style: TextStyle(
                              fontSize: 14.5,
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
