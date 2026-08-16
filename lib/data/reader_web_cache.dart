import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_web_models.dart';

class ReaderWebCache {
  static String _key(String url) =>
      'reader_web_cache_${base64Url.encode(utf8.encode(url))}';

  static Future<CachedWebBook?> read(String url) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(url));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map;
      return CachedWebBook(
        canonicalUrl: j['canonicalUrl']?.toString() ?? url,
        title: j['title']?.toString() ?? url,
        author: j['author']?.toString() ?? '',
        summary: j['summary']?.toString() ?? '',
        coverUrl: j['coverUrl']?.toString(),
        tags: [for (final x in (j['tags'] as List? ?? const [])) x.toString()],
        chapters: _chapters(j['chapters'], url),
      );
    } catch (_) {
      return null;
    }
  }

  static List<WebBookChapter> _chapters(dynamic value, String fallbackUrl) => [
    for (final item in (value as List? ?? const []))
      if (item is Map)
        WebBookChapter(
          title: item['title']?.toString() ?? '未命名',
          url: item['url']?.toString() ?? fallbackUrl,
          html: item['html']?.toString(),
          groupTitle: item['groupTitle']?.toString(),
        ),
  ];

  static Future<void> write(CachedWebBook book) async {
    final data = {
      'canonicalUrl': book.canonicalUrl,
      'title': book.title,
      'author': book.author,
      'summary': book.summary,
      'coverUrl': book.coverUrl,
      'tags': book.tags,
      'chapters': [
        for (final c in book.chapters)
          {
            'title': c.title,
            'url': c.url,
            'html': c.html,
            'groupTitle': c.groupTitle,
          },
      ],
    };
    await (await SharedPreferences.getInstance()).setString(
      _key(book.canonicalUrl),
      jsonEncode(data),
    );
  }

  static Future<void> clear(String url) async =>
      (await SharedPreferences.getInstance()).remove(_key(url));
}
