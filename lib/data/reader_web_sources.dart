import 'dart:convert';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_web_models.dart';

abstract class _SiteSource implements WebSource {
  const _SiteSource();
  Future<String> text(String url) async {
    final r = await http
        .get(
          Uri.parse(url),
          headers: const {
            'User-Agent': 'Molan/0.6 reader',
            'Accept': 'text/html',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw WebFetchException.fromStatus(displayName, r.statusCode);
    }
    return r.body;
  }
}

class WebFetchException implements Exception {
  WebFetchException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  factory WebFetchException.fromStatus(String source, int status) {
    const cf = {403, 503, 520, 521, 522, 523, 524, 525, 526, 530};
    final suffix = cf.contains(status)
        ? '，可能触发 Cloudflare，请在浏览器登录后重试或提供 Cookie'
        : '';
    return WebFetchException('$source 请求失败 HTTP $status$suffix', status);
  }
  @override
  String toString() => message;
}

class Ao3Source extends _SiteSource {
  const Ao3Source();
  @override
  String get id => 'ao3';
  @override
  String get displayName => 'Archive of Our Own';
  @override
  bool matches(Uri u) =>
      u.host.toLowerCase().endsWith('archiveofourown.org') &&
      u.path.contains('/works/');
  @override
  String canonicalize(String input) {
    final u = Uri.parse(input.trim());
    final m = RegExp(r'/works/(\d+)').firstMatch(u.path);
    return m == null
        ? u.toString()
        : 'https://archiveofourown.org/works/${m.group(1)}';
  }

  @override
  Future<CachedWebBook> fetchIndex(String url) async {
    final d = parser.parse(await text(url));
    final title =
        d.querySelector('h2.title')?.text.trim() ??
        d.querySelector('title')?.text.trim() ??
        url;
    final author = d.querySelector('a[rel="author"]')?.text.trim() ?? '';
    final summary =
        d.querySelector('.summary .userstuff')?.innerHtml.trim() ?? '';
    final chapters = [
      for (final a in d.querySelectorAll(
        'select#selected_id option, ol.chapters a[href*="/chapters/"]',
      ))
        if (a.attributes['value'] != '0' && a.attributes['href'] != null)
          WebBookChapter(
            title: a.text.trim().isEmpty ? '章节' : a.text.trim(),
            url: Uri.parse(url).resolve(a.attributes['href']!).toString(),
          ),
    ];
    return CachedWebBook(
      canonicalUrl: url,
      title: title,
      author: author,
      summary: summary,
      chapters: chapters.isEmpty
          ? [WebBookChapter(title: title, url: url)]
          : chapters,
    );
  }

  @override
  Future<WebBookChapter> fetchChapter(String url, WebBookChapter c) async {
    final d = parser.parse(await text(c.url));
    return c.copyWith(
      html:
          d.querySelector('.userstuff')?.innerHtml.trim() ??
          d.body?.innerHtml ??
          '',
    );
  }
}

class SyosetuSource extends _SiteSource {
  const SyosetuSource();
  @override
  String get id => 'syosetu';
  @override
  String get displayName => '小説家になろう';
  @override
  bool matches(Uri u) =>
      u.host == 'ncode.syosetu.com' && u.pathSegments.length >= 1;
  @override
  String canonicalize(String input) {
    final u = Uri.parse(input.trim());
    return 'https://ncode.syosetu.com/${u.pathSegments.first.toLowerCase()}/';
  }

  @override
  Future<CachedWebBook> fetchIndex(String url) async {
    final d = parser.parse(await text(url));
    final title =
        d.querySelector('#novel_title')?.text.trim() ??
        d.querySelector('title')?.text.trim() ??
        url;
    final author = d.querySelector('#novel_writername a')?.text.trim() ?? '';
    final summary = d.querySelector('#novel_ex')?.innerHtml.trim() ?? '';
    final chapters = [
      for (final a in d.querySelectorAll('#novel_sublist2 a[href]'))
        WebBookChapter(
          title: a.text.trim(),
          url: Uri.parse(url).resolve(a.attributes['href']!).toString(),
        ),
    ];
    return CachedWebBook(
      canonicalUrl: url,
      title: title,
      author: author,
      summary: summary,
      chapters: chapters,
    );
  }

