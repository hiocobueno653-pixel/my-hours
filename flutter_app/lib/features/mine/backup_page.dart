import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/measure_unit.dart';
import '../../core/theme_tokens.dart';
import '../../data/backup.dart';
import '../../data/constants.dart';
import '../../data/dates.dart';
import '../../data/ledger.dart';
import '../../data/models.dart';
import '../../data/persistence.dart';
import '../../data/records.dart';
import '../../platform/export_service.dart';
import '../../state/app_controller.dart';
import '../../ui/pinned_header.dart';
import '../../ui/widgets.dart';
import '../../ui/dialog.dart';

/// 数据与备份：导出 / 导入 / 迁移对账。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  String? _status;
  MigrationReport? _report;
  List<LocalSnapshot> _snapshots = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSnapshots());
  }

  String get _month => ref.read(selectedMonthProvider);

  void _refreshSnapshots() {
    if (!mounted) return;
    final snapshots = ref.read(storeProvider).listAutoSnapshots();
    setState(() => _snapshots = snapshots);
  }

  Future<void> _exportJson() async {
    try {
      final state = ref.read(appControllerProvider);
      final payload = createBackupPayload(
        records: state.records,
        entries: state.entries,
        customCategories: state.customCategories,
        workProfiles: state.workProfiles,
        budgetTargets: state.budgetTargets,
      );
      final text = const JsonEncoder.withIndent('  ').convert(payload.toJson());
      final file = await ExportService.writeText(
        text,
        ExportService.stampedName('时页备份', 'json'),
      );
      await ExportService.share(file, subject: '时页备份');
      if (mounted) setState(() => _status = '已生成备份文件并打开分享面板');
    } on Object {
      if (mounted) setState(() => _status = '导出失败，请稍后重试');
    }
  }

  Future<void> _exportCsv(String kind) async {
    try {
      final state = ref.read(appControllerProvider);
      final csv = switch (kind) {
        'hours' => buildMonthCsv(
          _month,
          state.records,
          quantity: context.unit.quantity,
        ),
        'ledger' => buildLedgerCsv(
          _month,
          state.entries,
          records: state.records,
          quantity: context.unit.quantity,
          unitName: context.unit.name,
        ),
        _ => buildMonthOverviewCsv(
          _month,
          state.records,
          state.entries,
          quantity: context.unit.quantity,
        ),
      };
      final name = switch (kind) {
        'hours' => ExportService.stampedName(
          '时页-${context.unit.quantity}表-$_month',
          'csv',
        ),
        'ledger' => ExportService.stampedName('时页-账本-$_month', 'csv'),
        _ => ExportService.stampedName('时页-月概览-$_month', 'csv'),
      };
      final file = await ExportService.writeText(csv, name);
      await ExportService.share(file, subject: name);
      if (mounted) setState(() => _status = '已导出 $name');
    } on Object {
      if (mounted) setState(() => _status = '导出失败，请稍后重试');
    }
  }

  Future<void> _import() async {
    PickedBackup? picked;
    try {
      picked = await ExportService.pickBackupText();
    } on BackupParseException catch (error) {
      // 大小/编码在读取阶段就可能被拒，不能只在 parse 时捕获
      if (mounted) setState(() => _status = '导入失败：${error.message}');
      return;
    } on Object {
      if (mounted) setState(() => _status = '无法读取备份文件，请重试');
      return;
    }
    if (picked == null) return;

    ParsedBackupData parsed;
    try {
      parsed = parseBackupText(picked.text, byteLength: picked.byteLength);
    } on BackupParseException catch (error) {
      if (mounted) setState(() => _status = '导入失败：${error.message}');
      return;
    } on Object {
      if (mounted) setState(() => _status = '导入失败：文件格式无法识别');
      return;
    }

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '导入会替换当前全部数据',
      description:
          '备份包含 ${parsed.records.length} 条${context.unit.quantity}、'
          '${parsed.entries.length} 条账目。'
          '${parsed.droppedItems > 0 ? '其中 ${parsed.droppedItems} 条无法识别的数据将被跳过。' : ''}'
          '导入后会在下方给出对账结果；不一致会明确标红。',
      confirmLabel: '导入',
      danger: true,
    );
    if (confirmed != true) return;

    try {
      final controller = ref.read(appControllerProvider.notifier);
      // 对账基准必须是「预期终态」而不是备份原文：replaceAll 会顺手对账
      // （补/删工资账目），拿原文比对必然把正确结果判成不一致。
      final expected = resolveImportedState(parsed);
      final written = controller.replaceAll(parsed);
      if (!mounted) return;

      final report = MigrationReport.compare(
        expected: expected,
        actual: ref.read(appControllerProvider),
      );
      setState(() {
        _report = report;
        _status = written
            ? '${parsed.droppedItems > 0 ? '已跳过 ${parsed.droppedItems} 条不合法数据；' : ''}'
                  '${MigrationReport.summaryOf(report)}'
            : '数据已载入但写入本地失败（仅本次运行有效），请检查存储空间后重试';
      });
      _refreshSnapshots();
    } on Object {
      if (mounted) setState(() => _status = '导入失败，数据未替换，请重试');
    }
  }

  Future<void> _restoreSnapshot(LocalSnapshot snapshot) async {
    ParsedBackupData parsed;
    try {
      parsed = parseBackupText(
        snapshot.file.readAsStringSync(),
        byteLength: snapshot.bytes,
      );
    } on BackupParseException catch (error) {
      if (mounted) setState(() => _status = '快照不可用：${error.message}');
      return;
    } on Object {
      if (mounted) setState(() => _status = '快照读取失败，请稍后重试');
      return;
    }

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '恢复本机快照？',
      description:
          '快照包含 ${parsed.records.length} 条${context.unit.quantity}、'
          '${parsed.entries.length} 条账目。'
          '${parsed.droppedItems > 0 ? '其中 ${parsed.droppedItems} 条无法识别的数据将被跳过。' : ''}'
          '恢复前会先为当前数据再留一份现场，然后替换为这份快照。',
      confirmLabel: '恢复',
      danger: true,
    );
    if (confirmed != true) return;

    try {
      final controller = ref.read(appControllerProvider.notifier);
      final expected = resolveImportedState(parsed);
      final written = controller.replaceAll(parsed);
      if (!mounted) return;
      final report = MigrationReport.compare(
        expected: expected,
        actual: ref.read(appControllerProvider),
      );
      setState(() {
        _report = report;
        _status = written
            ? '${parsed.droppedItems > 0 ? '已跳过 ${parsed.droppedItems} 条不合法数据；' : ''}'
                  '已恢复本机快照；${MigrationReport.summaryOf(report)}'
            : '快照已载入但写入本地失败（仅本次运行有效）';
      });
      _refreshSnapshots();
    } on Object {
      if (mounted) setState(() => _status = '恢复失败，当前数据未替换');
    }
  }

  String _snapshotLabel(LocalSnapshot snapshot) {
    final date = snapshot.takenAt;
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    String two(int value) => value.toString().padLeft(2, '0');
    final day = sameDay ? '今天' : '${date.month}月${date.day}日';
    return '$day ${two(date.hour)}:${two(date.minute)}';
  }

  String _snapshotSize(LocalSnapshot snapshot) {
    final kb = snapshot.bytes / 1024;
    return kb < 1 ? '${snapshot.bytes} B' : '${kb.toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: colors.page,
      body: AppPageBackground(
        child: LiquidBackdropScaffold(
          body: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              top: PinnedSubHeader.totalHeight(context) + 12,
              bottom: MediaQuery.paddingOf(context).bottom + 36,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      radius: Radii.hero,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前数据',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.text2,
                            ),
                          ),
                          const SizedBox(height: Gaps.md),
                          Row(
                            children: [
                              _Count(
                                label: '${context.unit.quantity}记录',
                                value: state.records.length,
                              ),
                              _Count(label: '账目', value: state.entries.length),
                              _Count(
                                label: '工作',
                                value: state.workProfiles.length,
                              ),
                              _Count(
                                label: '自定义分类',
                                value: state.customCategories.length,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.cardGap),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppIconBadge(
                                icon: Icons.history_rounded,
                                color: colors.primary,
                                size: 30,
                                iconSize: 17,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '本机自动快照',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                              const Spacer(),
                              if (_snapshots.isNotEmpty)
                                Text(
                                  '${_snapshots.length} 份',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.text3,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '每天首次打开或保存时自动留档，保留最近 7 天；恢复前会再保留当前现场。',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: colors.text3,
                            ),
                          ),
                          if (_snapshots.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                '还没有自动快照',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.text2,
                                ),
                              ),
                            )
                          else
                            for (
                              var index = 0;
                              index < _snapshots.length;
                              index++
                            ) ...[
                              if (index == 0)
                                const SizedBox(height: 8)
                              else
                                Divider(height: 1, color: colors.divider),
                              Pressable(
                                shape: Radii.shape(Radii.sm),
                                pressedScale: 0.98,
                                onTap: () =>
                                    _restoreSnapshot(_snapshots[index]),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.restore_rounded,
                                        size: 17,
                                        color: colors.text2,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _snapshotLabel(_snapshots[index]),
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: colors.text,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '本机安全副本 · ${_snapshotSize(_snapshots[index])}',
                                              style: TextStyle(
                                                fontSize: TypeScale.micro,
                                                color: colors.text3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: colors.text3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.cardGap),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                      child: Column(
                        children: [
                          ListRow(
                            title: '保存数据备份（JSON）',
                            subtitle: 'v4 格式，可直接用于本版导入',
                            leading: AppIconBadge(
                              icon: Icons.save_alt_rounded,
                              color: colors.primary,
                            ),
                            showChevron: true,
                            onTap: _exportJson,
                          ),
                          Divider(
                            height: 1,
                            color: colors.divider,
                            indent: 64,
                            endIndent: 16,
                          ),
                          ListRow(
                            title: '导出本月${context.unit.quantity}表（CSV）',
                            subtitle: '含星期、${context.unit.name}、备注与月总计',
                            leading: AppIconBadge(
                              icon: Icons.table_rows_rounded,
                              color: colors.income,
                            ),
                            showChevron: true,
                            onTap: () => _exportCsv('hours'),
                          ),
                          Divider(
                            height: 1,
                            color: colors.divider,
                            indent: 64,
                            endIndent: 16,
                          ),
                          ListRow(
                            title: '导出本月账本（CSV）',
                            subtitle: '含类型、分类、金额与月结余',
                            leading: const AppIconBadge(
                              icon: Icons.receipt_long_rounded,
                              color: Color(0xFF0EA5E9),
                            ),
                            showChevron: true,
                            onTap: () => _exportCsv('ledger'),
                          ),
                          Divider(
                            height: 1,
                            color: colors.divider,
                            indent: 64,
                            endIndent: 16,
                          ),
                          ListRow(
                            title: '导出月中概览（CSV）',
                            subtitle: '${context.unit.quantity} + 收支 + 分类小计',
                            leading: const AppIconBadge(
                              icon: Icons.assessment_outlined,
                              color: Color(0xFF5856D6),
                            ),
                            showChevron: true,
                            onTap: () => _exportCsv('overview'),
                          ),
                          Divider(
                            height: 1,
                            color: colors.divider,
                            indent: 64,
                            endIndent: 16,
                          ),
                          ListRow(
                            title: '加载备份数据',
                            subtitle: '导入会替换当前全部数据',
                            leading: AppIconBadge(
                              icon: Icons.file_open_rounded,
                              color: colors.warning,
                            ),
                            showChevron: true,
                            onTap: _import,
                          ),
                        ],
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: Gaps.md),
                      Text(
                        _status!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _report != null && !_report!.ok
                              ? colors.expense
                              : colors.text2,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (_report != null) ...[
                      const SizedBox(height: Gaps.md),
                      GlassCard(
                        flat: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '迁移对账',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '对比「备份文件」与「导入后数据」，任一项不一致即需人工核对。',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.text3,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: Gaps.md),
                            for (final row in _report!.rows)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        row.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: colors.text2,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      row.expected,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: colors.text3,
                                        fontFeatures: tabularFigures,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Icon(
                                        row.ok
                                            ? Icons.check_rounded
                                            : Icons.close_rounded,
                                        size: 15,
                                        color: row.ok
                                            ? colors.income
                                            : colors.expense,
                                      ),
                                    ),
                                    Text(
                                      row.actual,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: row.ok
                                            ? colors.text
                                            : colors.expense,
                                        fontFeatures: tabularFigures,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_report!.monthDiffs.isNotEmpty) ...[
                              const SizedBox(height: Gaps.md),
                              Text(
                                '按月份核对（只列出不一致）',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.expense,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final diff in _report!.monthDiffs)
                                _MonthDiffBlock(diff: diff),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Gaps.md),
                    Container(
                      padding: const EdgeInsets.all(Gaps.lg),
                      decoration: ShapeDecoration(
                        color: colors.isDark ? colors.block : colors.inset,
                        shape: Radii.shape(Radii.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '迁移说明',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colors.text2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '换机或从旧版迁移时：先在旧版「我的 → 数据与设置 → 保存数据备份」导出 JSON，'
                            '再回到本页导入。直接卸载旧版会连同浏览器数据一起删除，无法恢复。',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.text3,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gaps.xxl),
                  ],
                ),
              ),
            ],
          ),
          overlays: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedSubHeader(title: '数据与备份', onBack: widget.onBack),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.text,
              fontFeatures: tabularFigures,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: colors.text2)),
        ],
      ),
    );
  }
}

