import 'package:flutter/material.dart';
import '../data/chapter_translator.dart';
import '../data/db.dart';
import '../data/settings.dart';
import '../data/reader_web_client.dart';
import '../data/reader_preferences.dart';
import '../data/llm_client.dart';

class ReaderBookPage extends StatefulWidget {
  const ReaderBookPage({super.key, required this.db, required this.bookId});
  final AppDatabase db;
  final int bookId;
  @override
  State<ReaderBookPage> createState() => _ReaderBookPageState();
}

class _ReaderBookPageState extends State<ReaderBookPage> {
  final _scroll = ScrollController();
  int? _chapterId;
  bool _busy = false;
  int? _loadingChapterId;
  final _loadErrors = <int, Object>{};
  final _prefetching = <int>{};
  ReaderPreferences _preferences = const ReaderPreferences();
  double _progress = 0;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_chapterId != null &&
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent > 0) {
        final fraction = (_scroll.offset / _scroll.position.maxScrollExtent)
            .clamp(0.0, 1.0);
        widget.db.saveReaderProgress(
          bookId: widget.bookId,
          chapterId: _chapterId,
          fraction: fraction,
        );
      }
    });
    widget.db.readerProgressFor(widget.bookId).then((p) {
      if (!mounted || p == null) return;
      setState(() => _chapterId = p.chapterId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients)
          _scroll.jumpTo(_scroll.position.maxScrollExtent * p.scrollFraction);
      });
    });
    ReaderPreferencesStore.load().then((value) {
      if (mounted) setState(() => _preferences = value);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<ReaderChapter> _ensureLoaded(ReaderBook book, ReaderChapter c) async {
    if (c.originalHtml.isNotEmpty || c.sourceUrl == null) return c;
    setState(() {
      _loadingChapterId = c.id;
      _loadErrors.remove(c.id);
    });
    try {
      return await ReaderWebClient.loadChapter(widget.db, book, c);
    } catch (e) {
      _loadErrors[c.id] = e;
      rethrow;
    } finally {
      if (mounted) setState(() => _loadingChapterId = null);
    }
  }

  Future<void> _translate(ReaderBook book, ReaderChapter c) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      c = await _ensureLoaded(book, c);
      final s = await SettingsStore.loadFor(LlmPurpose.writing);
      final preferences = await ReaderPreferencesStore.load();
      final entries = await widget.db.readerGlossaryFor(book.id);
      final glossary = entries
          .take(preferences.glossaryMaxSize)
          .map(
            (e) =>
                '${e.source} -> ${e.target}${e.note.isEmpty ? '' : ' (${e.note})'}',
          )
          .join('\n');
      final result = await ChapterTranslator().translate(
        settings: s,
        targetLanguage: preferences.translationLanguage,
        chapterTitle: c.title,
        chapterHtml: c.originalHtml,
        glossary: glossary,
        style: preferences.translationStyle,
        batchChars: preferences.translationBatchChars,
        onProgress: (a, b) {
          if (mounted) setState(() => _progress = a / b);
        },
      );
      await widget.db.updateReaderTranslation(
        c.id,
        html: result.html,
        state: 'done',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('翻译失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectChapter(
    ReaderBook book,
    List<ReaderChapter> chapters,
    int index,
  ) {
    setState(() => _chapterId = chapters[index].id);
    _prefetch(book, chapters, index);
  }

  Future<void> _prefetch(
    ReaderBook book,
    List<ReaderChapter> chapters,
    int index,
  ) async {
    final end = (index + 1 + _preferences.prefetchAhead).clamp(
      0,
      chapters.length,
    );
    for (var i = index + 1; i < end; i++) {
      final chapter = chapters[i];
      if (chapter.originalHtml.isNotEmpty ||
          chapter.sourceUrl == null ||
          !_prefetching.add(chapter.id)) {
        continue;
      }
      try {
        await ReaderWebClient.loadChapter(widget.db, book, chapter);
      } catch (_) {
        // Foreground loading will surface the actionable error when opened.
      } finally {
        _prefetching.remove(chapter.id);
      }
    }
  }

  Future<void> _setTranslationMode(TranslationMode mode) async {
    final value = _preferences.copyWith(translationMode: mode);
    setState(() => _preferences = value);
    await ReaderPreferencesStore.save(value);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ReaderBook?>(
    future: widget.db.readerBookById(widget.bookId),
    builder: (context, bookSnap) {
      final book = bookSnap.data;
      if (book == null)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return FutureBuilder<List<ReaderChapter>>(
        future: widget.db.readerChaptersOf(widget.bookId),
        builder: (context, snap) {
          final chapters = snap.data ?? const <ReaderChapter>[];
          if (chapters.isEmpty)
            return Scaffold(
              appBar: AppBar(title: Text(book.title)),
              body: const Center(child: Text('没有章节')),
            );
          final current = chapters.firstWhere(
            (x) => x.id == _chapterId,
            orElse: () => chapters.first,
          );
          final index = chapters.indexOf(current);
          final colors = _readerColors(_preferences.readingTheme);
          final loading = _loadingChapterId == current.id;
          final loadError = _loadErrors[current.id];
          if (current.originalHtml.isEmpty &&
              current.sourceUrl != null &&
              !loading &&
              loadError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                _ensureLoaded(book, current).catchError((_) => current);
            });
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(book.title),
              actions: [
                IconButton(
                  onPressed: () => _showGlossary(book),
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: '术语表',
                ),
                IconButton(
                  onPressed: loading ? null : () => _showAsk(book, current),
                  icon: const Icon(Icons.question_answer_outlined),
                  tooltip: '章节问答',
                ),
                IconButton(
                  onPressed: _busy || loading
                      ? null
                      : () => _translate(book, current),
                  icon: const Icon(Icons.translate),
                  tooltip: '翻译本章',
                ),
              ],
            ),
            body: Column(
              children: [
                if (_busy) LinearProgressIndicator(value: _progress),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 190,
                        child: ListView(
                          children: [
                            for (final c in chapters)
                              ListTile(
                                selected: c.id == current.id,
                                title: Text(
                                  c.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectChapter(
                                  book,
                                  chapters,
                                  chapters.indexOf(c),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : loadError != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('章节加载失败：$loadError'),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _ensureLoaded(book, current),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('重试'),
                                    ),
                                  ],
                                ),
                              )
                            : ColoredBox(
                                color: colors.$1,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        8,
                                        16,
                                        4,
                                      ),
                                      child: SegmentedButton<TranslationMode>(
                                        segments: const [
                                          ButtonSegment(
                                            value: TranslationMode.original,
                                            label: Text('原文'),
                                          ),
                                          ButtonSegment(
                                            value: TranslationMode.translated,
                                            label: Text('译文'),
                                          ),
                                          ButtonSegment(
                                            value: TranslationMode.bilingual,
                                            label: Text('双语'),
                                          ),
                                        ],
                                        selected: {
                                          _preferences.translationMode,
                                        },
                                        onSelectionChanged: (v) =>
                                            _setTranslationMode(v.first),
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _scroll,
                                        padding: const EdgeInsets.all(24),
                                        child: _readingText(current, colors.$2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: index > 0
                      ? () => _selectChapter(book, chapters, index - 1)
                      : null,
                  child: const Text('上一章'),
                ),
                Text('${index + 1}/${chapters.length}'),
                TextButton(
                  onPressed: index + 1 < chapters.length
                      ? () => _selectChapter(book, chapters, index + 1)
                      : null,
                  child: const Text('下一章'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  String _plain(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  (Color, Color) _readerColors(ReadingTheme theme) => switch (theme) {
    ReadingTheme.day => (const Color(0xffffffff), const Color(0xff202124)),
    ReadingTheme.sepia => (const Color(0xfff3ead7), const Color(0xff332f29)),
    ReadingTheme.night => (const Color(0xff17191c), const Color(0xffe1e3e6)),
  };

  String? get _fontFamily => switch (_preferences.readerFontFamily) {
    ReaderFontFamily.system => null,
    ReaderFontFamily.serif => 'serif',
    ReaderFontFamily.sansSerif => 'sans-serif',
    ReaderFontFamily.monospace => 'monospace',
  };

  Widget _readingText(ReaderChapter chapter, Color color) {
    final style = TextStyle(
      fontSize: 18,
      height: 1.8,
      color: color,
      fontFamily: _fontFamily,
    );
    final original = _plain(chapter.originalHtml);
    final translated = _plain(chapter.translatedHtml);
    if (_preferences.translationMode == TranslationMode.bilingual &&
        translated.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(original, style: style),
          const SizedBox(height: 24),
          Divider(color: color.withValues(alpha: 0.25)),
          const SizedBox(height: 24),
          SelectableText(translated, style: style),
        ],
      );
    }
    final text =
        _preferences.translationMode == TranslationMode.translated &&
            translated.isNotEmpty
        ? translated
        : original;
    return SelectableText(text, style: style);
  }

  Future<void> _showGlossary(ReaderBook book) async {
    var entries = await widget.db.readerGlossaryFor(book.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('术语表'),
          content: SizedBox(
            width: 520,
            child: entries.isEmpty
                ? const Center(child: Text('暂无术语'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        title: Text('${entry.source} → ${entry.target}'),
                        subtitle: entry.note.isEmpty ? null : Text(entry.note),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '删除',
                          onPressed: () async {
                            await widget.db.deleteReaderGlossary(
                              book.id,
                              entry.source,
                            );
                            entries = await widget.db.readerGlossaryFor(
                              book.id,
                            );
                            setDialogState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final value = await _promptGlossaryEntry(dialogContext);
                if (value == null) return;
                await widget.db.upsertReaderGlossary(
                  bookId: book.id,
                  source: value.$1,
                  target: value.$2,
                  note: value.$3,
                );
                entries = await widget.db.readerGlossaryFor(book.id);
                setDialogState(() {});
              },
              child: const Text('添加'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAsk(ReaderBook book, ReaderChapter chapter) async {
    try {
      chapter = await _ensureLoaded(book, chapter);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final question = TextEditingController();
    var answer = '';
    Object? error;
    var loading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('章节问答', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: question,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '例如：总结本章要点',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: loading ? null : (_) {},
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                            setSheetState(() {
                              loading = true;
                              error = null;
                              answer = '';
                            });
                            try {
                              final settings = await SettingsStore.loadFor(
                                LlmPurpose.writing,
                              );
                              final contextText = _plain(
                                chapter.translatedHtml.isNotEmpty
                                    ? chapter.translatedHtml
                                    : chapter.originalHtml,
                              );
                              final result = await LlmClient.chat(
                                settings,
                                system: '你是中文阅读助手，只根据给出的章节内容回答，简洁准确；内容不足时明确说明。',
                                user:
                                    '章节内容（最多前 6000 字）：\n${contextText.substring(0, contextText.length.clamp(0, 6000))}\n\n问题：${question.text.trim().isEmpty ? '请总结本章要点。' : question.text.trim()}',
                              );
                              if (sheetContext.mounted) {
                                setSheetState(() => answer = result);
                              }
                            } catch (e) {
                              if (sheetContext.mounted) {
                                setSheetState(() => error = e);
                              }
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => loading = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('提问'),
                  ),
                ),
                const SizedBox(height: 12),
                if (loading) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    '请求失败：$error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (answer.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(child: SelectableText(answer)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    question.dispose();
  }

  Future<(String, String, String)?> _promptGlossaryEntry(
    BuildContext context,
  ) async {
    final source = TextEditingController();
    final target = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加术语'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: source,
              decoration: const InputDecoration(labelText: '原文'),
            ),
            TextField(
              controller: target,
              decoration: const InputDecoration(labelText: '译文'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (source.text.trim().isEmpty || target.text.trim().isEmpty)
                return;
              Navigator.pop(context, (
                source.text.trim(),
                target.text.trim(),
                note.text.trim(),
              ));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    source.dispose();
    target.dispose();
    note.dispose();
    return result;
  }
}
