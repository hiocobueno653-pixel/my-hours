import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/theme_tokens.dart';

void main() {
  double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final light = la > lb ? la : lb;
    final dark = la > lb ? lb : la;
    return (light + 0.05) / (dark + 0.05);
  }

  test('四套配色都保持 page / card / block / inset 的层级差', () {
    for (final style in AppColorStyle.values) {
      final light = AppColors.light.withAccent(
        AppColors.light.primary,
        isDark: false,
        style: style,
      );
      final dark = AppColors.dark.withAccent(
        AppColors.dark.primary,
        isDark: true,
        style: style,
      );

      expect(
        {light.page, light.card, light.block, light.inset},
        hasLength(4),
        reason: '$style light surfaces collapsed',
      );
      expect(
        {dark.page, dark.card, dark.block, dark.inset},
        hasLength(4),
        reason: '$style dark surfaces collapsed',
      );

      expect(
        light.card.computeLuminance(),
        greaterThan(light.page.computeLuminance()),
        reason: '$style light card must lift above page',
      );
      expect(
        light.page.computeLuminance(),
        greaterThan(light.block.computeLuminance()),
        reason: '$style light page must stay above block',
      );
      expect(
        light.block.computeLuminance(),
        greaterThan(light.inset.computeLuminance()),
        reason: '$style light block must stay above inset',
      );

      expect(
        dark.inset.computeLuminance(),
        greaterThan(dark.block.computeLuminance()),
        reason: '$style dark inset must stay above block',
      );
      expect(
        dark.block.computeLuminance(),
        greaterThan(dark.card.computeLuminance()),
        reason: '$style dark block must stay above card',
      );
      expect(
        dark.card.computeLuminance(),
        greaterThan(dark.page.computeLuminance()),
        reason: '$style dark card must lift above page',
      );
      expect(
        contrastRatio(light.primary, light.onPrimary),
        greaterThan(4.0),
        reason: '$style light primary text contrast',
      );
      expect(
        contrastRatio(dark.primary, dark.onPrimary),
        greaterThan(4.0),
        reason: '$style dark primary text contrast',
      );
    }
  });
}