/// 导入对账报告。
///
/// 两类校验刻意分开：
/// - **全局**：条数，以及「工资账目合计 vs 已结算工资合计」——这两个数由
///   账本与工时记录两条链路各自算出，相等才说明派生关系没断。只比
///   期望值与实际值（同源）抓不到解析阶段的数据丢失。
/// - **逐月**：备份覆盖的每个月份都单独核对，不再只看共享月
///   （否则停在空月份时报告全绿，其它月的差异完全不可见）。
class MigrationReport {
  const MigrationReport({
    required this.rows,
    required this.monthDiffs,
    required this.monthsChecked,
  });

  final List<MigrationRow> rows;

  /// 只包含「有不一致」的月份。
  final List<MonthDiff> monthDiffs;

  /// 备份里出现过数据的月份数。
  final int monthsChecked;

  bool get ok => rows.every((row) => row.ok) && monthDiffs.isEmpty;

  /// 结果文案。不再说「五项全部一致」——口径变了，拒绝过度承诺。
  static String summaryOf(MigrationReport report) {
    if (!report.ok) return '导入完成，但存在不一致，请核对下方差异';
    if (report.monthsChecked == 0) return '导入完成，备份里没有可核对的月份';
    return '导入完成，条数一致，${report.monthsChecked} 个月份已逐月核对';
  }

