import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// web:file_picker 8.x 不支持 saveFile,用 Blob + a 标签触发浏览器下载
Future<bool> saveJsonPlatform(String fileName, List<int> bytes) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return true;
}
