import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluid_glass/fluid_glass.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/motion.dart';
import 'core/motion_origin.dart';
import 'core/settings.dart';
import 'core/text_scaling.dart';
import 'core/theme_tokens.dart';
import 'data/persistence.dart';
import 'features/onboarding/welcome_screen.dart';
import 'state/app_controller.dart';
import 'ui/dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  try {
    runApp(_buildApp(await _loadBootData()));
  } on Object {
    runApp(const _BootFailureApp());
  }
}

class _BootData {
  const _BootData({
    required this.store,
    required this.settings,
    required this.startupLoad,
  });

  final LocalStore store;
  final AppSettings settings;
  final LoadResult startupLoad;
}

Future<_BootData> _loadBootData() async {
  final directoryFuture = getApplicationSupportDirectory();
  final settingsFuture = AppSettings.load();
  final directory = await directoryFuture;
  final settings = await settingsFuture;
  final store = LocalStore(directory);
  final startupLoad = store.load();
  if (startupLoad.status == LoadStatus.ok) {
    // 打开应用时先留一份「启动现场」，即使当天还没点保存也能回到这里。
    store.createDailySnapshot();
  }

  return _BootData(store: store, settings: settings, startupLoad: startupLoad);
}

Widget _buildApp(_BootData data) {
  return ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(data.store),
      startupLoadProvider.overrideWithValue(data.startupLoad),
      settingsProvider.overrideWithValue(data.settings),
      startupCorruptionProvider.overrideWithValue(
        data.startupLoad.status == LoadStatus.corrupted,
      ),
      startupRecoveredProvider.overrideWithValue(
        recoveredFromBackup(data.startupLoad),
      ),
    ],
    child: MyHoursApp(settings: data.settings),
  );
}

class _BootFailureApp extends StatefulWidget {
  const _BootFailureApp();

  @override
  State<_BootFailureApp> createState() => _BootFailureAppState();
}

class _BootFailureAppState extends State<_BootFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      final data = await _loadBootData();
      runApp(_buildApp(data));
    } on Object {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时页',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppColors.light, AppTokens.lightTokens),
      darkTheme: buildAppTheme(AppColors.dark, AppTokens.darkTokens),
      themeMode: ThemeMode.system,
      home: _BootErrorScreen(onRetry: _retry, retrying: _retrying),
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.onRetry, this.retrying = false});

  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 42, color: colors.text3),
              const SizedBox(height: 16),
              Text(
                '暂时无法打开时页',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '本地数据没有受到影响，请重试。',
                style: TextStyle(color: colors.text2, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: retrying ? null : onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(retrying ? '正在重试…' : '重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHoursApp extends StatelessWidget {
  const MyHoursApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final lightColors = AppColors.light.withAccent(
          settings.accentColor,
          isDark: false,
          style: settings.colorStyle,
        );
        final darkColors =
            (settings.pureBlack ? AppColors.darkPureBlack : AppColors.dark)
                .withAccent(
                  settings.accentColor,
                  isDark: true,
                  style: settings.colorStyle,
                  pureBlack: settings.pureBlack,
                );
        return MaterialApp(
          title: kHoursOnly ? '时页·工时' : '时页',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(
            lightColors,
            AppTokens.lightTokens.copyWith(colors: lightColors),
          ),
          darkTheme: buildAppTheme(
            darkColors,
            AppTokens.darkTokens.copyWith(colors: darkColors),
          ),
          themeMode: settings.themeMode,
          // 主题切换是状态变化，不是空间动画；不要整页渐变 200ms。
          themeAnimationDuration: Duration.zero,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final colors = context.colors;
            final reduceEffects =
                media.disableAnimations || settings.reduceMotion;
            final glassPreference = settings.glassPreference;
            final appContent = MediaQuery(
              data: media.copyWith(
                textScaler: AppTextScaler(
                  media.textScaler,
                  settings.textScale,
                ).clamp(maxScaleFactor: 1.30),
                disableAnimations: reduceEffects,
                // 内容延伸到系统栏下方后，三页的吸顶栏自己消费 padding.top；
                // 这里保留原始 padding，不做二次扣减。
              ),
              child: child ?? const SizedBox.shrink(),
            );
            final gestureAwareContent = Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => MotionOrigin.record(event.position),
              child: appContent,
            );
            // 状态栏图标颜色必须跟随主题，否则深色模式会出现"黑底黑字"。
            return LiquidGlassTheme(
              colors:
                  LiquidGlassColors.forBrightness(
                    isDark ? Brightness.dark : Brightness.light,
                  ).copyWith(
                    accent: colors.primary,
                    content: colors.text,
                    container: colors.isDark
                        ? colors.card.withValues(alpha: 0.46)
                        : Colors.white.withValues(alpha: 0.62),
                    track: colors.inset,
                  ),
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                ),
                child:
                    reduceEffects || glassPreference == AppGlassPreference.none
                    ? GlassQualityScope(
                        quality: GlassQuality.plain,
                        child: gestureAwareContent,
                      )
                    : glassPreference == AppGlassPreference.extreme
                    ? GlassQualityScope(
                        quality: GlassQuality.liquid,
                        child: gestureAwareContent,
                      )
                    : gestureAwareContent,
              ),
            );
          },
          home: _AppLaunchGate(settings: settings, hoursOnly: kHoursOnly),
        );
      },
    );
  }
}

