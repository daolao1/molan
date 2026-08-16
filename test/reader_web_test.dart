import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:molan/data/reader_web_cache.dart';
import 'package:molan/data/reader_web_models.dart';
import 'package:molan/data/reader_web_sources.dart';
import 'package:molan/data/st_chatu8.dart';

void main() {
  test('Pixiv content markers are converted to safe HTML', () {
    final html = PixivSource.contentToHtml(
      '[chapter:第一章]\n\n[[rb:漢字 > かんじ]] & <test>\n[jump:2]\n\n[newpage]\n下一页',
    );

    expect(html, contains('<h3>第一章</h3>'));
    expect(html, contains('<ruby>漢字<rt>かんじ</rt></ruby>'));
    expect(html, contains('&amp; &lt;test&gt;'));
    expect(html, isNot(contains('[jump:2]')));
    expect(html, contains('<hr>'));
  });

  test('web cache preserves chapter URLs and loaded HTML', () async {
    SharedPreferences.setMockInitialValues({});
    const url = 'https://example.test/book';
    const book = CachedWebBook(
      canonicalUrl: url,
      title: 'Example',
      author: 'Author',
      chapters: [
        WebBookChapter(
          title: 'Chapter 1',
          url: 'https://example.test/book/1',
          html: '<p>Body</p>',
        ),
      ],
    );

    await ReaderWebCache.write(book);
    final restored = await ReaderWebCache.read(url);

    expect(restored?.title, 'Example');
    expect(restored?.chapters.single.url, 'https://example.test/book/1');
    expect(restored?.chapters.single.html, '<p>Body</p>');
  });

  test('Cloudflare status has an actionable error message', () {
    final error = WebFetchException.fromStatus('AO3', 503);
    expect(error.statusCode, 503);
    expect(error.toString(), contains('Cloudflare'));
    expect(error.toString(), contains('Cookie'));
  });

  test('direct ComfyUI API workflow import selects ComfyUI backend', () {
    final config = StChatu8Store.parseImport('''
      {"72":{"class_type":"PrimitiveStringMultiline","inputs":{"value":"x"}}}
    ''');
    expect(config.backend, contains('comfy'));
    expect(config.comfyui['72'], isA<Map>());
  });
}
