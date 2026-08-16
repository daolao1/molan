import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'db.dart';
import 'reader_web_models.dart';
import 'reader_web_cache.dart';
import 'reader_web_sources.dart';

class GenericHtmlWebSource implements WebSource {
  const GenericHtmlWebSource();
  @override
  String get id => 'generic-html';
  @override
  String get displayName => '通用网页';
  @override
  bool matches(Uri url) => url.scheme == 'http' || url.scheme == 'https';
  @override
  String canonicalize(String input) => Uri.parse(input.trim()).toString();

  @override
  Future<CachedWebBook> fetchIndex(String canonicalUrl) async {
    final cached = await ReaderWebCache.read(canonicalUrl);
    if (cached != null && cached.chapters.isNotEmpty) return cached;
    final response = await _get(canonicalUrl);
    final doc = parser.parse(response.body);
    final title =
        doc
            .querySelector('meta[property="og:title"]')
            ?.attributes['content']
            ?.trim() ??
        doc.querySelector('title')?.text.trim() ??
        canonicalUrl;
    final author =
        doc
            .querySelector('[rel="author"], meta[name="author"]')
            ?.attributes['content']
            ?.trim() ??
        '';
    final summary =
        doc
            .querySelector(
              'meta[name="description"], meta[property="og:description"]',
            )
            ?.attributes['content']
            ?.trim() ??
        '';
    final links = <WebBookChapter>[];
    for (final a in doc.querySelectorAll('a[href]')) {
      final text = a.text.trim();
      final href = a.attributes['href'];
      if (text.length < 2 || href == null || href.startsWith('#')) continue;
      final url = Uri.parse(canonicalUrl).resolve(href).toString();
      if (url == canonicalUrl || links.any((x) => x.url == url)) continue;
      if (RegExp(
        r'(chapter|chap|episode|section|第.+章|話|话)',
        caseSensitive: false,
      ).hasMatch(text))
        links.add(WebBookChapter(title: text, url: url));
    }
    if (links.isEmpty)
      links.add(
        WebBookChapter(
          title: title,
          url: canonicalUrl,
          html: doc.body?.innerHtml ?? response.body,
        ),
      );
    final book = CachedWebBook(
      canonicalUrl: canonicalUrl,
      title: title,
      author: author,
      summary: summary,
      chapters: links,
    );
    await ReaderWebCache.write(book);
    return book;
  }

  @override
  Future<WebBookChapter> fetchChapter(
    String canonicalUrl,
    WebBookChapter chapter,
  ) async {
    if (chapter.html != null) return chapter;
    final response = await _get(chapter.url);
    final doc = parser.parse(response.body);
    final body =
        doc
            .querySelector('article, main, .chapter, .chapter-content, body')
            ?.innerHtml ??
        response.body;
    final loaded = chapter.copyWith(html: body);
    final cached = await ReaderWebCache.read(canonicalUrl);
    if (cached != null) {
      await ReaderWebCache.write(
        CachedWebBook(
          canonicalUrl: cached.canonicalUrl,
          title: cached.title,
          author: cached.author,
          summary: cached.summary,
          coverUrl: cached.coverUrl,
          tags: cached.tags,
          chapters: [
            for (final c in cached.chapters) c.url == chapter.url ? loaded : c,
          ],
        ),
      );
    }
    return loaded;
  }

  static Future<http.Response> _get(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: const {
            'User-Agent': 'Molan/0.6 reader',
            'Accept': 'text/html,application/xhtml+xml',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw WebFetchException.fromStatus('网页', response.statusCode);
    return response;
  }
}

class ReaderWebClient {
  static const source = GenericHtmlWebSource();

  static Future<ReaderChapter> loadChapter(
    AppDatabase db,
    ReaderBook book,
    ReaderChapter chapter,
  ) async {
    final sourceUrl = chapter.sourceUrl;
    if (sourceUrl == null ||
        sourceUrl.isEmpty ||
        chapter.originalHtml.isNotEmpty) {
      return chapter;
    }
    final canonicalUrl = book.canonicalUrl ?? sourceUrl;
    final site = WebSourceRegistry.byId(book.sourceId, Uri.parse(sourceUrl));
    final loaded = site is GenericHtmlWebSource
        ? await source.fetchChapter(
            canonicalUrl,
            WebBookChapter(title: chapter.title, url: sourceUrl),
          )
        : await site.fetchChapter(
            canonicalUrl,
            WebBookChapter(title: chapter.title, url: sourceUrl),
          );
    final html = loaded.html?.trim() ?? '';
    if (html.isEmpty) throw Exception('${site.displayName} 未返回章节正文');
    await db.updateReaderOriginal(chapter.id, html);
    return chapter.copyWith(originalHtml: html);
  }

  static Future<int> importUrl(AppDatabase db, String input) async {
    final url = source.canonicalize(input);
    final site = WebSourceRegistry.forUrl(Uri.parse(url));
    final book = site is GenericHtmlWebSource
        ? await source.fetchIndex(url)
        : await site.fetchIndex(url);
    final id = await db.createReaderBook(
      title: book.title,
      author: book.author,
      description: book.summary,
      canonicalUrl: url,
      sourceId: site.id,
    );
    for (var i = 0; i < book.chapters.length; i++) {
      final chapter = book.chapters[i];
      await db.createReaderChapter(
        bookId: id,
        position: i,
        title: chapter.title,
        originalHtml: chapter.html ?? '',
        sourceUrl: chapter.url,
      );
    }
    return id;
  }
}