  static MigrationReport compare({
    required AppState expected,
    required AppState actual,
  }) {
    String money(double value) => formatAmount(value);

    MigrationRow row(String label, String a, String b) =>
        MigrationRow(label: label, expected: a, actual: b, ok: a == b);

    final months = _monthsIn(expected);
    final diffs = <MonthDiff>[];
    for (final month in months) {
      final rows = <MigrationRow>[
        row(
          '工时',
          formatHoursValue(getMonthSummary(expected.records, month).totalHours),
          formatHoursValue(getMonthSummary(actual.records, month).totalHours),
        ),
        row(
          '工资',
          money(getMonthPay(expected.records, month, expected.workProfiles)),
          money(getMonthPay(actual.records, month, actual.workProfiles)),
        ),
        row(
          '结余',
          money(getLedgerMonthSummary(expected.entries, month).balance),
          money(getLedgerMonthSummary(actual.entries, month).balance),
        ),
      ];
      if (rows.any((item) => !item.ok)) {
        diffs.add(MonthDiff(month: month, rows: rows));
      }
    }

    return MigrationReport(
      rows: [
        row('工时记录数', '${expected.records.length}', '${actual.records.length}'),
        row('账目条数', '${expected.entries.length}', '${actual.entries.length}'),
        // 跨源校验：账本里的工资收入合计，应与记录按结算价算出的合计相等。
        row(
          '工资账目 vs 已结算',
          money(_wageEntriesSum(actual)),
          money(_settledPaySum(actual)),
        ),
      ],
      monthDiffs: diffs,
      monthsChecked: months.length,
    );
  }

