/// 文件导出 / 导入。
///
/// 导出走「写临时文件 + 系统分享」，导入走系统文件选择器。
/// 两者都不依赖存储权限（应用私有目录 + SAF），对齐旧版 `exportService.ts`。
///
/// 导入的防护顺序很重要：**先看文件大小，再读字节，最后解码**。
/// 反过来的话，一个 500 MB 的文件在 `utf8.decode` 阶段就已经把内存吃掉了，
/// 后面再检查大小没有任何意义。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup.dart';

/// 选中的备份文件：文本 + 真实 UTF-8 字节数。
///
/// 字节数单独带出来，是因为 `String.length` 是 UTF-16 code unit，
/// 中文/emoji 会显著低估实际体积，不能用来做上限判断。
class PickedBackup {
  const PickedBackup({required this.text, required this.byteLength});

  final String text;
  final int byteLength;
}

class ExportService {
  ExportService._();

  /// 写入临时目录并返回文件。
  static Future<File> writeText(String content, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// 分享文件（系统面板）。
  static Future<void> share(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeOf(file.path))],
        subject: subject,
      ),
    );
  }

  static String _mimeOf(String path) {
    if (path.endsWith('.json')) return 'application/json';
    if (path.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }

  /// 选择备份文件并返回文本 + 字节数；用户取消返回 null。
  ///
  /// 超限或不是合法 UTF-8 时抛 [BackupParseException]，调用方直接展示 message。
  static Future<PickedBackup?> pickBackupText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      // 不要 withData：它会把整个文件读进内存，大文件在选中的瞬间就崩
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;

    // 元数据预检：这一步还没读取文件内容
    if (picked.size > maxBackupBytes) {
      throw const BackupParseException('备份文件过大（超过 20 MB），请确认选对了文件');
    }

    final path = picked.path;
    if (path == null) {
      throw const BackupParseException('无法读取所选文件');
    }
    final Uint8List bytes = await File(path).readAsBytes();
    if (bytes.length > maxBackupBytes) {
      throw const BackupParseException('备份文件过大（超过 20 MB），请确认选对了文件');
    }

    try {
      // 严格解码：损坏的字节必须报错，不能被替换成 U+FFFD 后继续导入
      return PickedBackup(text: utf8.decode(bytes), byteLength: bytes.length);
    } on FormatException {
      throw const BackupParseException('备份文件不是有效的 UTF-8 文本');
    }
  }

  /// 生成带日期的文件名。
  static String stampedName(String prefix, String ext) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    return '$prefix-$stamp.$ext';
  }
}
