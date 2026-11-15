import 'package:flutter/material.dart';
import 'package:fluid_glass/fluid_glass.dart';

import 'widgets.dart';

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
