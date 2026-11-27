import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/motion.dart';

/// 主题单帧切换 + 旧帧快照交叉淡出。
///
/// 避免 `ThemeData` 逐帧补间触发全树 12~24 次重建导致掉帧；在主题签名变化时
/// 捕获上一帧纹理并按 `Timings.fast` 线性淡出。
class ThemeCrossFade extends StatefulWidget {
  const ThemeCrossFade({
    super.key,
    required this.signature,
    required this.child,
    this.duration = Timings.fast,
  });

  final Object signature;
  final Widget child;
  final Duration duration;

  @override
  State<ThemeCrossFade> createState() => _ThemeCrossFadeState();
}

class _ThemeCrossFadeState extends State<ThemeCrossFade>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_handleStatus);
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves2.out,
  );
  late final Animation<double> _fadeOut = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).animate(_curved);

  ui.Image? _snapshot;
  Size? _snapshotSize;

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _clearSnapshot();
    }
  }

  void _clearSnapshot() {
    final image = _snapshot;
    if (image == null) return;
    _snapshot = null;
    _snapshotSize = null;
    image.dispose();
    if (mounted) setState(() {});
  }

  void _captureSnapshot() {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (disable ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _clearSnapshot();
      return;
    }
    final renderObject = _boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;
    if (!renderObject.hasSize ||
        renderObject.size.isEmpty ||
        renderObject.debugNeedsPaint) {
      return;
    }
    try {
      final dpr = (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0).clamp(
        1.0,
        2.0,
      );
      final next = renderObject.toImageSync(pixelRatio: dpr);
      _snapshot?.dispose();
      _snapshot = next;
      _snapshotSize = renderObject.size;
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    } catch (_) {
      _clearSnapshot();
    }
  }

  @override
  void didUpdateWidget(covariant ThemeCrossFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature != widget.signature) {
      _captureSnapshot();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final size = _snapshotSize;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null && size != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RawImage(
                image: snapshot,
                opacity: _fadeOut,
                width: size.width,
                height: size.height,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
      ],
    );
  }
}
