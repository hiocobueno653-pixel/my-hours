/// 应用状态与全部写操作。
///
/// 与 `src/store/useAppStore.ts` 等价。三条不变量：
/// 1. **先落盘再 set**：任何写操作都先 `store.save(...)`，成功与否都不改变内存状态
///    的最终值（失败只记日志），保证 UI 不会显示未持久化的数据；
/// 2. **对账只在写操作内发生**：`syncWageEntries` / `syncWageEntryForDate` 是工资账目
///    的唯一来源，UI 不直接改工资账目；
/// 3. **`HOURS_ONLY` 分支**：只记工时变体不生成、不对账工资账目（结算只是标记）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/constants.dart';
import '../data/ledger.dart';
import '../data/models.dart';
import '../data/persistence.dart';
import '../data/profiles.dart';
import '../data/records.dart';
import '../data/wage_entries.dart';

/// 「只记工时」变体开关（`--dart-define=HOURS_ONLY=true`）。
const bool kHoursOnly = bool.fromEnvironment('HOURS_ONLY');

class AppState {
  const AppState({
    required this.records,
    required this.entries,
    required this.customCategories,
    required this.workProfiles,
    required this.budgetTargets,
  });

  final List<WorkDayRecord> records;
  final List<LedgerEntry> entries;
  final List<CustomLedgerCategory> customCategories;
  final List<WorkProfile> workProfiles;
  final BudgetTargets budgetTargets;

  static const empty = AppState(
    records: [],
    entries: [],
    customCategories: [],
    workProfiles: [],
    budgetTargets: BudgetTargets(),
  );

  AppState copyWith({
    List<WorkDayRecord>? records,
    List<LedgerEntry>? entries,
    List<CustomLedgerCategory>? customCategories,
    List<WorkProfile>? workProfiles,
    BudgetTargets? budgetTargets,
  }) {
    return AppState(
      records: records ?? this.records,
      entries: entries ?? this.entries,
      customCategories: customCategories ?? this.customCategories,
      workProfiles: workProfiles ?? this.workProfiles,
      budgetTargets: budgetTargets ?? this.budgetTargets,
    );
  }

  StoreDocument toDocument() => StoreDocument(
    records: records,
    entries: entries,
    customCategories: customCategories,
    workProfiles: workProfiles,
    budgetTargets: budgetTargets,
  );

  static AppState fromDocument(StoreDocument document) => AppState(
    records: document.records,
    entries: document.entries,
    customCategories: document.customCategories,
    workProfiles: document.workProfiles,
    budgetTargets: document.budgetTargets,
  );
}

/// 由 `main.dart` 覆盖为真实目录。
final storeProvider = Provider<LocalStore>(
  (ref) => throw StateError('storeProvider 必须在 ProviderScope 中覆盖'),
);

/// 启动时只读取一次本地文档；`main.dart` 会把这个结果注入，
/// 避免 AppController 再同步读一遍磁盘。
final startupLoadProvider = Provider<LoadResult>(
  (ref) => ref.read(storeProvider).load(),
);

/// 主文档与两代备份都损坏时为 true；由启动层提示用户，避免静默当成空数据。
final startupCorruptionProvider = Provider<bool>((ref) => false);

/// 启动时主文件不可读、已从 `.bak` / `.bak.1` 回退成功时为 true。
///
/// 回退本身是对的，但用户必须在场知道「最近一次改动可能不在」，
/// 否则只会觉得数据莫名少了一天。
final startupRecoveredProvider = Provider<bool>((ref) => false);

