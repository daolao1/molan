import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 桌面/移动:保存对话框;移动端由 file_picker 直接写入(必须传 bytes),
/// 桌面端 8.x 忽略 bytes 只返回路径,需自行写文件
Future<bool> saveJsonPlatform(String fileName, List<int> bytes) async {
  final path = await FilePicker.platform.saveFile(
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['json'],
    bytes: Uint8List.fromList(bytes),
  );
  if (path == null) return false;
  if (!Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes);
  }
  return true;
}
