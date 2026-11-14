/// 返回键栈。
///
/// 对齐旧版 `src/navigation/backNavigation.ts` 的语义：
/// 弹层（sheet/dialog）先消费返回键 → 非「记工」tab 回到「记工」→
/// 根页 2 秒内再按一次才退出。弹层消费返回时**重置双击计时**，
/// 避免「关弹层的那一下」被算作退出序列的第一击。
library;

import 'package:flutter/foundation.dart';

typedef BackHandler = bool Function();

class BackNavigation {
  BackNavigation._();

  static final List<Object> _tokens = <Object>[];
  static final Map<Object, BackHandler> _handlers = <Object, BackHandler>{};

  /// 注册一个可消费返回键的层级（越晚注册越先消费）。
  static void register(Object token, BackHandler handler) {
    _handlers[token] = handler;
    _tokens
      ..remove(token)
      ..add(token);
  }

  static void unregister(Object token) {
    _handlers.remove(token);
    _tokens.remove(token);
  }

  static bool get hasHandler => _tokens.isNotEmpty;

  /// 派发给最上层；返回 true 表示已被消费。
  static bool dispatch() {
    if (_tokens.isEmpty) return false;
    final token = _tokens.last;
    final handler = _handlers[token];
    if (handler == null) {
      _tokens.remove(token);
      return dispatch();
    }
    final consumed = handler();
    if (consumed) {
      debugPrint('[back] consumed by ${token.runtimeType}');
    }
    return consumed;
  }

  @visibleForTesting
  static void reset() {
    _tokens.clear();
    _handlers.clear();
  }
}