  @override
  Future<WebBookChapter> fetchChapter(String url, WebBookChapter c) async {
    final d = parser.parse(await text(c.url));
    return c.copyWith(
      html: d.querySelector('#novel_honbun')?.innerHtml.trim() ?? '',
    );
  }
}

class PixivSource extends _SiteSource {
  const PixivSource();
  @override
  String get id => 'pixiv';
  @override
  String get displayName => 'Pixiv 小说';
  @override
  bool matches(Uri u) =>
      (u.host == 'pixiv.net' || u.host == 'www.pixiv.net') &&
      (u.path == '/novel/show.php' || u.path.startsWith('/novel/series/'));
  @override
  String canonicalize(String input) {
    final u = Uri.parse(input.trim());
    if (u.path.startsWith('/novel/series/'))
      return 'https://www.pixiv.net${u.path}';
    final id = u.queryParameters['id'];
    if (id == null || int.tryParse(id) == null)
      throw const FormatException('Pixiv URL 缺少有效的 novel id');
    return 'https://www.pixiv.net/novel/show.php?id=$id';
  }

  Future<Map<String, dynamic>> _json(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = prefs.getString('reader_pixiv_phpsessid')?.trim();
    final r = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Molan/0.6 reader',
            'Accept': 'application/json',
            'Referer': 'https://www.pixiv.net/',
            if (cookie != null && cookie.isNotEmpty)
              'Cookie': 'PHPSESSID=$cookie',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw WebFetchException.fromStatus('Pixiv', r.statusCode);
    final root = jsonDecode(r.body) as Map;
    if (root['error'] == true)
      throw Exception(root['message']?.toString() ?? 'Pixiv 请求失败');
    return Map<String, dynamic>.from(root['body'] as Map? ?? root);
  }

  @override
  Future<CachedWebBook> fetchIndex(String url) async {
    if (url.contains('/series/')) {
      final sid = url.split('/').last;
      final meta = await _json('https://www.pixiv.net/ajax/novel/series/$sid');
      final chapters = <WebBookChapter>[];
      var lastOrder = 0;
      while (chapters.length < 1000) {
        final page = await _json(
          'https://www.pixiv.net/ajax/novel/series_content/$sid?limit=30&last_order=$lastOrder&order_by=asc',
        );
        final raw = page['page'] is Map
            ? page['page']['seriesContents']
            : page['seriesContents'];
        final list = raw is List ? raw : const [];
        if (list.isEmpty) break;
        for (final item in list) {
          if (item is Map && item['id'] != null)
            chapters.add(
              WebBookChapter(
                title: item['title']?.toString() ?? '章节 ${chapters.length + 1}',
                url: 'https://www.pixiv.net/novel/show.php?id=${item['id']}',
              ),
            );
        }
        if (list.length < 30) break;
        lastOrder += list.length;
      }
      return CachedWebBook(
        canonicalUrl: url,
        title: meta['title']?.toString() ?? 'Pixiv 系列 $sid',
        chapters: chapters,
      );
    }
    final id = Uri.parse(url).queryParameters['id'];
    if (id == null) throw Exception('Pixiv 系列暂需直接章节 URL');
    final body = await _json('https://www.pixiv.net/ajax/novel/$id');
    final title = body['title']?.toString() ?? 'Pixiv 小说 $id';
    return CachedWebBook(
      canonicalUrl: url,
      title: title,
      chapters: [
        WebBookChapter(
          title: title,
          url: url,
          html: contentToHtml(body['content']?.toString() ?? ''),
        ),
      ],
    );
  }

  @override
  Future<WebBookChapter> fetchChapter(String url, WebBookChapter c) async {
    final id = Uri.parse(c.url).queryParameters['id'];
    if (id == null) return c;
    final body = await _json('https://www.pixiv.net/ajax/novel/$id');
    return c.copyWith(html: contentToHtml(body['content']?.toString() ?? ''));
  }

