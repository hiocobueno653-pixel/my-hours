/// 本地存储：单 JSON 文档 + 原子写 + 三代轮转。
///
/// 见 docs/adr/0001-storage-format.md。核心不变量：
/// - 存储格式 == 备份 v4 格式（迁移即复制文件，导出即同一份字节）；
/// - 写入先落临时文件再 rename，避免半截文件；
/// - 读取按 主 → .bak → .bak.1 回退，三代都坏时返回 null（由首启向导处理，
///   绝不当成「空数据」静默覆盖）。
library;

import 'dart:convert';
import 'dart:io';

import 'ledger.dart';
import 'models.dart';
import 'profiles.dart';
import 'records.dart';

/// 内存中的完整数据文档（与备份 v4 同构）。
class StoreDocument {
  const StoreDocument({
    required this.records,
    required this.entries,
    required this.customCategories,
    required this.workProfiles,
    required this.budgetTargets,
    this.exportedAt,
  });

  final List<WorkDayRecord> records;
  final List<LedgerEntry> entries;
  final List<CustomLedgerCategory> customCategories;
  final List<WorkProfile> workProfiles;
  final BudgetTargets budgetTargets;
  final String? exportedAt;

  StoreDocument copyWith({
    List<WorkDayRecord>? records,
    List<LedgerEntry>? entries,
    List<CustomLedgerCategory>? customCategories,
    List<WorkProfile>? workProfiles,
    BudgetTargets? budgetTargets,
    String? exportedAt,
  }) {
    return StoreDocument(
      records: records ?? this.records,
      entries: entries ?? this.entries,
      customCategories: customCategories ?? this.customCategories,
      workProfiles: workProfiles ?? this.workProfiles,
      budgetTargets: budgetTargets ?? this.budgetTargets,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }

  Map<String, Object?> toJson() => BackupFile(
    exportedAt: exportedAt ?? DateTime.now().toUtc().toIso8601String(),
    records: records,
    entries: entries,
    customCategories: customCategories,
    workProfiles: workProfiles,
    budgetTargets: budgetTargets,
  ).toJson();

  static StoreDocument fromParsed(ParsedBackupData data, {String? exportedAt}) {
    return StoreDocument(
      records: data.records,
      entries: data.entries,
      customCategories: data.customCategories,
      workProfiles: data.workProfiles,
      budgetTargets: data.budgetTargets,
      exportedAt: exportedAt,
    );
  }
}

/// 读取结果：区分「文件不存在」与「文件存在但全坏」。
enum LoadStatus { ok, missing, corrupted }

class LoadResult {
  const LoadResult(this.status, this.document, {this.source});

  final LoadStatus status;
  final StoreDocument? document;

  /// 命中的文件：`main` / `bak` / `bak1`。
  final String? source;
}

/// 本机自动快照。每天最多保留一份，供「数据与备份」手动恢复。
class LocalSnapshot {
  const LocalSnapshot({
    required this.file,
    required this.takenAt,
    required this.bytes,
  });

  final File file;
  final DateTime takenAt;
  final int bytes;
}

/// 启动是否为「主文件不可读、从备份回退」。
///
/// 回退本身正确，但必须让用户知道最近一次改动可能不在。
bool recoveredFromBackup(LoadResult result) =>
    result.status == LoadStatus.ok &&
    result.source != null &&
    result.source != 'main';

/// 文件系统存储。`directory` 由 `path_provider` 提供（应用私有目录）。
class LocalStore {
  LocalStore(this.directory);

  final Directory directory;

  String get _mainPath => '${directory.path}/my-hours.json';
  String get _bakPath => '${directory.path}/my-hours.json.bak';
  String get _bak1Path => '${directory.path}/my-hours.json.bak.1';
  String get _tmpPath => '${directory.path}/my-hours.json.tmp';

  File get mainFile => File(_mainPath);
  File get backupFile => File(_bakPath);
  File get oldBackupFile => File(_bak1Path);

  String get _snapshotsPath => '${directory.path}/snapshots';

