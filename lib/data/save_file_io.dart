import 'dart:io';

/// 非 web 平台:把内容写入用户选择的路径
Future<void> maybeWriteFile(String path, List<int> bytes) =>
    File(path).writeAsBytes(bytes);
