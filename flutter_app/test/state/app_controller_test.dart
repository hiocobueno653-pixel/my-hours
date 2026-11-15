import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/data/models.dart';
import 'package:my_hours/data/persistence.dart';
import 'package:my_hours/data/records.dart';
import 'package:my_hours/state/app_controller.dart';

/// 写操作口径：时薪快照、0 元结算、旧版关联收入。
void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('my_hours_state_');
    container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(LocalStore(dir))],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  AppController ctrl() => container.read(appControllerProvider.notifier);
  AppState st() => container.read(appControllerProvider);

  ParsedBackupData backup({
    List<WorkDayRecord> records = const [],
    List<LedgerEntry> entries = const [],
    List<WorkProfile> profiles = const [
      WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 20),
    ],
  }) => ParsedBackupData(
    records: records,
    entries: entries,
    customCategories: const [],
    workProfiles: profiles,
    budgetTargets: const BudgetTargets(),
  );

  test(
    '改时薪固化已结算记录的快照，未结算记录跟随新价',
    skip: kHoursOnly ? '只记工时变体不生成工资账目' : false,
    () {
      ctrl().replaceAll(
        backup(
          records: const [
            WorkDayRecord(date: '2026-08-03', hours: 8, settled: true),
            WorkDayRecord(date: '2026-08-04', hours: 8),
          ],
        ),
      );
      expect(
        st().entries.firstWhere((e) => e.id == 'wage-2026-08-03').amount,
        160,
      );

      final ok = ctrl().saveWorkProfile(
        const WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 30),
      );
      expect(ok, isTrue);

      final settled = st().records.firstWhere((r) => r.date == '2026-08-03');
      final pending = st().records.firstWhere((r) => r.date == '2026-08-04');
      // 已结算：旧价固化，工资与账目都不漂移
      expect(settled.rate, 20);
      expect(
        st().entries.firstWhere((e) => e.id == 'wage-2026-08-03').amount,
        160,
      );
      // 未结算：还没付钱，跟随新时薪
      expect(pending.rate, isNull);
    },
  );

  test('0 工资的一天不能被标记结算', () {
    ctrl().saveDay('2026-08-05', 0, '');

    expect(ctrl().setRecordSettled('2026-08-05', true), isFalse);
    expect(st().records.single.settled, isFalse);
  });

  test('撤销本月结算会清掉 0 元日的历史脏标记', () {
    ctrl().replaceAll(
      backup(
        records: const [
          WorkDayRecord(date: '2026-08-06', hours: 0, settled: true),
        ],
      ),
    );
    expect(st().records.single.settled, isTrue);

    ctrl().settleMonth('2026-08', false);
    expect(st().records.single.settled, isFalse);
  });

  test('saveDay 不会写下 0 元已结算的脏记录', () {
    ctrl().saveDay('2026-08-09', 0, '', settled: true);

    expect(st().records.single.settled, isFalse);
  });

  test('整月结算也会清掉 0 元日的历史脏标记', () {
    ctrl().replaceAll(
      backup(
        records: const [
          WorkDayRecord(date: '2026-08-10', hours: 0, settled: true),
        ],
      ),
    );

    ctrl().settleMonth('2026-08', true);

    expect(st().records.single.settled, isFalse);
  });

  test(
    '结算时固化时薪快照，之后改时薪不影响已结算金额',
    skip: kHoursOnly ? '只记工时变体不生成工资账目' : false,
    () {
      ctrl().replaceAll(
        backup(records: const [WorkDayRecord(date: '2026-08-11', hours: 8)]),
      );
      expect(getMonthPay(st().records, '2026-08', st().workProfiles), 160);

      ctrl().setRecordSettled('2026-08-11', true);
      expect(st().records.single.rate, 20);

      ctrl().saveWorkProfile(
        const WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 30),
      );

      // 已结算：快照锁在结算那一刻的价，工资面板与账本都不漂移。
      expect(st().records.single.rate, 20);
      expect(getMonthPay(st().records, '2026-08', st().workProfiles), 160);
      expect(
        st().entries.firstWhere((e) => e.id == 'wage-2026-08-11').amount,
        160,
      );
    },
  );

  test('删除工作时把旧价固化到已结算记录', () {
    ctrl().replaceAll(
      backup(
        records: const [
          WorkDayRecord(
            date: '2026-08-12',
            hours: 8,
            workId: 'work-2',
            settled: true,
          ),
        ],
        profiles: const [
          WorkProfile(id: 'work-default', name: '默认工作', hourlyRate: 10),
          WorkProfile(id: 'work-2', name: '兼职', hourlyRate: 50),
        ],
      ),
    );
    expect(getMonthPay(st().records, '2026-08', st().workProfiles), 400);

    ctrl().deleteWorkProfile('work-2');

    expect(st().records.single.workId, isNull);
    expect(st().records.single.rate, 50);
    expect(getMonthPay(st().records, '2026-08', st().workProfiles), 400);
  });

  test('存档全坏时导入备份仍能恢复', () {
    final store = container.read(storeProvider);
    store.mainFile.writeAsStringSync('{ broken');
    store.load();
    expect(store.isQuarantined, isTrue);

    final written = ctrl().replaceAll(
      backup(records: const [WorkDayRecord(date: '2026-08-13', hours: 8)]),
    );

    expect(written, isTrue);
    expect(st().records, hasLength(1));
    expect(store.load().status, LoadStatus.ok);
  });

  test('隔离态下普通写操作被拦截，导入恢复后解除只读', () {
    final store = container.read(storeProvider);
    store.mainFile.writeAsStringSync('{ broken');
    store.backupFile.writeAsStringSync('{ broken too');
    store.oldBackupFile.writeAsStringSync('{ still broken');
    expect(store.load().status, LoadStatus.corrupted);
    expect(store.isQuarantined, isTrue);

    ctrl().saveDay('2026-08-14', 8, '只读测试');

    expect(st().records, isEmpty);
    expect(container.read(saveFailureProvider)?.quarantined, isTrue);
    expect(container.read(archiveReadOnlyProvider), isTrue);

    expect(
      ctrl().replaceAll(
        backup(records: const [WorkDayRecord(date: '2026-08-14', hours: 8)]),
      ),
      isTrue,
    );
    expect(st().records, hasLength(1));
    expect(container.read(archiveReadOnlyProvider), isFalse);
    expect(container.read(saveFailureProvider), isNull);
    expect(store.load().status, LoadStatus.ok);
  });

  test('保存工时时清掉旧版「同时记收入」，避免账本双计', skip: kHoursOnly ? '只记工时变体不维护账本' : false, () {
    ctrl().replaceAll(
      backup(
        records: const [WorkDayRecord(date: '2026-08-07', hours: 8)],
        entries: const [
          LedgerEntry(
            id: 'legacy-1',
            date: '2026-08-07',
            type: LedgerType.income,
            amount: 100,
            category: '工资',
            workDate: '2026-08-07',
          ),
        ],
      ),
    );
    expect(st().entries.any((e) => e.id == 'legacy-1'), isTrue);

    ctrl().saveDay('2026-08-07', 8, '');

    expect(st().entries.any((e) => e.id == 'legacy-1'), isFalse);
  });

  test('连续编辑 300ms 内合并，flush 后只落盘最终状态', () {
    final store = container.read(storeProvider);
    ctrl().saveDay('2026-08-15', 1, 'first');
    ctrl().saveDay('2026-08-15', 2, 'second');

    expect(store.mainFile.existsSync(), isFalse);
    expect(ctrl().flushPendingPersist(), isTrue);

    final result = store.load();
    expect(result.status, LoadStatus.ok);
    expect(result.document!.records.single.hours, 2);
    expect(result.document!.records.single.remark, 'second');
  });
}
