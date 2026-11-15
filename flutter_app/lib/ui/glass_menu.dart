import 'package:flutter/material.dart';
import 'package:fluid_glass/fluid_glass.dart';

import '../core/theme_tokens.dart';
import 'widgets.dart';

/// 单选项液体玻璃菜单。
///
/// 收起时是一枚紧凑玻璃胶囊；点击后由 [LiquidMenu] 从锚点角落
/// 液滴式展开，选项使用系统菜单的勾选语义。主题页的配色风格、
/// 顶栏更多操作等入口共用同一套材质与动效。
class GlassSelectMenu<T> extends StatelessWidget {
  const GlassSelectMenu({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.panelWidth = 176,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final double panelWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    return LiquidMenu(
      backdrop: nativeBackdrop,
      items: [
        for (final value in values)
          LiquidMenuItem(
            label: labelOf(value),
            isSelected: value == selected,
            onSelected: () => onChanged(value),
          ),
      ],
      side: LiquidMenuSide.below,
      alignment: Alignment.topRight,
      panelWidth: panelWidth,
      gap: 8,
      margin: EdgeInsets.only(
        top: media.padding.top + 8,
        bottom: media.padding.bottom + 96,
        left: 12,
        right: 12,
      ),
      rootOverlay: true,
      anchorBuilder: (context, isOpen, toggle) {
        return Semantics(
          button: true,
          label: '${labelOf(selected)}，展开选项',
          onTap: toggle,
          excludeSemantics: true,
          child: Pressable(
            onTap: toggle,
            shape: Radii.shape(18),
            pressedScale: 0.97,
            child: HeaderGlassSurface(
              height: 36,
              radius: 18,
              bright: true,
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labelOf(selected),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 顶栏玻璃菜单按钮。面板由 fluid_glass 负责液滴形变、遮罩和边缘翻转；
/// 业务层只提供菜单项，不再手写 OverlayEntry。
class GlassMenuButton extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.items,
    this.icon = Icons.more_horiz_rounded,
    this.tooltip = '更多操作',
  });

  final List<LiquidMenuItem> items;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LiquidMenu(
      backdrop: nativeBackdrop,
      items: items,
      side: LiquidMenuSide.below,
      alignment: Alignment.topRight,
      panelWidth: 224,
      gap: 8,
      margin: EdgeInsets.only(
        top: media.padding.top + 8,
        bottom: media.padding.bottom + 96,
        left: 12,
        right: 12,
      ),
      // 根 Overlay 才能盖住底部 Dock。
      rootOverlay: true,
      anchorBuilder: (context, isOpen, toggle) {
        return BarActionButton(
          icon: icon,
          tooltip: tooltip,
          selected: isOpen,
          bright: true,
          onTap: toggle,
        );
      },
    );
  }
}