  /// 本次会话 load() 命中的文件（`main` / `bak` / `bak1`）。
  ///
  /// 用它判断主文件是否可信：从后备回退说明 main 已损坏，
  /// 此时保存绝不能把坏 main 轮转成 .bak——那会把唯一的好备份挤掉。
  ///
  /// 三代全坏时置为 [quarantine]：现场必须原样保留，任何写入都拒绝，
  /// 否则第一次保存就会把同一份坏字节刷进 `.bak` / `.bak.1`，
  /// 「原文件没有被删除」这句承诺在用户下一次点保存时就失效。
  static const String quarantine = 'quarantine';

  String? _loadSource;
  String? get loadSource => _loadSource;

  /// 上一次成功写入的内容指纹。正常保存路径只对传入文档编码一次，
  /// 不再为了判断「内容没变」反复读取主文件。
  String? _lastSavedFingerprint;

  /// 存档处于隔离态：主文件与两代备份都不可读，禁止写入。
  bool get isQuarantined => _loadSource == quarantine;

  static String _dayStamp(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}';
  }

  List<File> _autoSnapshotFiles() {
    final folder = Directory(_snapshotsPath);
    if (!folder.existsSync()) return const [];
    final files = <File>[];
    for (final entity in folder.listSync()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('auto-') ||
          !name.endsWith('.json') ||
          name.length != 18) {
        continue;
      }
      files.add(entity);
    }
    return files;
  }

  /// 每天首次打开或保存时留一份可手动恢复的本机快照。
  ///
  /// 空数据不生成快照；快照不参与启动回退，只能在备份页显式恢复。
  String? createDailySnapshot({DateTime? now, int keep = 7}) {
    if (isQuarantined) return null;
    final folder = Directory(_snapshotsPath);
    folder.createSync(recursive: true);
    final target = File(
      '${folder.path}/auto-${_dayStamp(now ?? DateTime.now())}.json',
    );
    // 今天的快照已经存在时直接返回：不要为了判断而先解析整个主文档。
    if (target.existsSync()) return target.path;

    final main = File(_mainPath);
    if (!main.existsSync()) return null;
    final document = _tryParse(main);
    if (document == null) return null;
    if (document.records.isEmpty &&
        document.entries.isEmpty &&
        document.customCategories.isEmpty) {
      return null;
    }

    final tmp = File('${target.path}.tmp');
    try {
      if (tmp.existsSync()) tmp.deleteSync();
      main.copySync(tmp.path);
      try {
        // Android/Linux 上 rename 覆盖是同一文件系统内的原子替换。
        tmp.renameSync(target.path);
      } on FileSystemException {
        // Windows 测试环境不允许 rename 覆盖既有文件，退化为删除后替换。
        if (target.existsSync()) target.deleteSync();
        tmp.renameSync(target.path);
      }
    } on FileSystemException {
      return null;
    }
    _pruneAutoSnapshots(keep);
    return target.path;
  }

  /// 按文件名日期倒序，保留最近 [keep] 天。
  void _pruneAutoSnapshots(int keep) {
    final files = _autoSnapshotFiles()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (var index = keep; index < files.length; index++) {
      try {
        files[index].deleteSync();
      } on FileSystemException {
        // 单个旧快照清理失败不阻断新快照
      }
    }
  }

  /// 供备份页读取：最新快照在前。
  List<LocalSnapshot> listAutoSnapshots() {
    final result = <LocalSnapshot>[];
    for (final file in _autoSnapshotFiles()) {
      try {
        final stat = file.statSync();
        if (stat.size <= 0) continue;
        final name = file.path.split(Platform.pathSeparator).last;
        final stamp = name.substring(5, name.length - 5);
        final year = int.tryParse(stamp.substring(0, 4));
        final month = int.tryParse(stamp.substring(4, 6));
        final day = int.tryParse(stamp.substring(6, 8));
        final takenAt = year != null && month != null && day != null
            ? DateTime(
                year,
                month,
                day,
                stat.modified.hour,
                stat.modified.minute,
                stat.modified.second,
              )
            : stat.modified;
        result.add(
          LocalSnapshot(file: file, takenAt: takenAt, bytes: stat.size),
        );
      } on FileSystemException {
        // 已被其他操作删除的快照忽略
      }
    }
    result.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return result;
  }

  /// 读取：主 → bak → bak1。
  LoadResult load() {
    final candidates = <String, String>{
      'main': _mainPath,
      'bak': _bakPath,
      'bak1': _bak1Path,
    };
    var anyExists = false;
    for (final entry in candidates.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) continue;
      anyExists = true;
      final document = _tryParse(file);
      if (document != null) {
        _loadSource = entry.key;
        return LoadResult(LoadStatus.ok, document, source: entry.key);
      }
    }
    _loadSource = anyExists ? quarantine : null;
    return LoadResult(
      anyExists ? LoadStatus.corrupted : LoadStatus.missing,
      null,
    );
  }

  StoreDocument? _tryParse(File file) {
    try {
      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['app'] != 'my-hours') return null;
      final version = decoded['version'];
      if (version is! num || version.toInt() != 4) return null;

      final records = <WorkDayRecord>[];
      final recordsRaw = decoded['records'];
      if (recordsRaw is List) {
        for (final item in recordsRaw) {
          final record = _recordFromJson(item);
          if (record == null) return null;
          records.add(record);
        }
      } else {
        return null;
      }

      final entries = <LedgerEntry>[];
      final entriesRaw = decoded['entries'];
      if (entriesRaw is List) {
        for (final item in entriesRaw) {
          final entry = _entryFromJson(item);
          if (entry == null) return null;
          entries.add(entry);
        }
      } else {
        return null;
      }

      final categories = <CustomLedgerCategory>[];
      final categoriesRaw = decoded['customCategories'];
      if (categoriesRaw is List) {
        for (final item in categoriesRaw) {
          final category = _categoryFromJson(item);
          if (category == null) return null;
          categories.add(category);
        }
      }

      final profiles = <WorkProfile>[];
      final profilesRaw = decoded['workProfiles'];
      if (profilesRaw is List) {
        for (final item in profilesRaw) {
          final profile = _profileFromJson(item);
          if (profile == null) return null;
          profiles.add(profile);
        }
      }

      return StoreDocument(
        records: dedupeRecords(records),
        entries: dedupeLedgerEntries(entries),
        customCategories: dedupeLedgerCategories(categories),
        workProfiles: ensureDefaultWorkProfile(dedupeWorkProfiles(profiles)),
        budgetTargets: _budgetFromJson(decoded['budgetTargets']),
        exportedAt: decoded['exportedAt'] is String
            ? decoded['exportedAt'] as String
            : null,
      );
    } on Object {
      return null;
    }
  }

  /// 原子写入：tmp → 轮转 → rename。
  ///
  /// 三条失败路径都刻意保留现场：
  /// - 隔离态（三代全坏）直接拒绝，不写、不轮转；
  /// - 主文件不可信（从 `.bak` 回退）时不轮转；
  /// - rename 失败不做截断式覆盖，宁可失败也不留半截主文件。
  /// 规范化内容（剔除每次都会变的时间戳）用于「数据是否真的变了」判断。
  ///
  /// 不剔除的话每次保存的字节都不同，三代备份会退化成「最近三次保存」：
  /// 误删一个月后随手点两次保存，三代全是删后状态。
  static String? _contentFingerprint(Map<String, Object?>? json) {
    if (json == null) return null;
    final copy = Map<String, Object?>.of(json)..remove('exportedAt');
    return jsonEncode(copy);
  }

  Map<String, Object?>? _readJsonMap(File file) {
    try {
      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      return null;
    }
  }

  bool save(StoreDocument document, {bool overrideQuarantine = false}) {
    // 三代全坏：任何写入都会把同一份坏字节刷进 .bak / .bak.1，
    // 把最后的取证副本也毁掉。
    // 唯一例外是「导入一份校验通过的备份」——那是恢复通道，写的是全新内容。
    if (isQuarantined && !overrideQuarantine) return false;
    try {
      directory.createSync(recursive: true);
      final outgoing = document.toJson();

      // 内容与磁盘上完全一致时不做任何事：既省一次 IO，也不白烧一代备份。
      // 只对「从 main 读到的会话」生效——从 .bak 回退时即使内容相同，
      // 也要写一次把损坏的主文件修回来（此路径不轮转）。
      final fingerprint = _contentFingerprint(outgoing);
      final unchanged =
          _loadSource == 'main' &&
          fingerprint != null &&
          (fingerprint == _lastSavedFingerprint ||
              (_lastSavedFingerprint == null &&
                  fingerprint ==
                      _contentFingerprint(_readJsonMap(File(_mainPath)))));
      if (unchanged) return true;

      final text = const JsonEncoder.withIndent(null).convert(outgoing);
      final tmp = File(_tmpPath);
      tmp.writeAsStringSync(text, flush: true);

      final main = File(_mainPath);
      final bak = File(_bakPath);

      // 只有「本次会话从 main 成功读到」或「还没有任何存档」时才轮转。
      // 从 .bak 回退（main 已损坏）时轮转，会把坏 main 复制成 .bak，
      // 好备份被挤到 .bak.1，再写一次就三代全坏。
      final mainTrusted = _loadSource == 'main' || _loadSource == null;
      if (main.existsSync() && mainTrusted) {
        if (bak.existsSync()) {
          try {
            bak.copySync(_bak1Path);
          } on FileSystemException {
            // 旧备份轮转失败不阻断主写入
          }
        }
        try {
          main.copySync(_bakPath);
        } on FileSystemException {
          // 备份失败不阻断主写入
        }
      }

      // Windows 上 rename 覆盖已存在文件会失败：先删主文件再 rename。
      // 不用 `writeAsStringSync` 退化——它是先截断再写，进程中途被杀就留下
      // 半截主文件，比「主文件缺失、仍可从 .bak 回退」更糟。
      try {
        if (main.existsSync()) main.deleteSync();
        tmp.renameSync(_mainPath);
      } on FileSystemException {
        _loadSource = null;
        _lastSavedFingerprint = null;
        return false;
      }
      // 本次写入成功后 main 就是最新可信副本，后续轮转恢复正常。
      _loadSource = 'main';
      _lastSavedFingerprint = fingerprint;
      return true;
    } on Object {
      // 写入失败：主文件状态未知，下次保存不再把它当作可信源。
      _loadSource = null;
      _lastSavedFingerprint = null;
      return false;
    }
  }

  /// 覆盖全部数据前先留一份现场（导入备份、隔离态恢复都走这里）。
  ///
  /// 每条覆盖都是不可逆操作：几十 KB 换一次「还能翻回上一份」的机会。
  /// 不轮转、不清理，文件名带时间戳，返回实际写出的路径。
  List<String> preserveSnapshot(String stamp) {
    final saved = <String>[];
    for (final pair in {
      'main': _mainPath,
      'bak': _bakPath,
      'bak1': _bak1Path,
    }.entries) {
      final source = File(pair.value);
      if (!source.existsSync()) continue;
      final target = '${directory.path}/my-hours.${pair.key}.$stamp.json';
      try {
        source.copySync(target);
        saved.add(target);
      } on FileSystemException {
        // 单份保留失败不阻断导入流程
      }
    }
    return saved;
  }

  /// 删除全部本地数据（含备份）。
  void clear() {
    for (final path in [_mainPath, _bakPath, _bak1Path, _tmpPath]) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } on FileSystemException {
          // 忽略单个文件删除失败
        }
      }
    }
    // 「清空全部数据」必须连导入/恢复前留下的现场和每日快照一起清掉，
    // 否则用户以为数据已经删除，下一次打开仍能从本机快照恢复出来。
    final folder = Directory(_snapshotsPath);
    if (folder.existsSync()) {
      try {
        folder.deleteSync(recursive: true);
      } on FileSystemException {
        // 快照目录清理失败不阻断主文档清理
      }
    }
    try {
      for (final entity in directory.listSync()) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('my-hours.') && name.endsWith('.json')) {
          entity.deleteSync();
        }
      }
    } on FileSystemException {
      // 现场副本清理失败不阻断主文档清理
    }
    _loadSource = null;
    _lastSavedFingerprint = null;
  }
}

// ---- 解析辅助：严格解析，任何字段不合法即返回 null（由上层判定整份损坏） ----

WorkDayRecord? _recordFromJson(Object? raw) {
  return normalizeRecord(raw);
}

LedgerEntry? _entryFromJson(Object? raw) {
  return normalizeLedgerEntry(raw);
}

CustomLedgerCategory? _categoryFromJson(Object? raw) {
  return normalizeLedgerCategory(raw);
}

WorkProfile? _profileFromJson(Object? raw) {
  return normalizeWorkProfile(raw);
}

BudgetTargets _budgetFromJson(Object? raw) {
  return normalizeBudgetTargets(raw);
}