/// 存档处于隔离态（主文件与两代备份都不可读）时为 true。
///
/// 此时存储层会拒绝一切普通写入（只有导入备份能写），UI 必须说明原因，
/// 否则用户只会看到「点了保存，重开就没了」。
final archiveReadOnlyProvider = Provider<bool>(
  (ref) => ref.watch(storeProvider).isQuarantined,
);

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  late LocalStore _store;

  @override
  AppState build() {
    _store = ref.read(storeProvider);
    final loaded = ref.read(startupLoadProvider);
    final document = loaded.document;
    if (document == null) {
      return AppState.empty.copyWith(
        workProfiles: ensureDefaultWorkProfile(const []),
      );
    }

    var state = AppState.fromDocument(document);
    // 启动对账：已结算但缺工资账目的补齐（只记工时变体跳过）
    if (!kHoursOnly) {
      final synced = syncWageEntries(
        state.records,
        state.entries,
        state.workProfiles,
      );
      if (!identical(synced, state.entries)) {
        state = state.copyWith(entries: synced);
        _persist(state);
      }
    }
    return state;
  }

  /// 落盘。返回是否成功。
  ///
  /// 失败不阻断内存状态推进（否则一次磁盘错误会让界面反复回滚），
  /// 但必须留痕：之前丢弃 `save` 的返回值，写盘失败时 UI 仍提示成功。
  bool _persist(AppState next, {bool overrideQuarantine = false}) {
    final ok = _store.save(
      next.toDocument(),
      overrideQuarantine: overrideQuarantine,
    );
    if (!ok) {
      debugPrint('[my-hours] 本地存储写入失败；本次改动仅在内存中生效');
    } else {
      // 每天最多留一份；空数据由存储层跳过。
      _store.createDailySnapshot();
    }
    return ok;
  }

  // ---- 记工 ----

  void saveDay(
    String date,
    double hours,
    String remark, {
    String? workId,
    double? rate,
    double? fixedPay,
    bool settled = false,
  }) {
    var record = WorkDayRecord(
      date: date,
      hours: roundMoney(hours),
      remark: remark,
    );
    final normalizedWorkId = workId?.trim();
    if (normalizedWorkId != null &&
        normalizedWorkId.isNotEmpty &&
        normalizedWorkId != defaultWorkId) {
      record = record.copyWith(workId: normalizedWorkId);
    }
    if (rate != null && rate.isFinite && rate > 0 && rate <= maxHourlyRate) {
      record = record.copyWith(rate: roundMoney(rate));
    }
    if (fixedPay != null &&
        fixedPay.isFinite &&
        fixedPay >= 0 &&
        fixedPay <= maxFixedPay) {
      record = record.copyWith(fixedPay: roundMoney(fixedPay));
    }
    // 结算标记也要过工资口径：0 元日没有可结算金额，任何入口
    // （日编辑器、删除撤销恢复）都不该写出 settled=true 的脏记录。
    if (settled && recordPay(record, state.workProfiles) > 0) {
      record = record.copyWith(settled: true);
    }

    final nextRecords = dedupeRecords([
      for (final item in state.records)
        if (item.date != date) item,
      record,
    ]);
    // 旧版「同时记收入」遗留的关联收入必须在保存时清掉：它不看结算态，
    // 否则未结算/工资为 0 的那天会同时留着旧收入与（之后的）工资账目。
    final nextEntries = kHoursOnly
        ? state.entries
        : dropLegacyLinkedIncomeForDate(
            syncWageEntryForDate(
              nextRecords,
              state.entries,
              state.workProfiles,
              date,
            ),
            date,
          );
    final next = state.copyWith(records: nextRecords, entries: nextEntries);
    _persist(next);
    state = next;
  }

  /// 删除某天记录，返回被删除的系统工资账目（供撤销恢复）。
  LedgerEntry? deleteDay(String date) {
    final nextRecords = [
      for (final record in state.records)
        if (record.date != date) record,
    ];
    LedgerEntry? removed;
    for (final entry in state.entries) {
      if (isWageEntryForDate(entry, date)) {
        removed = entry;
        break;
      }
    }
    final nextEntries = kHoursOnly
        ? state.entries
        : syncWageEntryForDate(
            nextRecords,
            state.entries,
            state.workProfiles,
            date,
          );
    final next = state.copyWith(records: nextRecords, entries: nextEntries);
    _persist(next);
    state = next;
    return removed;
  }

  /// 结算瞬间把有效时薪固化成快照。
  ///
  /// 不固化的话，「已结算」记录的金额只靠「当前时薪」推导：之后改时薪、
  /// 删工作都会让 `recordPay` 变，而 `syncWageEntries` 不更新既有账目金额，
  /// 工资面板与账本收入就永久分叉。固化后两边都锁在结算那一刻的价上。
  WorkDayRecord _pinRate(WorkDayRecord record) {
    if (record.fixedPay != null) return record;
    final existing = record.rate;
    if (existing != null && existing > 0) return record;
    final rate = effectiveRate(record, state.workProfiles);
    return rate > 0 ? record.copyWith(rate: rate) : record;
  }

  /// 标记某天结算状态，返回是否真的改了。
  ///
  /// 工资为 0 的一天没有可结算金额：正向标记直接拒绝，避免出现
  /// 「已结算但 0 元」这种与工资面板口径矛盾的脏状态（面板按 `pay <= 0`
  /// 过滤，撤销也覆盖不到它）。反向取消始终允许，用来清历史脏标记。
  bool setRecordSettled(String date, bool settled) {
    final target = getRecordByDate(state.records, date);
    if (target == null) return false;
    if (settled && recordPay(target, state.workProfiles) <= 0) return false;
    if (target.settled == settled) return false;

    final nextRecords = dedupeRecords([
      for (final record in state.records)
        if (record.date == date)
          settled
              ? _pinRate(record).copyWith(settled: true)
              : record.copyWith(settled: false)
        else
          record,
    ]);
    final nextEntries = kHoursOnly
        ? state.entries
        : syncWageEntryForDate(
            nextRecords,
            state.entries,
            state.workProfiles,
            date,
          );
    final next = state.copyWith(records: nextRecords, entries: nextEntries);
    _persist(next);
    state = next;
    return true;
  }

  /// 整月结算 / 撤销结算。
  ///
  /// 跳过 `pay <= 0` 的记录（没有可结算金额），并顺手清掉它们身上可能
  /// 残留的历史 `settled` 标记——否则这类记录永远既不在待结算里，
  /// 也无法被批量撤销命中。
  void settleMonth(String yearMonth, bool settled) {
    final prefix = '$yearMonth-';
    final nextRecords = dedupeRecords([
      for (final record in state.records)
        if (!record.date.startsWith(prefix))
          record
        else if (recordPay(record, state.workProfiles) <= 0)
          record.settled ? record.copyWith(settled: false) : record
        else
          settled
              ? _pinRate(record).copyWith(settled: true)
              : record.copyWith(settled: false),
    ]);

    final nextEntries = kHoursOnly
        ? state.entries
        : syncWageEntries(nextRecords, state.entries, state.workProfiles);
    final next = state.copyWith(records: nextRecords, entries: nextEntries);
    _persist(next);
    state = next;
  }

  // ---- 记账 ----

  void saveLedgerEntry(LedgerEntry entry) {
    final nextEntries = dedupeLedgerEntries([
      for (final item in state.entries)
        if (item.id != entry.id) item,
      entry,
    ]);
    final next = state.copyWith(entries: nextEntries);
    _persist(next);
    state = next;
  }

  /// 删除一条账目，返回被删除的条目（供撤销）。
  LedgerEntry? deleteLedgerEntry(String id) {
    LedgerEntry? removed;
    for (final entry in state.entries) {
      if (entry.id == id) {
        removed = entry;
        break;
      }
    }
    final nextEntries = [
      for (final entry in state.entries)
        if (entry.id != id) entry,
    ];
    final next = state.copyWith(entries: nextEntries);
    _persist(next);
    state = next;
    return removed;
  }

  // ---- 分类 ----

  bool addCustomCategory(LedgerType type, String name) {
    final trimmed = name.trim();
    final normalized = trimmed.length <= maxCategoryNameLength
        ? trimmed
        : trimmed.substring(0, maxCategoryNameLength);
    if (normalized.isEmpty) return false;
    if (defaultCategoriesOf(type).contains(normalized)) return false;
    final duplicate = state.customCategories.any(
      (category) => category.type == type && category.name == normalized,
    );
    if (duplicate) return false;

    final nextCategories = dedupeLedgerCategories([
      ...state.customCategories,
      CustomLedgerCategory(
        id: createId('category'),
        type: type,
        name: normalized,
      ),
    ]);
    final next = state.copyWith(customCategories: nextCategories);
    _persist(next);
    state = next;
    return true;
  }

  bool deleteCustomCategory(String id) {
    CustomLedgerCategory? target;
    for (final category in state.customCategories) {
      if (category.id == id) {
        target = category;
        break;
      }
    }
    if (target == null) return false;
    if (isLedgerCategoryInUse(state.entries, target.type, target.name)) {
      return false;
    }
    final nextCategories = [
      for (final category in state.customCategories)
        if (category.id != id) category,
    ];
    final next = state.copyWith(customCategories: nextCategories);
    _persist(next);
    state = next;
    return true;
  }

  // ---- 工作 ----

  /// 保存（新增或覆写）一份工作，返回是否成功。
  ///
  /// 改时薪时先把**旧时薪固化**到该工作下「已结算且没有快照」的记录上：
  /// 这些记录已经按旧价付过钱，工资与账目都不该随新价漂移（面板文案
  /// 「之后改时薪不影响历史工资」由此成立）。未结算记录不固化，
  /// 它们还没付钱，理应跟随新时薪重算。
  bool saveWorkProfile(WorkProfile profile) {
    final trimmed = profile.name.trim();
    final normalizedName = trimmed.length <= maxWorkNameLength
        ? trimmed
        : trimmed.substring(0, maxWorkNameLength);
    if (normalizedName.isEmpty) return false;
    final duplicate = state.workProfiles.any(
      (item) => item.id != profile.id && item.name == normalizedName,
    );
    if (duplicate) return false;

    final previous = getWorkById(state.workProfiles, profile.id);
    final previousRate = previous?.hourlyRate ?? 0;
    final rateChanged =
        previous != null &&
        previousRate > 0 &&
        (previousRate - profile.hourlyRate).abs() > decimalTolerance;

    final nextRecords = rateChanged
        ? dedupeRecords([
            for (final record in state.records)
              if ((record.workId ?? defaultWorkId) == profile.id &&
                  record.rate == null &&
                  record.settled)
                record.copyWith(rate: previousRate)
              else
                record,
          ])
        : state.records;

    final nextProfiles = ensureDefaultWorkProfile(
      dedupeWorkProfiles([
        for (final item in state.workProfiles)
          if (item.id != profile.id) item,
        profile.copyWith(name: normalizedName),
      ]),
    );
    final next = state.copyWith(
      records: nextRecords,
      workProfiles: nextProfiles,
    );
    _persist(next);
    state = next;
    return true;
  }

  void deleteWorkProfile(String id) {
    if (id == defaultWorkId) return;
    final previousRate = getWorkById(state.workProfiles, id)?.hourlyRate ?? 0;
    // 关联记录归回默认工作；同时把旧价固化到「已结算且无快照」的记录上，
    // 否则归回默认工作后 recordPay 会按默认时薪重算，已结算金额当场漂移。
    final nextRecords = dedupeRecords([
      for (final record in state.records)
        if (record.workId != id)
          record
        else
          record.copyWith(
            clearWorkId: true,
            rate: (previousRate > 0 && record.rate == null && record.settled)
                ? previousRate
                : null,
          ),
    ]);
    final nextProfiles = ensureDefaultWorkProfile([
      for (final profile in state.workProfiles)
        if (profile.id != id) profile,
    ]);
    final next = state.copyWith(
      records: nextRecords,
      workProfiles: nextProfiles,
    );
    _persist(next);
    state = next;
  }

  // ---- 预算 / 全局 ----

  void saveBudgetTargets(BudgetTargets targets) {
    final normalized = normalizeBudgetTargets(targets.toJson());
    final next = state.copyWith(budgetTargets: normalized);
    _persist(next);
    state = next;
  }

  void clearAll() {
    _store.clear();
    final next = AppState.empty.copyWith(
      workProfiles: ensureDefaultWorkProfile(const []),
    );
    _persist(next);
    state = next;
  }

  /// 导入备份（调用方已通过 `parseBackupText` 严格校验），返回是否落盘成功。
  ///
  /// 覆盖前先把现有 main/.bak/.bak1 按时间戳各留一份：导入不可逆，
  /// 选错文件时这是唯一的回头路。隔离态下导入是唯一恢复通道，
  /// 因此允许写入全新内容（但仍不会轮转那三份坏文件）。
  bool replaceAll(ParsedBackupData data) {
    _store.preserveSnapshot(snapshotStamp());
    final next = resolveImportedState(data);
    final ok = _persist(next, overrideQuarantine: true);
    state = next;
    return ok;
  }
}

