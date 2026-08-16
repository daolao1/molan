import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as parser;
import 'db.dart';

class ReaderImport {
  static Future<int> importBytes(
    AppDatabase db,
    String name,
    List<int> bytes,
  ) async {
    final lower = name.toLowerCase();
    final bookTitle = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final bookId = await db.createReaderBook(title: bookTitle);
    final chapters = <({String title, String html})>[];
    if (lower.endsWith('.epub')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final files = <String, List<int>>{
        for (final f in archive.files)
          if (f.isFile) f.name.replaceAll('\\', '/'): f.content as List<int>,
      };
      final ordered = _epubSpine(files);
      final names = ordered.isEmpty
          ? files.keys
                .where(
                  (n) => RegExp(
                    r'\.(x?html?|htm)$',
                    caseSensitive: false,
                  ).hasMatch(n),
                )
                .toList()
          : ordered;
      for (final name in names) {
        final text = _decode(files[name] ?? const []);
        final doc = parser.parse(text);
        final body = doc.body?.innerHtml.trim() ?? '';
        if (body.isNotEmpty) {
          chapters.add((
            title: doc.querySelector('title')?.text.trim().isNotEmpty == true
                ? doc.querySelector('title')!.text.trim()
                : doc.querySelector('h1,h2,h3')?.text.trim().isNotEmpty == true
                ? doc.querySelector('h1,h2,h3')!.text.trim()
                : '第 ${chapters.length + 1} 章',
            html: body,
          ));
        }
      }
    } else {
      final text = _decode(bytes).replaceAll('\r\n', '\n');
      if (lower.endsWith('.html') || lower.endsWith('.htm')) {
        final doc = parser.parse(text);
        chapters.add((
          title: bookTitle,
          html: doc.body?.innerHtml.trim() ?? text,
        ));
      } else {
        final ps = text
            .split(RegExp(r'\n\s*\n'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        chapters.addAll([
          for (var i = 0; i < ps.length; i++)
            (
              title: ps.length == 1 ? bookTitle : '第 ${i + 1} 章',
              html: '<p>${_escape(ps[i]).replaceAll('\n', '<br>')}</p>',
            ),
        ]);
      }
    }
    if (chapters.isEmpty) chapters.add((title: bookTitle, html: '<p>正文为空</p>'));
    for (var i = 0; i < chapters.length; i++) {
      await db.createReaderChapter(
        bookId: bookId,
        position: i,
        title: chapters[i].title,
        originalHtml: chapters[i].html,
      );
    }
    return bookId;
  }

  static List<String> _epubSpine(Map<String, List<int>> files) {
    final container = files['META-INF/container.xml'];
    if (container == null) return [];
    final root = parser
        .parse(_decode(container))
        .querySelector('rootfile')
        ?.attributes['full-path'];
    if (root == null || files[root] == null) return [];
    final opf = parser.parse(_decode(files[root]!));
    final manifest = <String, String>{};
    for (final item in opf.querySelectorAll('manifest > item')) {
      final id = item.attributes['id'];
      final href = item.attributes['href'];
      if (id != null && href != null) manifest[id] = _join(root, href);
    }
    return [
      for (final ref in opf.querySelectorAll('spine > itemref'))
        if (manifest[ref.attributes['idref']] != null)
          manifest[ref.attributes['idref']]!,
    ];
  }

  static String _join(String root, String href) {
    final base = root.contains('/')
        ? root.substring(0, root.lastIndexOf('/'))
        : '';
    final out = <String>[];
    for (final part in [
      ...base.split('/'),
      ...Uri.decodeComponent(href).split('/'),
    ]) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..' && out.isNotEmpty) {
        out.removeLast();
      } else if (part != '..')
        out.add(part);
    }
    return out.join('/');
  }

  static String _decode(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf)
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe)
      return _utf16(bytes.sublist(2), true);
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff)
      return _utf16(bytes.sublist(2), false);
    final value = utf8.decode(bytes, allowMalformed: true);
    return value.contains('\uFFFD') ? latin1.decode(bytes) : value;
  }

  static String _utf16(List<int> bytes, bool little) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2)
      units.add(
        little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
      );
    return String.fromCharCodes(units);
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
