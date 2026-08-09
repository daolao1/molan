import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// 桌面/移动:保存对话框选路径后写入;用户取消返回 false
Future<bool> saveJsonPlatform(String fileName, List<int> bytes) async {
  final path = await FilePicker.platform.saveFile(
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (path == null) return false;
  await File(path).writeAsBytes(bytes);
  return true;
}
