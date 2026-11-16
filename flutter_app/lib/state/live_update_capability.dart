import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 这台设备能不能把计时通知放进状态栏胶囊。
///
/// 分界线是 Android 16（API 36）的 Live Updates：
/// - 36+：通知带短关键文本即可进胶囊，所有厂商通用；
/// - 34/35：只有普通常驻通知，厂商自己的「流体云 / 灵动胶囊」是另一套
///   私有通道，需要单独申请，用标准 API 进不去。
class LiveUpdateCapability {
  const LiveUpdateCapability({
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
  });

  final int sdkInt;
  final String manufacturer;
  final String model;

  /// 系统原生支持胶囊。
  bool get supported => sdkInt >= 36;

  /// 厂商私有通道（流体云 / 原子通知 / 焦点通知 / 灵动胶囊）。
  ///
  /// 这些不在标准 API 里，本应用没有接入；这里只用于如实说明，
  /// 不给用户「看起来支持」的错觉。
  String? get vendorChannel {
    final m = manufacturer.toLowerCase();
    if (m.contains('oppo') || m.contains('oneplus') || m.contains('realme')) {
      return 'ColorOS 流体云';
    }
    if (m.contains('vivo') || m.contains('iqoo')) return '原子通知';
    if (m.contains('xiaomi') || m.contains('redmi')) return '焦点通知';
    if (m.contains('honor')) return '灵动胶囊';
    return null;
  }

  String get summary {
    if (supported) return '已支持状态栏胶囊（Android 16+）';
    final vendor = vendorChannel;
    final base = 'Android $sdkInt · 仅常驻通知';
    return vendor == null ? base : '$base（$vendor 需单独接入）';
  }

  static const fallback = LiveUpdateCapability(
    sdkInt: 0,
    manufacturer: '',
    model: '',
  );
}

final liveUpdateCapabilityProvider =
    FutureProvider<LiveUpdateCapability>((ref) async {
      try {
        const channel = MethodChannel('com.myhours.app/timer');
        final raw = await channel.invokeMapMethod<String, Object?>(
          'capabilities',
        );
        if (raw == null) return LiveUpdateCapability.fallback;
        return LiveUpdateCapability(
          sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 0,
          manufacturer: raw['manufacturer'] as String? ?? '',
          model: raw['model'] as String? ?? '',
        );
      } on MissingPluginException {
        return LiveUpdateCapability.fallback;
      } on PlatformException {
        return LiveUpdateCapability.fallback;
      }
    });
