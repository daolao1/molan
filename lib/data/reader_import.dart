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
      final files = archive.files
          .where(
            (f) =>
                f.isFile &&
                RegExp(
                  r'\.(x?html?|htm)$',
                  caseSensitive: false,
                ).hasMatch(f.name),
          )
          .toList();
      for (final f in files) {
        final text = utf8.decode(f.content as List<int>, allowMalformed: true);
        final doc = parser.parse(text);
        final body = doc.body?.innerHtml.trim() ?? '';
        if (body.isNotEmpty)
          chapters.add((
            title: doc.querySelector('title')?.text.trim().isNotEmpty == true
                ? doc.querySelector('title')!.text.trim()
                : '第 ${chapters.length + 1} 章',
            html: body,
          ));
      }
    } else {
      final text = utf8
          .decode(bytes, allowMalformed: true)
          .replaceAll('\r\n', '\n');
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

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