  static String contentToHtml(String raw) => raw
      .split(RegExp(r'\[newpage\]'))
      .map(
        (p) => p
            .split(RegExp(r'\n\s*\n+'))
            .where((x) => x.trim().isNotEmpty)
            .map((x) => _paragraph(x.trim()))
            .join('\n'),
      )
      .join('<hr>\n');
  static String _paragraph(String value) {
    final chapter = RegExp(r'^\[chapter:(.+?)\]$').firstMatch(value);
    if (chapter != null) return '<h3>${_escape(chapter.group(1)!.trim())}</h3>';
    var s = value;
    final tags = <String>[];
    s = s.replaceAllMapped(RegExp(r'\[\[rb:(.+?)\s*>\s*(.+?)\]\]'), (m) {
      final token =
          '<ruby>${_escape(m.group(1)!.trim())}<rt>${_escape(m.group(2)!.trim())}</rt></ruby>';
      tags.add(token);
      return '\u0000${tags.length - 1}\u0000';
    });
    s = s.replaceAll(
      RegExp(r'\[(?:jump|pixivimage|uploadedimage):[^\]]*\]'),
      '',
    );
    var escaped = _escape(s).replaceAll('\n', '<br>');
    for (var i = 0; i < tags.length; i++)
      escaped = escaped.replaceAll('\u0000$i\u0000', tags[i]);
    return '<p>$escaped</p>';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Pixiv novel search backed by `/ajax/search/novels/{word}`.
class PixivDiscovery {
  const PixivDiscovery(this.source);
  final PixivSource source;

  Future<DiscoveryPage> search({
    required String keyword,
    int page = 1,
    String mode = 'all',
    String match = 's_tag',
    String order = 'date_d',
  }) async {
    final word = keyword.trim();
    if (word.isEmpty) throw const FormatException('Pixiv 搜索需要关键字');
    final encoded = Uri.encodeComponent(word);
    final root = await source._json(
      'https://www.pixiv.net/ajax/search/novels/$encoded?word=$encoded&order=$order&mode=$mode&s_mode=$match&p=${page < 1 ? 1 : page}',
    );
    final novel = root['novel'] is Map
        ? Map<String, dynamic>.from(root['novel'])
        : const <String, dynamic>{};
    final raw = novel['data'] is List ? novel['data'] as List : const [];
    final items = <DiscoveryItem>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final id = value['id']?.toString().trim() ?? '';
      final title = value['title']?.toString().trim() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      final seriesId = value['seriesId']?.toString();
      final tags = <String>[];
      if (value['xRestrict'] == 1) tags.add('R-18');
      if (value['xRestrict'] == 2) tags.add('R-18G');
      if (value['tags'] is List) {
        tags.addAll(
          (value['tags'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .take(12),
        );
      }
      final detail = seriesId != null && seriesId != '0'
          ? 'https://www.pixiv.net/novel/series/$seriesId'
          : 'https://www.pixiv.net/novel/show.php?id=$id';
      items.add(
        DiscoveryItem(
          id: seriesId != null && seriesId != '0' ? 's_$seriesId' : id,
          detailUrl: detail,
          title: title,
          author: value['userName']?.toString(),
          summary: _stripDescription(value['description']?.toString()),
          tags: tags,
        ),
      );
    }
    final total = int.tryParse(novel['total']?.toString() ?? '');
    return DiscoveryPage(
      items: items,
      page: page < 1 ? 1 : page,
      hasMore: total == null ? raw.length >= 30 : page * 30 < total,
    );
  }

  String? _stripDescription(String? input) {
    if (input == null) return null;
    final value = input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return value
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .trim()
            .isEmpty
        ? null
        : value.trim();
  }
}

class _SelectorSource extends _SiteSource {
  const _SelectorSource({
    required this.siteId,
    required this.name,
    required this.hosts,
    required this.chapterSelector,
    required this.bodySelector,
    this.titleSelector = 'title',
  });
  final String siteId, name, chapterSelector, bodySelector, titleSelector;
  final List<String> hosts;
  @override
  String get id => siteId;
  @override
  String get displayName => name;
  @override
  bool matches(Uri u) =>
      hosts.any((h) => u.host == h || u.host.endsWith('.$h'));
  @override
  String canonicalize(String input) => Uri.parse(input.trim()).toString();
  @override
  Future<CachedWebBook> fetchIndex(String url) async {
    final d = parser.parse(await text(url));
    final title = d.querySelector(titleSelector)?.text.trim() ?? url;
    final author =
        d.querySelector('[rel="author"], .author, .author-name')?.text.trim() ??
        '';
    final summary =
        d
            .querySelector('meta[name="description"], .summary, .description')
            ?.attributes['content'] ??
        d.querySelector('.summary, .description')?.innerHtml.trim() ??
        '';
    final chapters = [
      for (final a in d.querySelectorAll('$chapterSelector[href]'))
        if (a.attributes['href'] != null)
          WebBookChapter(
            title: a.text.trim().isEmpty ? '章节' : a.text.trim(),
            url: Uri.parse(url).resolve(a.attributes['href']!).toString(),
          ),
    ];
    return CachedWebBook(
      canonicalUrl: url,
      title: title,
      author: author,
      summary: summary,
      chapters: chapters.isEmpty
          ? [WebBookChapter(title: title, url: url)]
          : chapters,
    );
  }

  @override
  Future<WebBookChapter> fetchChapter(String url, WebBookChapter c) async {
    final d = parser.parse(await text(c.url));
    return c.copyWith(
      html:
          d.querySelector(bodySelector)?.innerHtml.trim() ??
          d.body?.innerHtml ??
          '',
    );
  }
}

class KakuyomuSource extends _SelectorSource {
  const KakuyomuSource()
    : super(
        siteId: 'kakuyomu',
        name: 'カクヨム',
        hosts: const ['kakuyomu.jp'],
        chapterSelector: 'a[href*="/works/"]',
        bodySelector: '.widget-episodeBody',
      );
}

class HamelnSource extends _SelectorSource {
  const HamelnSource()
    : super(
        siteId: 'hameln',
        name: 'ハーメルン',
        hosts: const ['syosetu.org'],
        chapterSelector: 'a[href*="/novel/"]',
        bodySelector: '#honbun',
      );
}

class RoyalRoadSource extends _SelectorSource {
  const RoyalRoadSource()
    : super(
        siteId: 'royalroad',
        name: 'Royal Road',
        hosts: const ['royalroad.com'],
        chapterSelector: 'a[href*="/fiction/"]',
        bodySelector: '.chapter-inner',
      );
}

class ScribbleHubSource extends _SelectorSource {
  const ScribbleHubSource()
    : super(
        siteId: 'scribblehub',
        name: 'Scribble Hub',
        hosts: const ['scribblehub.com'],
        chapterSelector: 'a[href*="/read/"]',
        bodySelector: '.chp_raw',
      );
}

class LiteroticaSource extends _SelectorSource {
  const LiteroticaSource()
    : super(
        siteId: 'literotica',
        name: 'Literotica',
        hosts: const ['literotica.com'],
        chapterSelector: 'a[href*="/s/"]',
        bodySelector: '.aa_ht',
      );
}

class WebSourceRegistry {
  static const sources = <WebSource>[
    PixivSource(),
    Ao3Source(),
    SyosetuSource(),
    KakuyomuSource(),
    HamelnSource(),
    RoyalRoadSource(),
    ScribbleHubSource(),
    LiteroticaSource(),
  ];
  static WebSource forUrl(Uri url) => sources.firstWhere(
    (s) => s.matches(url),
    orElse: () => const _FallbackSource(),
  );
  static WebSource byId(String id, Uri fallbackUrl) =>
      sources.firstWhere((s) => s.id == id, orElse: () => forUrl(fallbackUrl));
}

class _FallbackSource extends _SiteSource {
  const _FallbackSource();
  @override
  String get id => 'generic-html';
  @override
  String get displayName => '通用网页';
  @override
  bool matches(Uri u) => true;
  @override
  String canonicalize(String input) => Uri.parse(input.trim()).toString();
  @override
  Future<CachedWebBook> fetchIndex(String url) async =>
      throw UnsupportedError('请使用通用网页解析器');
  @override
  Future<WebBookChapter> fetchChapter(String url, WebBookChapter c) async => c;
}
