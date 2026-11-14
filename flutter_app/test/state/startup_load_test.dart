import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/state/app_controller.dart';

class _CountingStore extends LocalStore {
  _CountingStore(super.directory);

  var loadCount = 0;

  @override
  LoadResult load() {
    loadCount += 1;
    return const LoadResult(LoadStatus.missing, null);
  }
}

void main() {
  test('启动只读取一次本地文档', () {
    final directory = Directory.systemTemp.createTempSync('my-hours-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = _CountingStore(directory);
    final container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final state = container.read(appControllerProvider);

    expect(store.loadCount, 1);
    expect(state.workProfiles, isNotEmpty);
  });
}
