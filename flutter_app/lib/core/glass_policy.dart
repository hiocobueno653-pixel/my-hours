import 'package:fluid_glass/fluid_glass.dart';

import 'settings.dart';

/// 液态玻璃的实际生效方案。
///
/// fluid_glass 只有「液态折射 / 普通磨砂」两档，因此产品上的
/// 「标准」与「极致」靠作用范围区分，而不是伪造第三个着色器档位：
/// - 无：全界面普通磨砂；
/// - 标准：仅底栏镜片使用折射，其余界面保持磨砂，兼顾功耗；
/// - 极致：全界面启用折射。
class GlassEffectPolicy {
  const GlassEffectPolicy({
    required this.globalQuality,
    required this.dockQuality,
    required this.liquidDock,
  });

  final GlassQuality globalQuality;
  final GlassQuality dockQuality;
  final bool liquidDock;
}

GlassQuality globalGlassQualityFor(
  AppGlassPreference preference, {
  bool reduceEffects = false,
}) {
  if (reduceEffects || preference != AppGlassPreference.extreme) {
    return GlassQuality.plain;
  }
  return GlassQuality.liquid;
}

GlassEffectPolicy resolveGlassEffectPolicy(
  AppGlassPreference preference, {
  required bool liquidSupported,
  bool reduceEffects = false,
}) {
  if (reduceEffects || preference == AppGlassPreference.none) {
    return const GlassEffectPolicy(
      globalQuality: GlassQuality.plain,
      dockQuality: GlassQuality.plain,
      liquidDock: false,
    );
  }
  if (preference == AppGlassPreference.extreme) {
    return const GlassEffectPolicy(
      globalQuality: GlassQuality.liquid,
      dockQuality: GlassQuality.liquid,
      liquidDock: true,
    );
  }
  return GlassEffectPolicy(
    globalQuality: GlassQuality.plain,
    dockQuality: liquidSupported ? GlassQuality.liquid : GlassQuality.plain,
    liquidDock: liquidSupported,
  );
}