/// 快照文件名用的时间戳（避免 `:` 等 Windows 非法字符）。
String snapshotStamp() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

/// 由备份内容推导导入后的终态。
///
/// `replaceAll` 与导入对账共用它，避免两处各写一套归一化逻辑而漂移：
/// 对账基准必须是**预期终态**，不是备份原文——否则启动对账补上的
/// 工资账目会把正确结果判成「不一致」。
AppState resolveImportedState(ParsedBackupData data) {
  final nextRecords = dedupeRecords(data.records);
  final nextCategories = dedupeLedgerCategories(data.customCategories);
  final nextProfiles = ensureDefaultWorkProfile(
    dedupeWorkProfiles(data.workProfiles),
  );
  final nextBudget = normalizeBudgetTargets(data.budgetTargets.toJson());
  final nextEntries = kHoursOnly
      ? dedupeLedgerEntries(data.entries)
      : syncWageEntries(
          nextRecords,
          dedupeLedgerEntries(data.entries),
          nextProfiles,
        );

  return AppState(
    records: nextRecords,
    entries: nextEntries,
    customCategories: nextCategories,
    workProfiles: nextProfiles,
    budgetTargets: nextBudget,
  );
}

// ---- 派生 provider ----

final recordsProvider = Provider<List<WorkDayRecord>>(
  (ref) => ref.watch(appControllerProvider).records,
);

final entriesProvider = Provider<List<LedgerEntry>>(
  (ref) => ref.watch(appControllerProvider).entries,
);

final workProfilesProvider = Provider<List<WorkProfile>>(
  (ref) => ref.watch(appControllerProvider).workProfiles,
);

final budgetTargetsProvider = Provider<BudgetTargets>(
  (ref) => ref.watch(appControllerProvider).budgetTargets,
);

final customCategoriesProvider = Provider<List<CustomLedgerCategory>>(
  (ref) => ref.watch(appControllerProvider).customCategories,
);

/// 当前选中的月份（`YYYY-MM`），三个页面共享（修正旧版各页独立月份的割裂）。
class SelectedMonth extends Notifier<String> {
  @override
  String build() => _currentMonth();

  void setMonth(String value) => state = value;
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, String>(
  SelectedMonth.new,
);

String _currentMonth() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
