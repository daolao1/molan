import 'package:flutter_test/flutter_test.dart';
import 'package:molan/data/chapter_translator.dart';

void main() {
  final translator = ChapterTranslator();

  test('extracts paragraphs and falls back to plain text', () {
    expect(translator.extractParagraphs('<div><p>第一段</p><p>第二段</p></div>'), [
      '第一段',
      '第二段',
    ]);
    expect(translator.extractParagraphs('<div>第一段\n\n第二段</div>'), [
      '第一段',
      '第二段',
    ]);
  });

  test('batches paragraphs without splitting a paragraph', () {
    expect(translator.batchParagraphs(['aa', 'bbb', 'cccc'], 5), [
      ['aa', 'bbb'],
      ['cccc'],
    ]);
  });

  test('parses numbered model output and ignores think blocks', () {
    expect(
      translator.parseNumberedOutput(
        '<think>internal</think>[2] 第二段\n[1] 第一段',
        2,
      ),
      ['第一段', '第二段'],
    );
  });

  test('builds escaped paragraph HTML', () {
    expect(translator.buildHtml(['a < b'], ['原文']), '<p>a &lt; b</p>');
  });
}
