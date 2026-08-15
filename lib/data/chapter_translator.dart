import 'package:html/parser.dart' as html_parser;

import 'llm_client.dart';
import 'settings.dart';

typedef TranslationProgress = void Function(int current, int total);

class ChapterTranslation {
  const ChapterTranslation({required this.title, required this.html});
  final String title;
  final String html;
}

/// Paragraph-preserving translation pipeline migrated from llm_reader.
class ChapterTranslator {
  ChapterTranslator();

  Future<ChapterTranslation> translate({
    required LlmSettings settings,
    required String targetLanguage,
    required String chapterTitle,
    required String chapterHtml,
    String glossary = '',
    String previousContext = '',
    int batchChars = 4000,
    TranslationProgress? onProgress,
    void Function(String title, String html)? onPartial,
  }) async {
    final paragraphs = extractParagraphs(chapterHtml);
    if (paragraphs.isEmpty) throw LlmException('正文为空，无法翻译');
    final batches = batchParagraphs(
      paragraphs,
      batchChars < 200 ? 200 : batchChars,
    );
    final total = batches.length + 1;
    onProgress?.call(0, total);
    final translatedTitle = await _translateOne(
      settings,
      targetLanguage,
      chapterTitle,
      glossary,
    );
    onProgress?.call(1, total);
    onPartial?.call(translatedTitle, '');
    final output = List<String>.filled(paragraphs.length, '');
    var offset = 0;
    var context = previousContext;
    for (var bi = 0; bi < batches.length; bi++) {
      final batch = batches[bi];
      final prompt = _batchPrompt(targetLanguage, batch, glossary, context);
      final raw = await LlmClient.chatStream(
        settings,
        messages: [
          {'role': 'system', 'content': _systemPrompt(targetLanguage)},
          {'role': 'user', 'content': prompt},
        ],
        onDelta: (delta) {
          final partial = parseNumberedOutput(delta, batch.length);
          for (var i = 0; i < partial.length; i++) {
            if (partial[i].isNotEmpty) output[offset + i] = partial[i];
          }
          onPartial?.call(translatedTitle, buildHtml(output, paragraphs));
        },
      );
      final parsed = parseNumberedOutput(raw, batch.length);
      for (var i = 0; i < batch.length; i++) {
        output[offset + i] = parsed[i].isEmpty ? batch[i] : parsed[i];
      }
      context = output.sublist(0, offset + batch.length).takeLast(3).join('\n');
      offset += batch.length;
      onProgress?.call(bi + 2, total);
      onPartial?.call(translatedTitle, buildHtml(output, paragraphs));
    }
    return ChapterTranslation(
      title: translatedTitle,
      html: buildHtml(output, paragraphs),
    );
  }

  List<String> extractParagraphs(String source) {
    final doc = html_parser.parse(source);
    final ps = doc
        .querySelectorAll('p')
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ps.isNotEmpty) return ps;
    return doc.body?.text
            .split(RegExp(r'\n{2,}'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
  }

  List<List<String>> batchParagraphs(List<String> paragraphs, int maxChars) {
    final result = <List<String>>[];
    var current = <String>[];
    var size = 0;
    for (final p in paragraphs) {
      if (current.isNotEmpty && size + p.length > maxChars) {
        result.add(current);
        current = [];
        size = 0;
      }
      current.add(p);
      size += p.length;
    }
    if (current.isNotEmpty) result.add(current);
    return result;
  }

  List<String> parseNumberedOutput(String raw, int expected) {
    final cleaned = raw.replaceAll(
      RegExp(r'<think.*?</think>', dotAll: true, caseSensitive: false),
      '',
    );
    final matches = RegExp(r'\[(\d+)\]\s*').allMatches(cleaned).toList();
    final result = List<String>.filled(expected, '');
    for (var i = 0; i < matches.length; i++) {
      final index = int.tryParse(matches[i].group(1) ?? '') ?? 0;
      if (index < 1 || index > expected) continue;
      final start = matches[i].end;
      final end = i + 1 < matches.length
          ? matches[i + 1].start
          : cleaned.length;
      result[index - 1] = cleaned.substring(start, end).trim();
    }
    return result;
  }

  String buildHtml(List<String> translated, List<String> original) =>
      List.generate(original.length, (i) {
        final value = translated[i].isEmpty ? original[i] : translated[i];
        return '<p>${_escape(value)}</p>';
      }).join('\n');

  Future<String> _translateOne(
    LlmSettings s,
    String lang,
    String title,
    String glossary,
  ) async {
    return LlmClient.chat(
      s,
      system: '你是专业小说翻译，只输出译文标题。目标语言：$lang。',
      user: '术语表：$glossary\n标题：$title',
    );
  }

  String _batchPrompt(
    String lang,
    List<String> batch,
    String glossary,
    String context,
  ) {
    final numbered = List.generate(
      batch.length,
      (i) => '[${i + 1}] ${batch[i]}',
    ).join('\n\n');
    return '目标语言：$lang\n术语表：$glossary\n前文上下文（不要输出）：$context\n严格按编号逐段翻译，只输出 [N] 译文：\n$numbered';
  }

  String _systemPrompt(String lang) => '你是专业小说翻译。翻译为$lang。每段一一对应，不合并、不拆分、不解释。';
  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

extension on List<String> {
  List<String> takeLast(int count) =>
      length <= count ? this : sublist(length - count);
}
