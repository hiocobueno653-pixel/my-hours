import 'package:flutter_test/flutter_test.dart';
import 'package:fluid_glass/fluid_glass.dart';
import 'package:my_hours/core/glass_policy.dart';
import 'package:my_hours/core/settings.dart';

void main() {
  test('液态玻璃标准与极致使用不同作用范围', () {
    expect(
      globalGlassQualityFor(AppGlassPreference.standard),
      GlassQuality.plain,
    );
    expect(
      globalGlassQualityFor(AppGlassPreference.extreme),
      GlassQuality.liquid,
    );

    final standard = resolveGlassEffectPolicy(
      AppGlassPreference.standard,
      liquidSupported: true,
    );
    expect(standard.globalQuality, GlassQuality.plain);
    expect(standard.dockQuality, GlassQuality.liquid);
    expect(standard.liquidDock, isTrue);

    final extreme = resolveGlassEffectPolicy(
      AppGlassPreference.extreme,
      liquidSupported: true,
    );
    expect(extreme.globalQuality, GlassQuality.liquid);
    expect(extreme.dockQuality, GlassQuality.liquid);
    expect(extreme.liquidDock, isTrue);
  });

  test('无与减少动效时全部退回普通磨砂', () {
    for (final preference in AppGlassPreference.values) {
      final reduced = resolveGlassEffectPolicy(
        preference,
        liquidSupported: true,
        reduceEffects: true,
      );
      expect(reduced.globalQuality, GlassQuality.plain);
      expect(reduced.dockQuality, GlassQuality.plain);
      expect(reduced.liquidDock, isFalse);
    }

    final none = resolveGlassEffectPolicy(
      AppGlassPreference.none,
      liquidSupported: true,
    );
    expect(none.globalQuality, GlassQuality.plain);
    expect(none.dockQuality, GlassQuality.plain);
    expect(none.liquidDock, isFalse);
  });
}