  /// 备份数据里出现过的月份（`YYYY-MM`），升序。
  static List<String> _monthsIn(AppState state) {
    final months = <String>{};
    for (final record in state.records) {
      if (record.date.length >= 7) months.add(record.date.substring(0, 7));
    }
    for (final entry in state.entries) {
      if (entry.date.length >= 7) months.add(entry.date.substring(0, 7));
    }
    return months.toList()..sort();
  }

  /// 账本里由结算生成（`wage-*`）的收入合计。
  static double _wageEntriesSum(AppState state) {
    var sum = 0.0;
    for (final entry in state.entries) {
      if (entry.type != LedgerType.income) continue;
      if (!entry.id.startsWith(wageEntryIdPrefix)) continue;
      sum += entry.amount;
    }
    return roundMoney(sum);
  }

  /// 所有已结算且工资 > 0 的记录按当前口径算出的合计。
  static double _settledPaySum(AppState state) {
    var sum = 0.0;
    for (final record in state.records) {
      if (!record.settled) continue;
      final pay = recordPay(record, state.workProfiles);
      if (pay <= 0) continue;
      sum += pay;
    }
    return roundMoney(sum);
  }
}

/// 单个月份的不一致明细。
class MonthDiff {
  const MonthDiff({required this.month, required this.rows});

  final String month;
  final List<MigrationRow> rows;
}

class MigrationRow {
  const MigrationRow({
    required this.label,
    required this.expected,
    required this.actual,
    required this.ok,
  });

  final String label;
  final String expected;
  final String actual;
  final bool ok;
}

/// 单个月份的差异块：只渲染不一致的项，避免整页数字。
class _MonthDiffBlock extends StatelessWidget {
  const _MonthDiffBlock({required this.diff});

  final MonthDiff diff;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatMonthLabel(diff.month),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          for (final row in diff.rows)
            if (!row.ok)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${row.label}：${row.expected} → ${row.actual}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.expense,
                    height: 1.4,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
