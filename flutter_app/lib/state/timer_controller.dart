import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';

/// 正在进行的计时。
///
/// 只记「从什么时候开始」和「此前累计了多久」，当前已用时长由
/// [elapsed] 现算。这样进程被杀、手机重启都不会让计时漂移——恢复时
/// 用 `DateTime.now() - startedAt` 就能对上，不需要每秒写盘。
class ActiveTimer {
  const ActiveTimer({
    required this.date,
    this.workId,
    this.startedAt,
    this.accumulatedMs = 0,
  });

  /// 归属日期（开始计时那天），跨零点不拆。
  final String date;

  /// 关联的工作；null 表示默认工作。
  final String? workId;

  /// 本轮开始时刻；null 表示已暂停。
  final DateTime? startedAt;

  /// 暂停之前累计的毫秒数。
  final int accumulatedMs;

  bool get running => startedAt != null;

  /// 已用时长。
  Duration get elapsed {
    final base = Duration(milliseconds: accumulatedMs);
    final start = startedAt;
    if (start == null) return base;
    final delta = DateTime.now().difference(start);
    // 系统时间被往回调时不倒扣：负数按 0 处理。
    return base + (delta.isNegative ? Duration.zero : delta);
  }

  /// 折合小时，两位小数——与 `WorkDayRecord.hours` 同口径。
  double get hours {
    final value = elapsed.inMilliseconds / 3600000;
    return (value * 100).roundToDouble() / 100;
  }

  ActiveTimer copyWith({
    String? date,
    Object? workId = _sentinel,
    Object? startedAt = _sentinel,
    int? accumulatedMs,
  }) {
    return ActiveTimer(
      date: date ?? this.date,
      workId: workId == _sentinel ? this.workId : workId as String?,
      startedAt: startedAt == _sentinel
          ? this.startedAt
          : startedAt as DateTime?,
      accumulatedMs: accumulatedMs ?? this.accumulatedMs,
    );
  }

  Map<String, Object?> toJson() => {
    'date': date,
    'workId': workId,
    'startedAt': startedAt?.toIso8601String(),
    'accumulatedMs': accumulatedMs,
  };

  static ActiveTimer? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final date = map['date'];
      if (date is! String || date.isEmpty) return null;
      return ActiveTimer(
        date: date,
        workId: map['workId'] as String?,
        startedAt: DateTime.tryParse(map['startedAt'] as String? ?? ''),
        accumulatedMs: (map['accumulatedMs'] as num?)?.toInt() ?? 0,
      );
    } on FormatException {
      return null;
    }
  }

  bool get isIdle => !running && accumulatedMs == 0;
}

const Object _sentinel = Object();

/// 计时状态。
///
/// 每次开始 / 暂停 / 停止才落盘，秒级刷新只在内存里算。
class TimerController extends Notifier<ActiveTimer?> {
  @override
  ActiveTimer? build() {
    // 单元测试只 override 了 storeProvider，没有 settingsProvider。
    // 计时是可选能力，取不到就当「没在计时」，不要让整页崩掉。
    try {
      return ActiveTimer.fromJson(_read());
    } on Object {
      return null;
    }
  }

  String? _read() => ref.read(settingsProvider).timerSnapshot;

  /// 和 Android 前台服务同步「是否在计时」。
  ///
  /// 只传三个时刻的快照，不传秒数：通知里的秒由 SystemUI 的
  /// Chronometer 自己走，不需要我们每秒唤醒进程。
  static const _channel = MethodChannel('com.myhours.app/timer');

  Future<void> _syncNotification(ActiveTimer? timer) async {
    try {
      if (timer == null) {
        await _channel.invokeMethod<void>('stop');
      } else {
        await _channel.invokeMethod<void>('start', {
          'elapsedMs': timer.elapsed.inMilliseconds,
          'label': timer.running ? '正在计时' : '已暂停',
          'running': timer.running,
        });
      }
    } on MissingPluginException {
      // 非 Android 平台（或未注册）时静默跳过。
    } on PlatformException {
      // 通知发不出去不影响计时本身，界面上的读数仍然正确。
    }
  }

  void _persist(ActiveTimer? timer) {
    try {
      unawaited(
        ref.read(settingsProvider).setTimerSnapshot(timer?.toJsonString()),
      );
    } on Object {
      // 同上：持久化缺席不影响本次会话的计时读数。
    }
    state = timer;
    unawaited(_syncNotification(timer));
  }

  /// 开始或继续。
  void start({required String date, String? workId}) {
    final current = state;
    if (current == null || current.date != date) {
      _persist(
        ActiveTimer(date: date, workId: workId, startedAt: DateTime.now()),
      );
      return;
    }
    if (current.running) return;
    _persist(
      current.copyWith(
        startedAt: DateTime.now(),
        workId: workId ?? current.workId,
      ),
    );
  }

  /// 暂停：把当前这轮时长并入累计。
  void pause() {
    final current = state;
    if (current == null || !current.running) return;
    _persist(
      current.copyWith(
        accumulatedMs: current.elapsed.inMilliseconds,
        startedAt: null,
      ),
    );
  }

  /// 状态栏用的短文本：`1:23:45` / `12:34`。
  String get shortText {
    final timer = state;
    if (timer == null) return '';
    final total = timer.elapsed.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// 停止并返回折合小时（供调用方写入当天记录），随后清空状态。
  double stopAndClear() {
    final timer = state;
    if (timer == null) return 0;
    final hours = timer.hours;
    _persist(null);
    return hours;
  }

  /// 放弃本轮，不写入。
  void discard() => _persist(null);
}

extension on ActiveTimer {
  String toJsonString() => jsonEncode(toJson());
}

final timerProvider = NotifierProvider<TimerController, ActiveTimer?>(
  TimerController.new,
);
