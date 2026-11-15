import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/persistence.dart';

/// 存储契约（ADR-001）：单文档 + 原子写 + 三代轮转 + 损坏回退。
void main() {
  late Directory tempDir;
  late LocalStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('my_hours_store_');
    store = LocalStore(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  StoreDocument sample({String remark = 'v1'}) => StoreDocument(
    records: [WorkDayRecord(date: '2026-08-01', hours: 8, remark: remark)],
    entries: const [
      LedgerEntry(
        id: 'e1',
        date: '2026-08-01',
        type: LedgerType.income,
        amount: 100,
        category: '工资',
      ),
    ],
    customCategories: const <CustomLedgerCategory>[],
    workProfiles: const [
      WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 20),
    ],
    budgetTargets: const BudgetTargets(monthlyExpenseBudget: 3000),
    exportedAt: '2026-08-16T00:00:00.000Z',
  );

  test('空目录返回 missing', () {
    final result = store.load();
    expect(result.status, LoadStatus.missing);
    expect(result.document, isNull);
  });

  test('保存后可完整读回', () {
    expect(store.save(sample()), isTrue);
    final result = store.load();
    expect(result.status, LoadStatus.ok);
    expect(result.source, 'main');
    final document = result.document!;
    expect(document.records.single.remark, 'v1');
    expect(document.entries.single.amount, 100);
    expect(document.workProfiles.single.hourlyRate, 20);
    expect(document.budgetTargets.monthlyExpenseBudget, 3000);
    expect(document.exportedAt, '2026-08-16T00:00:00.000Z');
  });

  test('主文档损坏时回退 .bak', () {
    store.save(sample(remark: 'first'));
    store.save(sample(remark: 'second'));
    // 主文档写坏
    store.mainFile.writeAsStringSync('{ broken');

    final result = store.load();
    expect(result.status, LoadStatus.ok);
    expect(result.source, 'bak');
    expect(result.document!.records.single.remark, 'first');
  });

  test('主与 .bak 都损坏时回退 .bak.1', () {
    store.save(sample(remark: 'first'));
    store.save(sample(remark: 'second'));
    store.save(sample(remark: 'third'));
    store.mainFile.writeAsStringSync('{ broken');
    store.backupFile.writeAsStringSync('{ also broken');

    final result = store.load();
    expect(result.status, LoadStatus.ok);
    expect(result.source, 'bak1');
    expect(result.document!.records.single.remark, 'first');
  });

  test('三代都损坏时返回 corrupted（不静默当成空数据）', () {
    store.save(sample());
    store.mainFile.writeAsStringSync('{');
    store.backupFile.writeAsStringSync('{');
    store.oldBackupFile.writeAsStringSync('{');

    final result = store.load();
    expect(result.status, LoadStatus.corrupted);
    expect(result.document, isNull);
  });

  test('轮转后 .bak 与 .bak.1 内容不同', () {
    store.save(sample(remark: 'one'));
    store.save(sample(remark: 'two'));
    store.save(sample(remark: 'three'));

    final bak = jsonDecode(store.backupFile.readAsStringSync()) as Map;
    final bak1 = jsonDecode(store.oldBackupFile.readAsStringSync()) as Map;
    final bakRemark = ((bak['records'] as List).first as Map)['remark'];
    final bak1Remark = ((bak1['records'] as List).first as Map)['remark'];
    expect(bakRemark, 'two');
    expect(bak1Remark, 'one');
  });

  test('recoveredFromBackup 只对「从备份回退」为 true', () {
    expect(
      recoveredFromBackup(const LoadResult(LoadStatus.missing, null)),
      isFalse,
    );

    store.save(sample());
    expect(recoveredFromBackup(store.load()), isFalse);

    store.save(sample(remark: 'second'));
    store.mainFile.writeAsStringSync('{ broken');
    final fallback = store.load();
    expect(fallback.source, 'bak');
    expect(recoveredFromBackup(fallback), isTrue);
  });

  test('从 .bak 回退后再保存，不会把损坏的主文件写进 .bak', () {
    store.save(sample(remark: 'first'));
    store.save(sample(remark: 'second'));
    // 主文档写坏，此时好数据只在 .bak 里
    store.mainFile.writeAsStringSync('{ broken');
    expect(store.load().source, 'bak');

    // 回退加载后保存新数据：坏 main 绝不能被轮转成 .bak
    expect(store.save(sample(remark: 'third')), isTrue);

    final bak = jsonDecode(store.backupFile.readAsStringSync()) as Map;
    expect(((bak['records'] as List).first as Map)['remark'], 'first');
    final result = store.load();
    expect(result.status, LoadStatus.ok);
    expect(result.source, 'main');
    expect(result.document!.records.single.remark, 'third');
  });

  test('内容未变化时不再轮转备份代', () {
    store.save(sample(remark: 'one'));
    store.save(sample(remark: 'two'));
    final bakBefore = store.backupFile.readAsStringSync();

    // 同一份内容重复保存（例如连点两次整月结算）：不应烧掉备份代。
    expect(store.save(sample(remark: 'two')), isTrue);
    expect(store.save(sample(remark: 'two')), isTrue);

    expect(store.backupFile.readAsStringSync(), bakBefore);
  });

  test('三代全坏后拒绝写入，坏文件原样保留；导入可作为恢复通道', () {
    store.save(sample(remark: 'first'));
    store.save(sample(remark: 'second'));
    store.mainFile.writeAsStringSync('{ broken');
    store.backupFile.writeAsStringSync('{ also broken');
    store.oldBackupFile.writeAsStringSync('{ third broken');

    final loaded = store.load();
    expect(loaded.status, LoadStatus.corrupted);
    expect(store.isQuarantined, isTrue);

    // 普通保存必须被拒绝：否则第一次写入就把坏字节轮进 .bak / .bak.1，
    // 「原文件没有被删除」的承诺在用户下一次点保存时就失效。
    expect(store.save(sample(remark: 'third')), isFalse);
    expect(store.mainFile.readAsStringSync(), '{ broken');
    expect(store.backupFile.readAsStringSync(), '{ also broken');
    expect(store.oldBackupFile.readAsStringSync(), '{ third broken');

    // 导入一份校验通过的备份是恢复通道，允许写入全新内容。
    expect(
      store.save(sample(remark: 'recovered'), overrideQuarantine: true),
      isTrue,
    );
    expect(store.load().document!.records.single.remark, 'recovered');
  });

  test('clear 会清除隔离态，之后可以重新写入', () {
    store.save(sample(remark: 'first'));
    store.save(sample(remark: 'second'));
    store.mainFile.writeAsStringSync('{ broken');
    store.backupFile.writeAsStringSync('{ also broken');
    store.oldBackupFile.writeAsStringSync('{ third broken');
    expect(store.load().status, LoadStatus.corrupted);
    expect(store.isQuarantined, isTrue);

    store.clear();

    expect(store.isQuarantined, isFalse);
    expect(store.save(sample(remark: 'after-clear')), isTrue);
    expect(store.load().document!.records.single.remark, 'after-clear');
  });

  test('preserveSnapshot 在覆盖前按时间戳留一份', () {
    store.save(sample(remark: 'before-import'));
    final saved = store.preserveSnapshot('20261114-120000');

    expect(saved, hasLength(1));
    expect(saved.single, contains('my-hours.main.20261114-120000.json'));
    final preserved = File(saved.single).readAsStringSync();
    expect(preserved, contains('before-import'));
  });

  test('clear 删除主文档与两代备份', () {
    store.save(sample());
    store.clear();
    expect(store.mainFile.existsSync(), isFalse);
    expect(store.backupFile.existsSync(), isFalse);
    expect(store.oldBackupFile.existsSync(), isFalse);
    expect(store.load().status, LoadStatus.missing);
  });

  test('每日自动快照按天去重并只保留最近 7 天', () {
    store.save(sample());
    final first = store.createDailySnapshot(now: DateTime(2026, 11, 1, 8, 30));
    expect(first, isNotNull);
    expect(store.createDailySnapshot(now: DateTime(2026, 11, 1, 21)), first);

    for (var day = 2; day <= 9; day++) {
      expect(
        store.createDailySnapshot(now: DateTime(2026, 11, day, 8)),
        isNotNull,
      );
    }

    final snapshots = store.listAutoSnapshots();
    expect(snapshots, hasLength(7));
    expect(File(first!).existsSync(), isFalse);
    expect(snapshots.every((item) => item.bytes > 0), isTrue);
  });

  test('clear 同时删除自动快照和导入前现场副本', () {
    store.save(sample());
    final auto = store.createDailySnapshot(now: DateTime(2026, 11, 14, 9));
    final preserved = store.preserveSnapshot('20261114-120000').single;

    store.clear();

    expect(auto, isNotNull);
    expect(File(auto!).existsSync(), isFalse);
    expect(File(preserved).existsSync(), isFalse);
    expect(store.listAutoSnapshots(), isEmpty);
  });

  test('版本不符视为损坏（不误读其它格式）', () {
    store.mainFile.writeAsStringSync(
      jsonEncode({
        'app': 'my-hours',
        'version': 3,
        'records': <Object?>[],
        'entries': <Object?>[],
      }),
    );
    expect(store.load().status, LoadStatus.corrupted);
  });

  test('本机文档读取时会校验、去重并补齐默认工作', () {
    store.mainFile.writeAsStringSync(
      jsonEncode({
        'app': 'my-hours',
        'version': 4,
        'exportedAt': '2026-08-16T00:00:00.000Z',
        'records': [
          {'date': '2026-08-01', 'hours': 8},
          {'date': '2026-08-01', 'hours': 9},
        ],
        'entries': <Object?>[],
        'customCategories': <Object?>[],
        'workProfiles': <Object?>[],
        'budgetTargets': {
          'monthlyExpenseBudget': -1,
          'monthlyIncomeGoal': 3000,
        },
      }),
    );

    final result = store.load();
    expect(result.status, LoadStatus.ok);
    expect(result.document!.records, hasLength(1));
    expect(result.document!.records.single.hours, 9);
    expect(result.document!.workProfiles.single.id, 'work-default');
    expect(result.document!.budgetTargets.monthlyExpenseBudget, 0);
    expect(result.document!.budgetTargets.monthlyIncomeGoal, 3000);
  });

  test('本机文档中的非法记录不会被静默读入', () {
    store.mainFile.writeAsStringSync(
      jsonEncode({
        'app': 'my-hours',
        'version': 4,
        'records': [
          {'date': 'not-a-date', 'hours': 8},
        ],
        'entries': <Object?>[],
        'customCategories': <Object?>[],
        'workProfiles': <Object?>[],
        'budgetTargets': <String, Object?>{},
      }),
    );

    expect(store.load().status, LoadStatus.corrupted);
  });
}
