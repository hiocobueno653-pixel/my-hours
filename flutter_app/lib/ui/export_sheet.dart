import 'package:flutter/material.dart';

import '../core/measure_unit.dart';
import '../data/backup.dart';
import '../data/models.dart';
import '../platform/export_service.dart';
import 'sheet.dart';
import 'widgets.dart';

/// CSV 导出面板：月工时 / 月账本 / 月中概览。
Future<void> showExportSheet(
  BuildContext context, {
  required String month,
  required List<WorkDayRecord> records,
  required List<LedgerEntry> entries,
  bool includeLedger = true,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => SheetScaffold(
      title: '导出 CSV',
      child: Column(
        children: [
          ListRow(
            title: '本月${context.unit.quantity}表',
            subtitle: '日期、星期、${context.unit.name}、备注与月总计',
            leading: const Icon(Icons.table_rows_rounded),
            onTap: () => _export(
              context,
              sheetContext,
              content: buildMonthCsv(
                month,
                records,
                quantity: context.unit.quantity,
              ),
              name: ExportService.stampedName(
                '时页-${context.unit.quantity}-$month',
                'csv',
              ),
            ),
          ),
          if (includeLedger) ...[
            const SizedBox(height: 4),
            ListRow(
              title: '本月账本',
              subtitle: '类型、分类、金额、关联${context.unit.name}与结余',
              leading: const Icon(Icons.receipt_long_rounded),
              onTap: () => _export(
                context,
                sheetContext,
                content: buildLedgerCsv(
                  month,
                  entries,
                  records: records,
                  quantity: context.unit.quantity,
                  unitName: context.unit.name,
                ),
                name: ExportService.stampedName('时页-账本-$month', 'csv'),
              ),
            ),
            const SizedBox(height: 4),
            ListRow(
              title: '月中概览',
              subtitle: '${context.unit.quantity} + 收支 + 分类小计',
              leading: const Icon(Icons.assessment_outlined),
              onTap: () => _export(
                context,
                sheetContext,
                content: buildMonthOverviewCsv(
                  month,
                  records,
                  entries,
                  quantity: context.unit.quantity,
                ),
                name: ExportService.stampedName('时页-概览-$month', 'csv'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> _export(
  BuildContext context,
  BuildContext sheetContext, {
  required String content,
  required String name,
}) async {
  Navigator.of(sheetContext).pop();
  try {
    final file = await ExportService.writeText(content, name);
    await ExportService.share(file, subject: name);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导出 $name')));
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('导出失败，请稍后重试')));
    }
  }
}