/// 首次启动先展示欢迎页；写入标记后用淡入过渡进入记工主页。
class _AppLaunchGate extends ConsumerWidget {
  const _AppLaunchGate({required this.settings, required this.hoursOnly});

  final AppSettings settings;
  final bool hoursOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final corrupted = ref.watch(startupCorruptionProvider);
    final recovered = ref.watch(startupRecoveredProvider);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final content = AnimatedSwitcher(
          duration: motionDuration(
            const Duration(milliseconds: 420),
            disableAnimations: disable,
          ),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) {
            final children = List<Widget>.of(previous);
            if (current != null) children.add(current);
            return Stack(fit: StackFit.expand, children: children);
          },
          child: settings.brandWelcomeSeen
              ? AppShell(
                  key: const ValueKey('app-shell'),
                  hoursOnly: hoursOnly,
                  largeText: settings.largeText,
                  onLargeTextChanged: settings.setLargeText,
                  dockStyle: settings.dockStyle,
                  tabTransition: settings.tabTransition,
                  glassPreference: settings.glassPreference,
                )
              : WelcomeScreen(
                  key: const ValueKey('welcome'),
                  onStart: settings.setWelcomeSeen,
                ),
        );
        return _StartupCorruptionGuard(
          corrupted: corrupted,
          recovered: recovered,
          child: content,
        );
      },
    );
  }
}

class _StartupCorruptionGuard extends StatefulWidget {
  const _StartupCorruptionGuard({
    required this.corrupted,
    required this.recovered,
    required this.child,
  });

  final bool corrupted;

  /// 主文件不可读、已从备份回退：数据可用，但最近一次改动可能丢失。
  final bool recovered;
  final Widget child;

  @override
  State<_StartupCorruptionGuard> createState() =>
      _StartupCorruptionGuardState();
}

class _StartupCorruptionGuardState extends State<_StartupCorruptionGuard> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.corrupted || widget.recovered) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
    }
  }

  @override
  void didUpdateWidget(covariant _StartupCorruptionGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final became =
        (!oldWidget.corrupted && widget.corrupted) ||
        (!oldWidget.recovered && widget.recovered);
    if (became) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
    }
  }

  Future<void> _showNotice() async {
    if (!mounted || _shown) return;
    _shown = true;
    if (!widget.corrupted) {
      // 回退成功是「数据还在，但可能在旧版本」：轻提示，不打断。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('主文件未能读取，已从备份恢复；最近一次改动可能不在'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }
    await showConfirmDialog(
      context,
      title: '本地存档需要检查',
      description:
          '主文件与两代备份都未能读取，应用已进入空数据模式，原文件没有被删除。'
          '请先到「我的 → 数据与备份」恢复可用备份，再继续记录。',
      confirmLabel: '知道了',
      cancelLabel: '稍后',
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
